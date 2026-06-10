// 个人资料更新：JWT 身份、头像格式校验、仅更新提交字段。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;

const PROFILE_ROW = {
  student_id: '2023307020941', name: '李仕炜', avatar_url: 'data:image/jpeg;base64,abcd',
  college: '电子信息工程学院', major: '计算机科学与技术', class_name: '23计算机科学与技术U9',
  grade: '2023级', phone: '', email: '', address: '', emergency_contact: '', bio: ''
};

beforeEach(() => __mock.reset());

describe('PUT /api/profile', () => {
  test('无 token → 401', async () => {
    const res = await request(app).put('/api/profile').send({ phone: '13800000000' });
    expect(res.status).toBe(401);
  });

  test('管理员（无学号身份）→ 403', async () => {
    const res = await request(app).put('/api/profile').set('Authorization', adm).send({ phone: '13800000000' });
    expect(res.status).toBe(403);
  });

  test('头像格式非法 → 400', async () => {
    const res = await request(app).put('/api/profile').set('Authorization', stu)
      .send({ avatarUrl: 'javascript:alert(1)' });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('头像');
  });

  test('没有可更新字段 → 400', async () => {
    const res = await request(app).put('/api/profile').set('Authorization', stu).send({ evil: 'x' });
    expect(res.status).toBe(400);
  });

  test('base64 头像更新成功并返回完整 profile', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.student_profiles SET/, result: [{ updated: 1 }] },
      { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [PROFILE_ROW] }
    ]);
    const res = await request(app).put('/api/profile').set('Authorization', stu)
      .send({ avatarUrl: 'data:image/jpeg;base64,abcd', phone: '13800000000' });
    expect(res.status).toBe(200);
    expect(res.body.data.avatarUrl).toBe('data:image/jpeg;base64,abcd');
    const update = __mock.getLog().find((e) => e.sql.indexOf('UPDATE dtest2.student_profiles SET') >= 0);
    expect(update.sql).toContain('avatar_url');
    expect(update.sql).toContain('phone');
    expect(update.sql).not.toContain('bio =');
  });
});
