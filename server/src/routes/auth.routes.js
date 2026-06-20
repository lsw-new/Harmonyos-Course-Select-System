// 认证域路由：登录 / 邮箱验证码下发与校验 / 注册 / 找回密码。
// 全部为公开端点（无需登录），统一挂 authLimiter 防爆破；
// 身份建立后由各业务域路由用 authRequired 守卫。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { verifyPassword, hashBcrypt, isBcryptHash } = require('../hash');
const { signToken, authRequired } = require('../auth');
const { sendVerificationCode } = require('../email');
const codeStore = require('../codeStore');
const { authLimiter } = require('../middleware/rateLimit');
const { serverError, pgClientError } = require('../middleware/errorHandler');
const { fetchStudentProfile, fetchAdminProfile } = require('../repositories/profile.repo');

const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

const router = express.Router();

// ---- 邮箱双因素认证（2FA）辅助 ----
// 进程内「待二次校验登录」表：account_id -> { email, expiresAt }。
// 仅在「密码校验通过且账号开启 2FA」后写入，verify-2fa 必须先命中此表才放行，
// 杜绝绕过密码步骤直接调 verify-2fa 凭验证码换 token。单实例 pm2 用内存即可，
// 进程重启即清空（验证码本就短期一次性，用户重走登录即可）。
const PENDING_2FA_TTL_MS = 5 * 60 * 1000; // 与验证码有效期一致
const pending2fa = new Map();

function setPending2fa(accountId, email) {
  pending2fa.set(String(accountId), { email, expiresAt: Date.now() + PENDING_2FA_TTL_MS });
}

function takePending2fa(accountId) {
  const rec = pending2fa.get(String(accountId));
  if (!rec) { return null; }
  if (Date.now() > rec.expiresAt) {
    pending2fa.delete(String(accountId));
    return null;
  }
  return rec;
}

function clearPending2fa(accountId) {
  pending2fa.delete(String(accountId));
}

// 定期清理过期待校验项；unref 不阻止进程退出。
const pendingSweeper = setInterval(() => {
  const now = Date.now();
  for (const [key, rec] of pending2fa) {
    if (now > rec.expiresAt) { pending2fa.delete(key); }
  }
}, 60 * 1000);
if (typeof pendingSweeper.unref === 'function') { pendingSweeper.unref(); }

// 邮箱打码：a***b@domain，避免在「需要二次校验」响应里回明文邮箱（防枚举/信息泄露）。
function maskEmail(email) {
  const s = String(email || '');
  const at = s.indexOf('@');
  if (at <= 0) { return ''; }
  const local = s.slice(0, at);
  const domain = s.slice(at);
  if (local.length <= 2) { return `${local[0] || ''}*${domain}`; }
  return `${local[0]}***${local[local.length - 1]}${domain}`;
}

// 取账号绑定邮箱：学生取 student_profiles.email；管理员取 admin_profiles.email（若有）。
// 取不到邮箱则返回空串，由调用方决定降级（无邮箱无法 2FA，应放行普通登录避免锁死账号）。
async function fetchAccountEmail(accountId, role) {
  try {
    if (role === 'student') {
      const r = await pool.query('SELECT email FROM dtest2.student_profiles WHERE student_id=$1', [accountId]);
      return (r.rowCount > 0 ? (r.rows[0].email || '') : '').trim();
    }
    if (role === 'admin') {
      const r = await pool.query('SELECT email FROM dtest2.admin_profiles WHERE admin_id=$1', [accountId]);
      return (r.rowCount > 0 ? (r.rows[0].email || '') : '').trim();
    }
  } catch (e) { /* 取邮箱失败按无邮箱处理 */ }
  return '';
}

// 登录成功后的标准 token + profile 载荷（普通登录与 2FA 二次校验通过共用，保证返回结构一致）。
async function buildLoginPayload(account) {
  const token = signToken({ sub: account.account_id, role: account.role });
  let profile = null;
  if (account.role === 'student') {
    profile = await fetchStudentProfile(account.account_id);
  } else if (account.role === 'admin') {
    profile = await fetchAdminProfile(account.account_id);
  }
  return { token, accountId: account.account_id, role: account.role, profile };
}

