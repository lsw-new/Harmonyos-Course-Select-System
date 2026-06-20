// 邮箱双因素认证（2FA / roadmap #12）：登录两段式 + 二次校验 + 开关。
// mock 验证码与邮件，专注校验 HTTP 分支与 DB 逻辑（沿用 auth-flows 的 stub 方式）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
jest.mock('../src/codeStore', () => ({
  verify: jest.fn(() => ({ ok: true })),
  canIssue: jest.fn(() => ({ ok: true })),
  issue: jest.fn(() => '654321')
}));
jest.mock('../src/email', () => ({ sendVerificationCode: jest.fn(async () => undefined) }));

const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const codeStore = require('../src/codeStore');
const { signToken } = require('../src/auth');
const { hashBcrypt } = require('../src/hash');

const ACCOUNT = '2023307020941';
const PASSWORD = 'TestPass@123';
const EMAIL = 'me@qq.com';
let bcryptHash;

beforeAll(async () => {
  bcryptHash = await hashBcrypt(PASSWORD);
});

beforeEach(() => {
  __mock.reset();
  codeStore.verify.mockReturnValue({ ok: true });
  codeStore.canIssue.mockReturnValue({ ok: true });
  codeStore.issue.mockReturnValue('654321');
});

// 2FA 关闭的账号行
function accountRow(twoFactor) {
  return { account_id: ACCOUNT, role: 'student', password_hash: bcryptHash, salt: '', status: 'active', two_factor_enabled: twoFactor };
}

describe('登录 2FA 两段式', () => {
  test('2FA 关闭 → 直接返回 token（行为不变）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [accountRow(false)] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.data.token).toBe('string');
    expect(res.body.data.twoFactorRequired).toBeUndefined();
  });

  test('2FA 开启 → 返回 twoFactorRequired 且不发 token', async () => {
    __mock.setRoutes([
      { match: /SELECT account_id, role, password_hash, salt, status, two_factor_enabled/, result: [accountRow(true)] },
      { match: /SELECT email FROM dtest2\.student_profiles/, result: [{ email: EMAIL }] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.twoFactorRequired).toBe(true);
    expect(res.body.data.account).toBe(ACCOUNT);
    expect(res.body.data.token).toBeUndefined();
    // 邮箱已打码，非明文
    expect(res.body.data.email).not.toBe(EMAIL);
    expect(res.body.data.email).toContain('@qq.com');
    expect(codeStore.issue).toHaveBeenCalled();
  });

  test('2FA 开启但账号无绑定邮箱 → 降级普通登录（直接发 token）', async () => {
    __mock.setRoutes([
      { match: /SELECT account_id, role, password_hash, salt, status, two_factor_enabled/, result: [accountRow(true)] },
      { match: /SELECT email FROM dtest2\.student_profiles/, result: [{ email: '' }] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(typeof res.body.data.token).toBe('string');
    expect(res.body.data.twoFactorRequired).toBeUndefined();
  });
});

describe('POST /api/auth/login/verify-2fa', () => {
  // 先走 step-1 让 pending2fa 落记，再做二次校验
  async function doStep1() {
    __mock.setRoutes([
      { match: /SELECT account_id, role, password_hash, salt, status, two_factor_enabled/, result: [accountRow(true)] },
      { match: /SELECT email FROM dtest2\.student_profiles/, result: [{ email: EMAIL }] }
    ]);
    const r = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(r.body.data.twoFactorRequired).toBe(true);
  }

  test('正确验证码 → 返回 token', async () => {
    await doStep1();
    // step-2 重新设路由：账号回读 + student_profiles 回退 null
    __mock.setRoutes([
      { match: /SELECT account_id, role, status FROM dtest2\.accounts/, result: [{ account_id: ACCOUNT, role: 'student', status: 'active' }] }
    ]);
    codeStore.verify.mockReturnValue({ ok: true });
    const res = await request(app).post('/api/auth/login/verify-2fa').send({ account: ACCOUNT, code: '654321' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.data.token).toBe('string');
    expect(res.body.data.role).toBe('student');
  });

  test('验证码错误 → 400', async () => {
    await doStep1();
    codeStore.verify.mockReturnValue({ ok: false, reason: '验证码错误' });
    const res = await request(app).post('/api/auth/login/verify-2fa').send({ account: ACCOUNT, code: '000000' });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toContain('验证码');
  });

  test('未走 step-1 直接调 verify-2fa → 401（不发 token）', async () => {
    const res = await request(app).post('/api/auth/login/verify-2fa').send({ account: 'never-logged-in', code: '654321' });
    expect(res.status).toBe(401);
    expect(res.body.data).toBeNull();
  });

  test('缺少账号或验证码 → 400', async () => {
    const res = await request(app).post('/api/auth/login/verify-2fa').send({ account: '', code: '' });
    expect(res.status).toBe(400);
  });
});

describe('POST /api/auth/2fa 开关', () => {
  const token = signToken({ sub: ACCOUNT, role: 'student' });

  test('无 token → 401', async () => {
    const res = await request(app).post('/api/auth/2fa').send({ enabled: true });
    expect(res.status).toBe(401);
  });

  test('开启 → enabled:true', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.accounts SET two_factor_enabled/, result: [{ two_factor_enabled: true }] }
    ]);
    const res = await request(app)
      .post('/api/auth/2fa')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: true });
    expect(res.status).toBe(200);
    expect(res.body.data.enabled).toBe(true);
    expect(__mock.executed('UPDATE dtest2.accounts SET two_factor_enabled')).toBe(true);
  });

  test('关闭 → enabled:false', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.accounts SET two_factor_enabled/, result: [{ two_factor_enabled: false }] }
    ]);
    const res = await request(app)
      .post('/api/auth/2fa')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false });
    expect(res.status).toBe(200);
    expect(res.body.data.enabled).toBe(false);
  });

  test('GET /api/auth/2fa → 返回当前状态', async () => {
    __mock.setRoutes([
      { match: /SELECT two_factor_enabled FROM dtest2\.accounts/, result: [{ two_factor_enabled: true }] }
    ]);
    const res = await request(app)
      .get('/api/auth/2fa')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data.enabled).toBe(true);
  });
});
