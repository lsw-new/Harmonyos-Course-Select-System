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
      return res.status(403).json(fail('账号状态异常：' + a.status));
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
  if (password.length < 6) {
    return res.status(400).json(fail('密码至少 6 位'));
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
    await client.query(
      `INSERT INTO dtest2.student_profiles (student_id, name, college, major, class_name, grade, email)
       VALUES ($1,$2,'待完善','待完善','待完善','待完善',$3)
       ON CONFLICT (student_id) DO UPDATE SET name=EXCLUDED.name, email=EXCLUDED.email`,
      [studentId, name, email]
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
  if (newPassword.length < 6) {
    return res.status(400).json(fail('密码至少 6 位'));
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
