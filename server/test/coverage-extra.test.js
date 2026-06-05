// 补充覆盖：详情读端点、角色权限聚合循环、以及查询异常时的 500 catch 分支。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

beforeEach(() => __mock.reset());

describe('详情读端点（有数据 → 200，映射行）', () => {
  test('GET /api/grades 有成绩 → 200 并映射', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.grades g/, result: [{ grade_id: 'g1', term: '2025-2026-1', score: 88, grade_point: 3.7, rank: 5, code: 'CS101', name: '数据结构', category: '必修', credit: 4 }] }]);
    const res = await request(app).get('/api/grades').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data[0].courseName).toBe('数据结构');
    expect(res.body.data[0].score).toBe(88);
  });

  test('GET /api/notices/:id 存在 → 200', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.notices n/, result: [{ notice_id: 'n1', title: '停课', publisher: '教务处', summary: 's', content: '正文', category: '通知', published_at: 't', is_read: false }] }]);
    const res = await request(app).get('/api/notices/n1').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.title).toBe('停课');
  });

  test('GET /api/notices/:id 不存在 → 404', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.notices n/, result: [] }]);
    const res = await request(app).get('/api/notices/x').set('Authorization', stu);
    expect(res.status).toBe(404);
  });

  test('GET /api/practice/:id 存在 → 200', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.practice_projects p/, result: [{ project_id: 'p1', title: '实训', org: '学院', category: '实践', credits: 2, period: '2026春', slots_total: 8, requirements_json: [] }] }]);
    const res = await request(app).get('/api/practice/p1').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('p1');
  });

  test('GET /api/admin/roles 有数据 → 200 聚合权限矩阵', async () => {
    __mock.setRoutes([
      PERM,
      {
        match: /FROM dtest2\.roles r/,
        result: [
          { role_id: 'role-super-admin', role_name: '超级管理员', description: '全部权限', member_count: 1, code: 'students.manage', perm_name: '学生管理', module: '学生', actions: ['view', 'update'] },
          { role_id: 'role-super-admin', role_name: '超级管理员', description: '全部权限', member_count: 1, code: 'grades.input', perm_name: '成绩录入', module: '成绩', actions: ['create', 'update'] }
        ]
      }
    ]);
    const res = await request(app).get('/api/admin/roles').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data[0].permissions.length).toBe(2);
    expect(res.body.data[0].permissions[0].actions).toContain('view');
  });
});

describe('查询异常 → 500 catch 分支', () => {
  test('登录时账号查询抛错 → 500，且不泄露内部错误细节', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.accounts/, result: new Error('db connection lost: host=10.0.0.5 pwd=secret') }]);
    const res = await request(app).post('/api/auth/login').send({ account: '2023307020941', password: 'x' });
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    // 安全：内部错误细节（连接串 / 主机 / 凭据等）绝不出现在客户端响应里，只回通用文案
    expect(res.body.error).not.toMatch(/db connection lost|10\.0\.0\.5|secret/);
    expect(res.body.error).toMatch(/请稍后重试/);
  });

  test('课程查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.courses c/, result: new Error('db down') }]);
    const res = await request(app).get('/api/courses').set('Authorization', stu);
    expect(res.status).toBe(500);
  });

  test('成绩查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.grades g/, result: new Error('boom') }]);
    const res = await request(app).get('/api/grades').set('Authorization', stu);
    expect(res.status).toBe(500);
  });
});