// ---- 登录 ----
router.post('/api/auth/login', authLimiter, async (req, res) => {
  const account = ((req.body && req.body.account) || '').trim();
  const password = (req.body && req.body.password) || '';
  if (!account || !password) {
    return res.status(400).json(fail('账号或密码不能为空'));
  }
  try {
    const r = await pool.query(
      'SELECT account_id, role, password_hash, salt, status, two_factor_enabled FROM dtest2.accounts WHERE account_id=$1',
      [account]
    );
    if (r.rowCount === 0) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    const a = r.rows[0];
    if (a.status !== 'active') {
      // 不回数据库枚举值（disabled/suspended…），避免暴露账号管理策略
      return res.status(403).json(fail('账号已被禁用或暂停使用，请联系管理员'));
    }
    const passOk = await verifyPassword(password, a.salt, a.password_hash);
    if (!passOk) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    // P2-01 收尾：旧 SHA-256 账号登录成功后惰性升级为 bcrypt（失败不影响本次登录）
    if (!isBcryptHash(a.password_hash)) {
      try {
        const upgraded = await hashBcrypt(password);
        await pool.query('UPDATE dtest2.accounts SET password_hash=$2, salt=$3, updated_at=now() WHERE account_id=$1', [a.account_id, upgraded, '']);
      } catch (e) { /* 迁移失败忽略，下次登录再试 */ }
    }
    // 2FA：账号开启邮箱双因素时，密码通过后不直接发 token，改为下发邮箱验证码，
    // 由 /api/auth/login/verify-2fa 二次校验后再发 token。
    if (a.two_factor_enabled === true) {
      const email = await fetchAccountEmail(a.account_id, a.role);
      // 无绑定邮箱无法走 2FA——为避免把账号锁死在登录半途，降级为普通登录直接发 token。
      if (email && EMAIL_RE.test(email)) {
        const gate = codeStore.canIssue(email);
        if (!gate.ok) {
          const wait = Math.ceil(gate.waitMs / 1000);
          return res.status(429).json(fail(`验证码请求过于频繁，请 ${wait} 秒后再试`));
        }
        const code = codeStore.issue(email);
        try {
          await sendVerificationCode(email, code);
        } catch (e) {
          if (e && (e.responseCode === 550 || String(e.message || '').indexOf('550') >= 0)) {
            return res.status(400).json(fail('账号绑定邮箱无法接收邮件，请联系管理员更新邮箱'));
          }
          return serverError(res, '验证码邮件发送失败', e);
        }
        setPending2fa(a.account_id, email);
        return res.json(ok({ twoFactorRequired: true, account: a.account_id, email: maskEmail(email) }));
      }
    }
    // P1-03：随登录下发真实 profile（取不到则置 null，前端回退本地兜底）
    const payload = await buildLoginPayload(a);
    res.json(ok(payload));
  } catch (e) {
    serverError(res, '登录失败', e);
  }
});

// ---- 2FA 二次校验：凭 step-1 下发的邮箱验证码换 token ----
// 必须先命中 pending2fa（即密码已通过且账号开启 2FA 才有记录），再校验验证码，
// 防止跳过密码步骤直接换 token。验证码校验沿用 codeStore（同样的尝试次数/过期限制）。
router.post('/api/auth/login/verify-2fa', authLimiter, async (req, res) => {
  const account = ((req.body && req.body.account) || '').trim();
  const code = ((req.body && req.body.code) || '').trim();
  if (!account || !code) {
    return res.status(400).json(fail('账号或验证码不能为空'));
  }
  const pending = takePending2fa(account);
  if (!pending) {
    // 未发起过 step-1，或已过期——统一文案，不区分以免泄露账号状态
    return res.status(401).json(fail('登录会话已失效，请重新登录'));
  }
  const v = codeStore.verify(pending.email, code);
  if (!v.ok) {
    // 验证码错/过期/尝试超限：保留 pending，让用户在限额内重试；
    // codeStore 自身在尝试超限/过期时会删码，此时下次 verify 会落到「不存在」。
    return res.status(400).json(fail(v.reason));
  }
  clearPending2fa(account);
  try {
    const r = await pool.query(
      'SELECT account_id, role, status FROM dtest2.accounts WHERE account_id=$1',
      [account]
    );
    if (r.rowCount === 0) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    const a = r.rows[0];
    if (a.status !== 'active') {
      return res.status(403).json(fail('账号已被禁用或暂停使用，请联系管理员'));
    }
    const payload = await buildLoginPayload(a);
    res.json(ok(payload));
  } catch (e) {
    serverError(res, '登录失败', e);
  }
});

// ---- 2FA 开关查询（需登录）：返回当前账号的 2FA 开启状态 ----
router.get('/api/auth/2fa', authRequired, async (req, res) => {
  const accountId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
  if (!accountId) {
    return res.status(401).json(fail('未授权', 'unauthorized'));
  }
  try {
    const r = await pool.query('SELECT two_factor_enabled FROM dtest2.accounts WHERE account_id=$1', [accountId]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('账号不存在'));
    }
    res.json(ok({ enabled: r.rows[0].two_factor_enabled === true }));
  } catch (e) {
    serverError(res, '查询双因素状态失败', e);
  }
});

