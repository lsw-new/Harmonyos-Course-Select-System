// 成绩申诉：学生提交（含成绩校验/重复拦截）/ 管理端列表 / 受理驳回状态机。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const PERM_DENY = { match: /FROM dtest2\.admin_profiles ap/, result: [] };

const GRADE_OK = {
  match: /FROM dtest2\.grades g\s+JOIN dtest2\.grade_tasks gt/,
  result: [{ course_id: 'VDZ02119204', term: '2025-2026-2' }]
};
const GRADE_NONE = { match: /FROM dtest2\.grades g\s+JOIN dtest2\.grade_tasks gt/, result: [] };
const NO_DUP = { match: /FROM dtest2\.grade_appeals\s+WHERE task_id/, result: [] };
const HAS_DUP = { match: /FROM dtest2\.grade_appeals\s+WHERE task_id/, result: [{ ok: 1 }] };

const insertedAppeal = {
  appeal_id: 'ga-1', student_id: '2023307020941', task_id: 'gt-VDZ02119204',
  course_id: 'VDZ02119204', term: '2025-2026-2', reason: '分数有误', status: 'pending',
  reply: null, handled_by: null, handled_at: null,
  submitted_at: '2026-06-19T08:00:00Z', updated_at: '2026-06-19T08:00:00Z'
};
const INSERT_APPEAL = { match: /INSERT INTO dtest2\.grade_appeals/, result: [insertedAppeal] };

beforeEach(() => __mock.reset());

describe('POST /api/grades/:taskId/appeal（学生提交）', () => {
  test('未登录 → 401', async () => {
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal').send({ reason: 'x' });
    expect(res.status).toBe(401);
  });

  test('reason 为空 → 400', async () => {
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal')
      .set('Authorization', stu).send({ reason: '   ' });
    expect(res.status).toBe(400);
  });

  test('reason 过长 → 400', async () => {
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal')
      .set('Authorization', stu).send({ reason: 'a'.repeat(501) });
    expect(res.status).toBe(400);
  });

  test('无对应成绩 → 404', async () => {
    __mock.setRoutes([GRADE_NONE]);
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal')
      .set('Authorization', stu).send({ reason: '分数有误' });
    expect(res.status).toBe(404);
  });

  test('已有 pending 申诉 → 409', async () => {
    __mock.setRoutes([GRADE_OK, HAS_DUP]);
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal')
      .set('Authorization', stu).send({ reason: '分数有误' });
    expect(res.status).toBe(409);
  });

  test('提交成功 → 200 返回 pending 申诉对象', async () => {
    __mock.setRoutes([GRADE_OK, NO_DUP, INSERT_APPEAL]);
    const res = await request(app).post('/api/grades/gt-VDZ02119204/appeal')
      .set('Authorization', stu).send({ reason: '分数有误' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.appealId).toBe('ga-1');
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.studentId).toBe('2023307020941');
    expect(__mock.executed('INSERT INTO dtest2.grade_appeals')).toBe(true);
  });
});

describe('GET /api/admin/grade-appeals（管理端列表）', () => {
  test('无权限 → 403', async () => {
    __mock.setRoutes([PERM_DENY]);
    const res = await request(app).get('/api/admin/grade-appeals').set('Authorization', adm);
    expect(res.status).toBe(403);
  });

  test('未登录 → 401', async () => {
    const res = await request(app).get('/api/admin/grade-appeals');
    expect(res.status).toBe(401);
  });

  test('返回申诉数组（含 studentName）', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.grade_appeals ga/, result: [
        Object.assign({}, insertedAppeal, { student_name: '李仕炜' })
      ] }
    ]);
    const res = await request(app).get('/api/admin/grade-appeals?status=pending').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].studentName).toBe('李仕炜');
    expect(res.body.data[0].appealId).toBe('ga-1');
  });
});

describe('POST /api/admin/grade-appeals/:id/handle（受理/驳回）', () => {
  test('decision 非法 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/grade-appeals/ga-1/handle')
      .set('Authorization', adm).send({ decision: 'maybe' });
    expect(res.status).toBe(400);
  });

  test('申诉不存在 → 404 且回滚', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FOR UPDATE/, result: [] }]);
    const res = await request(app).post('/api/admin/grade-appeals/ga-x/handle')
      .set('Authorization', adm).send({ decision: 'rejected', reply: 'no' });
    expect(res.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('非 pending → 409 且回滚', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FOR UPDATE/, result: [{ status: 'accepted', task_id: 'gt-x' }] }]);
    const res = await request(app).post('/api/admin/grade-appeals/ga-1/handle')
      .set('Authorization', adm).send({ decision: 'rejected', reply: 'no' });
    expect(res.status).toBe(409);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('受理 → 200 且联动 grade_tasks 置 appealed', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [{ status: 'pending', task_id: 'gt-VDZ02119204' }] },
      { match: /UPDATE dtest2\.grade_appeals/, result: [
        Object.assign({}, insertedAppeal, { status: 'accepted', reply: '已核实', handled_by: 'A20251001' })
      ] },
      { match: /UPDATE dtest2\.grade_tasks SET status = 'appealed'/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/grade-appeals/ga-1/handle')
      .set('Authorization', adm).send({ decision: 'accepted', reply: '已核实' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('accepted');
    expect(__mock.executed("UPDATE dtest2.grade_tasks SET status = 'appealed'")).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('驳回 → 200 且不联动 grade_tasks', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [{ status: 'pending', task_id: 'gt-VDZ02119204' }] },
      { match: /UPDATE dtest2\.grade_appeals/, result: [
        Object.assign({}, insertedAppeal, { status: 'rejected', reply: '驳回', handled_by: 'A20251001' })
      ] }
    ]);
    const res = await request(app).post('/api/admin/grade-appeals/ga-1/handle')
      .set('Authorization', adm).send({ decision: 'rejected', reply: '驳回' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('rejected');
    expect(__mock.executed("UPDATE dtest2.grade_tasks SET status = 'appealed'")).toBe(false);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
});
