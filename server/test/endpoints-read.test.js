// 只读端点广覆盖：健康检查 + 学生侧 GET + 管理端 GET（具备权限）。
// 空数据下绝大多数读端点返回 200 + 空集合，借此覆盖各 handler 主体与鉴权链路。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const studentToken = signToken({ sub: '2023307020941', role: 'student' });
const adminToken = signToken({ sub: 'A20251001', role: 'admin' });
// 管理端读端点需先通过 permissionRequired 的权限查询
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

beforeEach(() => __mock.reset());

describe('GET /health', () => {
  test('数据库可达 → 200', async () => {
    __mock.setRoutes([{ match: /SELECT now\(\)/, result: [{ now: new Date().toISOString() }] }]);
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.data.db).toBe('ok');
  });
});

describe('学生只读端点（空数据 → 200）', () => {
  const paths = [
    '/api/courses',
    '/api/selection-rounds/active',
    '/api/selections',
    '/api/grades',
    '/api/notices',
    '/api/leave',
    '/api/feedback',
    '/api/evaluations',
    '/api/practice'
  ];
  test.each(paths)('GET %s → 200', async (path) => {
    const res = await request(app).get(path).set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('无 token 一律 401', async () => {
    for (const path of paths) {
      const res = await request(app).get(path);
      expect(res.status).toBe(401);
    }
  });
});

describe('管理端只读端点（具备权限 → 200）', () => {
  const paths = [
    '/api/admin/students',
    '/api/admin/grades',
    '/api/admin/approvals',
    '/api/admin/roles',
    '/api/admin/audit-logs',
    '/api/admin/eval/templates'
  ];
  test.each(paths)('GET %s（管理员+权限）→ 200', async (path) => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).get(path).set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test.each(paths)('GET %s（学生越权）→ 403', async (path) => {
    const res = await request(app).get(path).set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(403);
  });
});
