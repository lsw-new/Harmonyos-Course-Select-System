// 越权防护：P0-01（IDOR——学生身份取自 JWT，忽略客户端传入 studentId）+ P0-02（管理端细粒度权限）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const STUDENT_ID = '2023307020941';
const ADMIN_ID = 'A20251001';
const studentToken = signToken({ sub: STUDENT_ID, role: 'student' });
const adminToken = signToken({ sub: ADMIN_ID, role: 'admin' });

beforeEach(() => __mock.reset());

describe('P0-01 IDOR：成绩查询只认 JWT 学号', () => {
  test('携带伪造 ?studentId 时，后端仍按 token.sub 查询', async () => {
    let capturedParams = null;
    __mock.setRoutes([
      {
        match: /FROM dtest2\.grades g/,
        result: (params) => { capturedParams = params; return []; }
      }
    ]);
    const res = await request(app)
      .get('/api/grades?studentId=9999999')
      .set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(capturedParams).not.toBeNull();
    // 查询参数包含真实 token 学号，绝不包含伪造的 9999999
    expect(capturedParams).toContain(STUDENT_ID);
    expect(capturedParams).not.toContain('9999999');
  });
});

describe('P0-02 细粒度权限：GET /api/admin/students 需 students.manage:view', () => {
  test('学生 token → 403（adminRequired 拦截）', async () => {
    const res = await request(app).get('/api/admin/students').set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(403);
  });

  test('管理员但无该权限 → 403（permissionRequired 拦截）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.admin_profiles ap/, result: [] } // 权限查询无命中 → fail-closed
    ]);
    const res = await request(app).get('/api/admin/students').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(403);
    expect(res.body.error).toContain('权限');
  });

  test('管理员且具备权限 → 200', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] }, // 命中权限
      { match: /FROM dtest2\.student_profiles/, result: [] }            // 学生列表查询
    ]);
    const res = await request(app).get('/api/admin/students').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('无 token → 401', async () => {
    const res = await request(app).get('/api/admin/students');
    expect(res.status).toBe(401);
  });
});
