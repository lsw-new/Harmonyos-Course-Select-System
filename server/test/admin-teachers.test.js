// 管理端·教师管理域：列表 / 新增 / 编辑 / 重置密码 / 删除 + 权限守卫。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const PERM_DENY = { match: /FROM dtest2\.admin_profiles ap/, result: [] };

beforeEach(() => __mock.reset());

describe('权限守卫', () => {
  test('学生 token → 403', async () => {
    const res = await request(app).get('/api/admin/teachers').set('Authorization', stu);
    expect(res.status).toBe(403);
  });
  test('管理员无 teachers.manage → 403', async () => {
    __mock.setRoutes([PERM_DENY]);
    const res = await request(app).get('/api/admin/teachers').set('Authorization', adm);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/admin/teachers', () => {
  test('返回教师列表（资料 + 状态 + 授课门数）', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.teacher_profiles tp/, result: [
        { teacher_id: 'T001', name: '张伟', college: '计算机学院', title: '副教授', email: 'z@x.com', avatar_url: '', status: 'active', course_count: 3 },
        { teacher_id: 'T002', name: '李娜', college: '', title: '', email: '', avatar_url: '', status: 'active', course_count: 0 }
      ] }
    ]);
    const res = await request(app).get('/api/admin/teachers').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data[0].teacherId).toBe('T001');
    expect(res.body.data[0].courseCount).toBe(3);
    expect(res.body.data[0].title).toBe('副教授');
  });
});

describe('POST /api/admin/teachers', () => {
  test('新增 → 200 并生成下一个 T 编号', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /COALESCE\(MAX\(\(substring\(teacher_id/, result: [{ n: 3 }] },
      { match: /INSERT INTO dtest2\.accounts/, result: [] },
      { match: /INSERT INTO dtest2\.teacher_profiles/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/teachers').set('Authorization', adm)
      .send({ name: '王强', college: '艺术学院', title: '讲师', email: 'w@x.com' });
    expect(res.status).toBe(200);
    expect(res.body.data.teacherId).toBe('T003');
    expect(res.body.data.name).toBe('王强');
    expect(__mock.executed('COMMIT')).toBe(true);
  });
  test('缺姓名 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/teachers').set('Authorization', adm).send({ college: 'x' });
    expect(res.status).toBe(400);
  });
  test('非法邮箱 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/teachers').set('Authorization', adm).send({ name: '王强', email: 'not-an-email' });
    expect(res.status).toBe(400);
  });
});

describe('PUT /api/admin/teachers/:id', () => {
  test('编辑资料 → 200', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /UPDATE dtest2\.teacher_profiles SET/, result: [{}] }
    ]);
    const res = await request(app).put('/api/admin/teachers/T001').set('Authorization', adm)
      .send({ college: '软件学院', title: '教授' });
    expect(res.status).toBe(200);
    expect(res.body.data.updated).toBe(true);
  });
  test('不存在 → 404', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /UPDATE dtest2\.teacher_profiles SET/, result: [] }
    ]);
    const res = await request(app).put('/api/admin/teachers/TX').set('Authorization', adm).send({ title: 'x' });
    expect(res.status).toBe(404);
  });
  test('无字段 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).put('/api/admin/teachers/T001').set('Authorization', adm).send({});
    expect(res.status).toBe(400);
  });
});

describe('POST /api/admin/teachers/:id/reset-password', () => {
  test('重置 → 200', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /UPDATE dtest2\.accounts SET password_hash/, result: [{}] }
    ]);
    const res = await request(app).post('/api/admin/teachers/T001/reset-password').set('Authorization', adm).send({ password: 'NewPass@2024' });
    expect(res.status).toBe(200);
    expect(res.body.data.reset).toBe(true);
  });
  test('账号不存在 → 404', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /UPDATE dtest2\.accounts SET password_hash/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/teachers/TX/reset-password').set('Authorization', adm).send({});
    expect(res.status).toBe(404);
  });
});

describe('DELETE /api/admin/teachers/:id', () => {
  test('删除 → 200（资料 + 账号）', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /DELETE FROM dtest2\.teacher_profiles/, result: [{}] },
      { match: /DELETE FROM dtest2\.accounts/, result: [] }
    ]);
    const res = await request(app).delete('/api/admin/teachers/T001').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.deleted).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
  test('不存在 → 404', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /DELETE FROM dtest2\.teacher_profiles/, result: [] },
      { match: /DELETE FROM dtest2\.accounts/, result: [] }
    ]);
    const res = await request(app).delete('/api/admin/teachers/TX').set('Authorization', adm);
    expect(res.status).toBe(404);
  });
});