// ---- 2FA 开关设置（需登录）：身份取自 JWT，不信任 body ----
// 注意：开启 2FA 不强制额外邮箱验证码（设计取舍——用户已持有有效登录态即视为已认证身份；
// 真正的二次校验发生在「下次登录」时）。
router.post('/api/auth/2fa', authRequired, async (req, res) => {
  const accountId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
  if (!accountId) {
    return res.status(401).json(fail('未授权', 'unauthorized'));
  }
  const enabled = !!(req.body && req.body.enabled);
  try {
    const r = await pool.query(
      'UPDATE dtest2.accounts SET two_factor_enabled=$2, updated_at=now() WHERE account_id=$1 RETURNING two_factor_enabled',
      [accountId, enabled]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('账号不存在'));
    }
    res.json(ok({ enabled: r.rows[0].two_factor_enabled === true }));
  } catch (e) {
    pgClientError(res, '更新双因素状态失败', e);
  }
});

// ---- 发送邮箱验证码（公开，无需登录）----
router.post('/api/auth/email-code', authLimiter, async (req, res) => {
  const email = ((req.body && req.body.email) || '').trim();
  if (!EMAIL_RE.test(email)) {
    return res.status(400).json(fail('邮箱格式不正确'));
  }
  const gate = codeStore.canIssue(email);
  if (!gate.ok) {
    const wait = Math.ceil(gate.waitMs / 1000);
    return res.status(429).json(fail(`请求过于频繁，请 ${wait} 秒后再试`));
  }
  const code = codeStore.issue(email);
  try {
    await sendVerificationCode(email, code);
    res.json(ok({ sent: true, ttl: 300 }));
  } catch (e) {
    // SMTP 550 = 收件人不存在/拒收：地址问题而非服务问题，给精确提示且不诱导重试
    if (e && (e.responseCode === 550 || String(e.message || '').indexOf('550') >= 0)) {
      return res.status(400).json(fail('该邮箱地址不存在或无法接收邮件，请检查邮箱是否填写正确'));
    }
    serverError(res, '邮件发送失败', e);
  }
});

// ---- 校验邮箱验证码（公开，无需登录；成功即消费）----
router.post('/api/auth/verify-email-code', authLimiter, (req, res) => {
  const email = ((req.body && req.body.email) || '').trim();
  const code = ((req.body && req.body.code) || '').trim();
  if (!EMAIL_RE.test(email) || !code) {
    return res.status(400).json(fail('邮箱或验证码不能为空'));
  }
  const result = codeStore.verify(email, code);
  if (!result.ok) {
    return res.status(400).json(fail(result.reason));
  }
  res.json(ok({ valid: true }));
});

