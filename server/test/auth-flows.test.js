// 账号闭环（P1-01/02）：注册落库、找回密码不建号。mock 验证码与邮件，专注校验 HTTP 分支与 DB 逻辑。
jest.mock('../src/db', () => require('./helpers/dbMock'));
jest.mock('../src/codeStore', () => ({
  verify: jest.fn(() => ({ ok: true })),
  canIssue: jest.fn(() => ({ ok: true })),
  issue: jest.fn()
}));
jest.mock('../src/email', () => ({ sendVerificationCode: jest.fn(async () => undefined) }));

const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const codeStore = require('../src/codeStore');

beforeEach(() => {
  __mock.reset();
  codeStore.verify.mockReturnValue({ ok: true });
});

describe('POST /api/auth/register', () => {
  const body = { studentId: '2023307020999', name: '新同学', email: 'newbie@qq.com', emailCode: '123456', password: 'New@12345' };

  test('信息不完整 → 400', async () => {
    const res = await request(app).post('/api/auth/register').send({ studentId: '', name: '', email: 'x', emailCode: '', password: '' });
    expect(res.status).toBe(400);
  });

  test('验证码错误 → 400', async () => {
    codeStore.verify.mockReturnValue({ ok: false, reason: '验证码错误或已过期' });
    const res = await request(app).post('/api/auth/register').send(body);
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('验证码');
  });

  test('学号已注册 → 409 且回滚', async () => {
    __mock.setRoutes([{ match: /SELECT 1 FROM dtest2\.accounts/, result: [{ exists: 1 }] }]);
    const res = await request(app).post('/api/auth/register').send(body);
    expect(res.status).toBe(409);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('注册成功 → 200 落库并提交', async () => {
    __mock.setRoutes([
      { match: /SELECT 1 FROM dtest2\.accounts/, result: [] },
      { match: /INSERT INTO dtest2\.accounts/, result: [] },
      { match: /INSERT INTO dtest2\.student_profiles/, result: [] }
    ]);
    const res = await request(app).post('/api/auth/register').send(body);
    expect(res.status).toBe(200);
    expect(res.body.data.registered).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
    expect(__mock.executed('INSERT INTO dtest2.student_profiles')).toBe(true);
  });
});

describe('POST /api/auth/reset-password', () => {
  const body = { account: '2023307020941', contact: 'me@qq.com', verifyCode: '123456', newPassword: 'Reset@123' };

  test('账号不存在 → 404（不建号）', async () => {
    __mock.setRoutes([{ match: /SELECT account_id, role FROM dtest2\.accounts/, result: [] }]);
    const res = await request(app).post('/api/auth/reset-password').send(body);
    expect(res.status).toBe(404);
  });

  test('管理员账号 → 403', async () => {
    __mock.setRoutes([{ match: /SELECT account_id, role FROM dtest2\.accounts/, result: [{ account_id: body.account, role: 'admin' }] }]);
    const res = await request(app).post('/api/auth/reset-password').send(body);
    expect(res.status).toBe(403);
  });

  test('邮箱与账号不匹配 → 403', async () => {
    __mock.setRoutes([
      { match: /SELECT account_id, role FROM dtest2\.accounts/, result: [{ account_id: body.account, role: 'student' }] },
      { match: /FROM dtest2\.student_profiles/, result: [{ email: 'other@qq.com' }] }
    ]);
    const res = await request(app).post('/api/auth/reset-password').send(body);
    expect(res.status).toBe(403);
    expect(res.body.error).toContain('邮箱');
  });

  test('校验通过 → 200 重置密码', async () => {
    __mock.setRoutes([
      { match: /SELECT account_id, role FROM dtest2\.accounts/, result: [{ account_id: body.account, role: 'student' }] },
      { match: /FROM dtest2\.student_profiles/, result: [{ email: 'me@qq.com' }] },
      { match: /UPDATE dtest2\.accounts/, result: [] }
    ]);
    const res = await request(app).post('/api/auth/reset-password').send(body);
    expect(res.status).toBe(200);
    expect(res.body.data.reset).toBe(true);
  });
});

describe('POST /api/auth/email-code 与 verify-email-code', () => {
  test('邮箱格式非法 → 400', async () => {
    const res = await request(app).post('/api/auth/email-code').send({ email: 'not-an-email' });
    expect(res.status).toBe(400);
  });

  test('发送验证码 → 200', async () => {
    const res = await request(app).post('/api/auth/email-code').send({ email: 'someone@qq.com' });
    expect(res.status).toBe(200);
  });

  test('校验验证码（mock ok）→ 200', async () => {
    const res = await request(app).post('/api/auth/verify-email-code').send({ email: 'someone@qq.com', code: '123456' });
    expect(res.status).toBe(200);
  });
});
