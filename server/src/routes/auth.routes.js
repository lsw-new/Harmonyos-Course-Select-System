// 认证域路由：登录 / 邮箱验证码下发与校验 / 注册 / 找回密码。
// 全部为公开端点（无需登录），统一挂 authLimiter 防爆破；
// 身份建立后由各业务域路由用 authRequired 守卫。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { verifyPassword, hashBcrypt, isBcryptHash } = require('../hash');
const { signToken } = require('../auth');
const { sendVerificationCode } = require('../email');
const codeStore = require('../codeStore');
const { authLimiter } = require('../middleware/rateLimit');
const { serverError } = require('../middleware/errorHandler');
const { fetchStudentProfile, fetchAdminProfile } = require('../repositories/profile.repo');

const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

const router = express.Router();

// ---- 登录 ----
router.post('/api/auth/login', authLimiter, async (req, res) => {
  const account = ((req.body && req.body.account) || '').trim();
  const password = (req.body && req.body.password) || '';
  if (!account || !password) {
    return res.status(400).json(fail('账号或密码不能为空'));
  }
  try {
    const r = await pool.query(
      'SELECT account_id, role, password_hash, salt, status FROM dtest2.accounts WHERE account_id=$1',
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
    const token = signToken({ sub: a.account_id, role: a.role });
    // P1-03：随登录下发真实 profile（取不到则置 null，前端回退本地兜底）
    let profile = null;
    if (a.role === 'student') {
      profile = await fetchStudentProfile(a.account_id);
    } else if (a.role === 'admin') {
      profile = await fetchAdminProfile(a.account_id);
    }
    res.json(ok({ token, accountId: a.account_id, role: a.role, profile }));
  } catch (e) {
    serverError(res, '登录失败', e);
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
