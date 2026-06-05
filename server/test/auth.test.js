// 登录与鉴权中间件：覆盖空参 400 / 错密码 401 / 成功 200 / 无 token 401。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { hashBcrypt, hashPassword, genSalt } = require('../src/hash');

const ACCOUNT = '2023307020941';
const PASSWORD = 'TestPass@123';
let bcryptHash;

beforeAll(async () => {
  bcryptHash = await hashBcrypt(PASSWORD);
});

beforeEach(() => __mock.reset());

describe('POST /api/auth/login', () => {
  test('缺少账号或密码 → 400', async () => {
    const res = await request(app).post('/api/auth/login').send({ account: '', password: '' });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('账号不存在 → 401', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.accounts/, result: [] }]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('密码错误 → 401', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [{ account_id: ACCOUNT, role: 'student', password_hash: bcryptHash, salt: '', status: 'active' }] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: 'wrong-password' });
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('账号停用 → 403', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [{ account_id: ACCOUNT, role: 'student', password_hash: bcryptHash, salt: '', status: 'disabled' }] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(403);
  });

  test('凭据正确 → 200 + 返回 token 与角色', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [{ account_id: ACCOUNT, role: 'student', password_hash: bcryptHash, salt: '', status: 'active' }] }
      // student_profiles 查询未匹配 → 返回空 → profile=null（登录仍 200）
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.data.token).toBe('string');
    expect(res.body.data.token.length).toBeGreaterThan(20);
    expect(res.body.data.role).toBe('student');
  });

  test('管理员登录 → 200 且返回真实权限矩阵 profile', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [{ account_id: 'A20251001', role: 'admin', password_hash: bcryptHash, salt: '', status: 'active' }] },
      { match: /FROM dtest2\.admin_profiles ap LEFT JOIN/, result: [{ admin_id: 'A20251001', name: '爱莉希雅', department: '教务处', role_id: 'role-super-admin', avatar_url: '', online_status: 'online', role_name: '超级管理员' }] },
      { match: /FROM dtest2\.role_permissions rp/, result: [{ code: 'students.manage', name: '学生管理', module: '学生', actions: ['view', 'update'] }] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: 'A20251001', password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.data.role).toBe('admin');
    expect(res.body.data.profile).not.toBeNull();
    expect(res.body.data.profile.permissions.length).toBeGreaterThan(0);
  });

  test('旧 SHA-256 账号登录成功后惰性升级为 bcrypt（执行 UPDATE）', async () => {
    const salt = genSalt();
    const legacyHash = hashPassword(PASSWORD, salt); // 旧 SHA-256 方案
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts/, result: [{ account_id: ACCOUNT, role: 'student', password_hash: legacyHash, salt, status: 'active' }] },
      { match: /UPDATE dtest2\.accounts SET password_hash/, result: [] }
    ]);
    const res = await request(app).post('/api/auth/login').send({ account: ACCOUNT, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(__mock.executed('UPDATE dtest2.accounts SET password_hash')).toBe(true);
  });
});

describe('authRequired 中间件', () => {
  test('受保护接口无 Authorization 头 → 401', async () => {
    const res = await request(app).get('/api/courses');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('Bearer token 非法 → 401', async () => {
    const res = await request(app).get('/api/courses').set('Authorization', 'Bearer not-a-real-jwt');
    expect(res.status).toBe(401);
  });
});