// ---- 注册（公开）：校验邮箱验证码 + 建账号 + 建学生资料（重复学号拒绝）----
// P1-01：注册真正落库（accounts + student_profiles）。注册仅收集 学号/姓名/邮箱，
// student_profiles 其余 NOT NULL 字段先占位「待完善」，由学生登录后在「编辑资料」补全。
// 名册白名单：学号必须存在于 dtest2.class_students（班级学生名册）且姓名一致才允许注册；
// 名册校验放在验证码校验之前，避免不合名册的请求白白消耗一次有效验证码。
router.post('/api/auth/register', authLimiter, async (req, res) => {
  const b = req.body || {};
  const studentId = ((b.studentId) || '').trim();
  const name = ((b.name) || '').trim();
  const email = ((b.email) || '').trim();
  const code = ((b.emailCode) || '').trim();
  const password = (b.password) || '';
  if (!studentId || !name || !EMAIL_RE.test(email) || !code || !password) {
    return res.status(400).json(fail('注册信息不完整'));
  }
  if (password.length < 8) {
    return res.status(400).json(fail('密码至少 8 位'));
  }
  // bcrypt 静默截断 72 字节以上输入，会造成「长密码任意后缀都能登录」的旁路；显式上限拒绝
  if (password.length > 72) {
    return res.status(400).json(fail('密码长度不能超过 72 个字符'));
  }
  let rosterRow;
  try {
    const roster = await pool.query(
      'SELECT student_id, name, class_name, college, major FROM dtest2.class_students WHERE student_id=$1',
      [studentId]
    );
    if (roster.rowCount === 0) {
      return res.status(403).json(fail('该学号不在班级学生名册中，无法注册'));
    }
    rosterRow = roster.rows[0];
    if (rosterRow.name !== name) {
      return res.status(400).json(fail('姓名与学号不匹配，请按学籍信息填写'));
    }
  } catch (e) {
    return serverError(res, '注册失败', e);
  }
  const v = codeStore.verify(email, code);
  if (!v.ok) {
    return res.status(400).json(fail(v.reason));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exists = await client.query('SELECT 1 FROM dtest2.accounts WHERE account_id=$1', [studentId]);
    if (exists.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('该学号已注册'));
    }
    const passwordHash = await hashBcrypt(password);
    await client.query(
      `INSERT INTO dtest2.accounts (account_id, role, password_hash, salt, status) VALUES ($1,'student',$2,$3,'active')`,
      [studentId, passwordHash, '']
    );
    // 班级/年级/学院/专业直接取自名册（姓名已校验与名册一致）；名册缺值时兜底'待完善'
    const grade = `${studentId.slice(0, 4)}级`;
    const college = rosterRow.college || '待完善';
    const major = rosterRow.major || '待完善';
    await client.query(
      `INSERT INTO dtest2.student_profiles (student_id, name, college, major, class_name, grade, email)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (student_id) DO UPDATE SET name=EXCLUDED.name, class_name=EXCLUDED.class_name, grade=EXCLUDED.grade, email=EXCLUDED.email,
         college = CASE WHEN dtest2.student_profiles.college = '待完善' THEN EXCLUDED.college ELSE dtest2.student_profiles.college END,
         major   = CASE WHEN dtest2.student_profiles.major   = '待完善' THEN EXCLUDED.major   ELSE dtest2.student_profiles.major   END`,
      [studentId, rosterRow.name, college, major, rosterRow.class_name, grade, email]
    );
    // 按班级生成本班课程的评教任务（教师绑定来自班级课表）；
    // JOIN courses 与 EXISTS 模板守住外键——课表/模板未导入时静默跳过，不阻断注册
    await client.query(
      `INSERT INTO dtest2.evaluation_tasks
         (task_id, template_id, student_id, course_id, term, teacher_name, status, open_time, close_time)
       SELECT DISTINCT 'eval-' || csi.course_id || '-' || $1,
              'qt-default', $1, csi.course_id, csi.term, csi.teacher, 'open',
              now() - interval '1 day', timestamptz '2026-07-15 23:59:59+08'
       FROM dtest2.class_schedule_items csi
       JOIN dtest2.courses c ON c.course_id = csi.course_id
       WHERE csi.class_name = $2
         AND EXISTS (SELECT 1 FROM dtest2.evaluation_templates WHERE template_id = 'qt-default')
       ON CONFLICT (task_id) DO NOTHING`,
      [studentId, rosterRow.class_name]
    );
    await client.query('COMMIT');
    res.json(ok({ registered: true, accountId: studentId }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '注册失败', e);
  } finally {
    client.release();
  }
});

// ---- 找回密码（公开）：账号须存在且邮箱与绑定邮箱一致，仅重置不建号 ----
// P1-02：堵掉「找回密码可建任意账号」——账号不存在直接 404，邮箱不匹配 403。
router.post('/api/auth/reset-password', authLimiter, async (req, res) => {
  const b = req.body || {};
  const account = ((b.account) || '').trim();
  const email = ((b.contact) || b.email || '').trim();
  const code = ((b.verifyCode) || b.code || '').trim();
  const newPassword = (b.newPassword) || '';
  if (!account || !EMAIL_RE.test(email) || !code || !newPassword) {
    return res.status(400).json(fail('找回密码信息不完整'));
  }
  if (newPassword.length < 8) {
    return res.status(400).json(fail('密码至少 8 位'));
  }
  if (newPassword.length > 72) {
    return res.status(400).json(fail('密码长度不能超过 72 个字符'));
  }
  try {
    const acc = await pool.query('SELECT account_id, role FROM dtest2.accounts WHERE account_id=$1', [account]);
    if (acc.rowCount === 0) {
      return res.status(404).json(fail('账号不存在'));
    }
    if (acc.rows[0].role !== 'student') {
      return res.status(403).json(fail('该账号不支持邮箱找回密码'));
    }
    const prof = await pool.query('SELECT email FROM dtest2.student_profiles WHERE student_id=$1', [account]);
    const boundEmail = (prof.rowCount > 0 ? (prof.rows[0].email || '') : '').trim().toLowerCase();
    if (!boundEmail || boundEmail !== email.toLowerCase()) {
      return res.status(403).json(fail('邮箱与账号不匹配'));
    }
    // 账号/邮箱校验通过后再消费验证码，避免无谓消费
    const v = codeStore.verify(email, code);
    if (!v.ok) {
      return res.status(400).json(fail(v.reason));
    }
    const passwordHash = await hashBcrypt(newPassword);
    await pool.query(
      'UPDATE dtest2.accounts SET password_hash=$2, salt=$3, updated_at=now() WHERE account_id=$1',
      [account, passwordHash, '']
    );
    res.json(ok({ reset: true }));
  } catch (e) {
    serverError(res, '重置密码失败', e);
  }
});

module.exports = router;
