// 评教期全局开关：读默认开放、管理员写入、关闭后提交被服务端权威拦截。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const PERIOD_CLOSED = { match: /FROM dtest2\.system_settings WHERE key/, result: [{ value_json: false }] };

beforeEach(() => __mock.reset());

describe('GET /api/eval-period', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/eval-period');
    expect(res.status).toBe(401);
  });

  test('无记录 → 默认开放', async () => {
    const res = await request(app).get('/api/eval-period').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.open).toBe(true);
  });

  test('记录为 false → 关闭', async () => {
    __mock.setRoutes([PERIOD_CLOSED]);
    const res = await request(app).get('/api/eval-period').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.open).toBe(false);
  });
});

describe('PUT /api/admin/eval-period', () => {
  test('学生 → 403', async () => {
    const res = await request(app).put('/api/admin/eval-period').set('Authorization', stu).send({ open: false });
    expect(res.status).toBe(403);
  });

  test('open 非布尔 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).put('/api/admin/eval-period').set('Authorization', adm).send({ open: 'no' });
    expect(res.status).toBe(400);
  });

  test('管理员写入 → UPSERT 并回显', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /INSERT INTO dtest2\.system_settings/, result: [] }]);
    const res = await request(app).put('/api/admin/eval-period').set('Authorization', adm).send({ open: false });
    expect(res.status).toBe(200);
    expect(res.body.data.open).toBe(false);
    expect(__mock.executed('INSERT INTO dtest2.system_settings')).toBe(true);
  });
});

describe('开关关闭时的提交拦截', () => {
  test('POST /api/evaluations/:taskId/submit → 409 且不进事务', async () => {
    __mock.setRoutes([PERIOD_CLOSED]);
    const res = await request(app).post('/api/evaluations/eval-x/submit').set('Authorization', stu)
      .send({ answers: [{ questionId: 'q-1', score: 5 }] });
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('未开放');
    expect(__mock.executed('BEGIN')).toBe(false);
  });
});
