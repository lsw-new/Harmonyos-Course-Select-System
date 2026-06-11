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

describe('GET /api/evaluations 评教任务与当前课程同步', () => {
  const CLASS_ROW = { match: /SELECT COALESCE\(\s*\(SELECT class_name/, result: [{ class_name: '23计算机科学与技术U9' }] };
  const TASK_ROWS = {
    match: /FROM dtest2\.evaluation_tasks et/,
    result: [{ task_id: 'eval-c1-2023307020941', term: '2025-2026-2', teacher_name: '方坚', status: 'open',
      open_time: null, close_time: null, code: 'c1', name: '课程1', category: 'required', questionnaire_name: '问卷' }]
  };

  test('开放期 + 班级可定位 → 同步补齐并清理后返回列表', async () => {
    __mock.setRoutes([CLASS_ROW, TASK_ROWS]);
    const res = await request(app).get('/api/evaluations').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(__mock.executed('INSERT INTO dtest2.evaluation_tasks')).toBe(true);
    expect(__mock.executed('DELETE FROM dtest2.evaluation_tasks')).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('评教期关闭 → 不触发同步，仅查列表', async () => {
    __mock.setRoutes([PERIOD_CLOSED, TASK_ROWS]);
    const res = await request(app).get('/api/evaluations').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(__mock.executed('INSERT INTO dtest2.evaluation_tasks')).toBe(false);
  });

  test('班级为待完善 → 跳过同步避免误删', async () => {
    __mock.setRoutes([
      { match: /SELECT COALESCE\(\s*\(SELECT class_name/, result: [{ class_name: '待完善' }] },
      TASK_ROWS
    ]);
    const res = await request(app).get('/api/evaluations').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(__mock.executed('INSERT INTO dtest2.evaluation_tasks')).toBe(false);
    expect(__mock.executed('DELETE FROM dtest2.evaluation_tasks')).toBe(false);
  });

  test('同步失败 → 回滚且不阻断列表返回', async () => {
    __mock.setRoutes([
      CLASS_ROW,
      { match: /INSERT INTO dtest2\.evaluation_tasks/, result: new Error('insert boom') },
      TASK_ROWS
    ]);
    const res = await request(app).get('/api/evaluations').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('管理员 token 查询 → 不触发学生课程同步', async () => {
    __mock.setRoutes([TASK_ROWS]);
    const res = await request(app).get('/api/evaluations?studentId=2023307020941').set('Authorization', adm);
    expect(__mock.executed('INSERT INTO dtest2.evaluation_tasks')).toBe(false);
  });
});
