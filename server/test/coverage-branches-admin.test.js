// 分支覆盖补测（管理域 admin.routes + 评教开关写）：成绩状态机 4xx、审批流转 4xx、
// 通知/模板校验矩阵、各端点 catch 500 与事务回滚。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const boom = () => new Error('db down');

beforeEach(() => __mock.reset());

describe('学生管理/成绩列表 catch 分支', () => {
  test('学生列表/学生详情/成绩列表查询抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.student_profiles/, result: boom() }]);
    expect((await request(app).get('/api/admin/students').set('Authorization', adm)).status).toBe(500);
    expect((await request(app).get('/api/admin/students/s1').set('Authorization', adm)).status).toBe(500);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.grade_tasks gt/, result: boom() }]);
    expect((await request(app).get('/api/admin/grades').set('Authorization', adm)).status).toBe(500);
  });
});

describe('成绩录入/打分 状态机与异常', () => {
  test('录入：进度非法 400 / 任务不存在 404 / 状态不可录入 409 / 抛错 500', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/grades/g1/input').set('Authorization', adm)
      .send({ inputProgress: 101 })).status).toBe(400);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: [] }]);
    expect((await request(app).post('/api/admin/grades/g1/input').set('Authorization', adm)
      .send({ inputProgress: 50 })).status).toBe(404);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: [{ status: 'published' }] }]);
    expect((await request(app).post('/api/admin/grades/g1/input').set('Authorization', adm)
      .send({ inputProgress: 50 })).status).toBe(409);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: boom() }]);
    expect((await request(app).post('/api/admin/grades/g1/input').set('Authorization', adm)
      .send({ inputProgress: 50 })).status).toBe(500);
  });

  test('打分名单查询抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.grade_tasks WHERE task_id/, result: boom() }]);
    expect((await request(app).get('/api/admin/grades/g1/scores').set('Authorization', adm)).status).toBe(500);
  });

  test('打分：分数非法 400 / 任务不存在 404 回滚 / 事务抛错 500 回滚', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/grades/g1/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: 's1', score: 101 }] })).status).toBe(400);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.grade_tasks WHERE task_id=\$1 FOR UPDATE/, result: [] }]);
    const r404 = await request(app).post('/api/admin/grades/g1/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: 's1', score: 90 }] });
    expect(r404.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.grade_tasks WHERE task_id=\$1 FOR UPDATE/, result: boom() }]);
    expect((await request(app).post('/api/admin/grades/g1/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: 's1', score: 90 }] })).status).toBe(500);
  });
});

describe('成绩审核 状态机与异常', () => {
  test('审核通过：404 / 状态不可审核 409 / 进度未满 409 / 抛错 500', async () => {
    __mock.setRoutes([PERM, { match: /SELECT status, input_progress FROM dtest2\.grade_tasks/, result: [] }]);
    expect((await request(app).post('/api/admin/grades/g1/approve').set('Authorization', adm)).status).toBe(404);

    __mock.setRoutes([PERM, { match: /SELECT status, input_progress FROM dtest2\.grade_tasks/, result: [{ status: 'inputting', input_progress: 50 }] }]);
    expect((await request(app).post('/api/admin/grades/g1/approve').set('Authorization', adm)).status).toBe(409);

    __mock.setRoutes([PERM, { match: /SELECT status, input_progress FROM dtest2\.grade_tasks/, result: [{ status: 'pendingAudit', input_progress: 90 }] }]);
    const rProg = await request(app).post('/api/admin/grades/g1/approve').set('Authorization', adm);
    expect(rProg.status).toBe(409);
    expect(rProg.body.error).toContain('100%');

    __mock.setRoutes([PERM, { match: /SELECT status, input_progress FROM dtest2\.grade_tasks/, result: boom() }]);
    expect((await request(app).post('/api/admin/grades/g1/approve').set('Authorization', adm)).status).toBe(500);
  });

  test('驳回：404 / 状态不可驳回 409 / 抛错 500', async () => {
    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: [] }]);
    expect((await request(app).post('/api/admin/grades/g1/reject').set('Authorization', adm)
      .send({ reason: 'r' })).status).toBe(404);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: [{ status: 'published' }] }]);
    expect((await request(app).post('/api/admin/grades/g1/reject').set('Authorization', adm)
      .send({ reason: 'r' })).status).toBe(409);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.grade_tasks/, result: boom() }]);
    expect((await request(app).post('/api/admin/grades/g1/reject').set('Authorization', adm)
      .send({ reason: 'r' })).status).toBe(500);
  });
});

describe('审批流转分支', () => {
  test('列表查询抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.approval_instances/, result: boom() }]);
    expect((await request(app).get('/api/admin/approvals').set('Authorization', adm)).status).toBe(500);
  });

  test('通过：意见缺失 400 / 记录不存在 404 / 非 pending 409 / 抛错 500', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/approvals/a1/approve').set('Authorization', adm)
      .send({ comment: ' ' })).status).toBe(400);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: [] }]);
    expect((await request(app).post('/api/admin/approvals/a1/approve').set('Authorization', adm)
      .send({ comment: 'ok' })).status).toBe(404);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: [{ status: 'approved', biz_type: 'leave', biz_id: 'lv1' }] }]);
    expect((await request(app).post('/api/admin/approvals/a1/approve').set('Authorization', adm)
      .send({ comment: 'ok' })).status).toBe(409);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: boom() }]);
    expect((await request(app).post('/api/admin/approvals/a1/approve').set('Authorization', adm)
      .send({ comment: 'ok' })).status).toBe(500);
  });

  test('驳回：意见缺失 400；带意见正常驳回（leave 联动）→ 200', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/approvals/a1/reject').set('Authorization', adm)
      .send({ comment: '' })).status).toBe(400);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1' }] }]);
    const res = await request(app).post('/api/admin/approvals/a1/reject').set('Authorization', adm)
      .send({ comment: '材料不全' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('rejected');
    expect(__mock.executed('UPDATE dtest2.leave_requests')).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
});

describe('通知发布校验矩阵', () => {
  const base = { title: 't', content: 'c' };

  test('紧急程度/接收类型非法 400；写入抛错 500', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/notices').set('Authorization', adm)
      .send(Object.assign({}, base, { urgency: 'super' }))).status).toBe(400);
    expect((await request(app).post('/api/admin/notices').set('Authorization', adm)
      .send(Object.assign({}, base, { receiverType: 'aliens' }))).status).toBe(400);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.notices/, result: boom() }]);
    expect((await request(app).post('/api/admin/notices').set('Authorization', adm)
      .send(base)).status).toBe(500);
  });
});

describe('角色矩阵 / 操作日志 catch 与聚合分支', () => {
  test('角色矩阵：有权限角色与零权限角色都正确聚合', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.roles r/, result: [
      { role_id: 'r-super', role_name: '超管', description: 'd', member_count: 1, code: 'grades.input', perm_name: '成绩录入', module: 'grades', actions: ['update', 'view'] },
      { role_id: 'r-empty', role_name: '空角色', description: '', member_count: 0, code: null, perm_name: null, module: null, actions: null }
    ] }]);
    const res = await request(app).get('/api/admin/roles').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data[0].permissions).toHaveLength(1);
    expect(res.body.data[1].permissions).toHaveLength(0);
  });

  test('角色矩阵/操作日志查询抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.roles r/, result: boom() }]);
    expect((await request(app).get('/api/admin/roles').set('Authorization', adm)).status).toBe(500);
    __mock.setRoutes([PERM, { match: /FROM dtest2\.audit_logs/, result: boom() }]);
    expect((await request(app).get('/api/admin/audit-logs').set('Authorization', adm)).status).toBe(500);
  });
});

describe('评教问卷模板校验矩阵与异常', () => {
  const valid = { name: 'n', description: 'd', questionCount: 10, status: 'enabled' };

  test('新建：名称空/题数非法/状态非法 400；抛错 500', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).post('/api/admin/eval/templates').set('Authorization', adm)
      .send(Object.assign({}, valid, { name: ' ' }))).status).toBe(400);
    expect((await request(app).post('/api/admin/eval/templates').set('Authorization', adm)
      .send(Object.assign({}, valid, { questionCount: 0 }))).status).toBe(400);
    expect((await request(app).post('/api/admin/eval/templates').set('Authorization', adm)
      .send(Object.assign({}, valid, { status: 'weird' }))).status).toBe(400);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.evaluation_templates/, result: boom() }]);
    expect((await request(app).post('/api/admin/eval/templates').set('Authorization', adm)
      .send(valid)).status).toBe(500);
  });

  test('更新：校验矩阵 400、成功回显 200、抛错 500；列表抛错 500', async () => {
    __mock.setRoutes([PERM]);
    expect((await request(app).put('/api/admin/eval/templates/t1').set('Authorization', adm)
      .send(Object.assign({}, valid, { name: '' }))).status).toBe(400);
    expect((await request(app).put('/api/admin/eval/templates/t1').set('Authorization', adm)
      .send(Object.assign({}, valid, { questionCount: 99 }))).status).toBe(400);
    expect((await request(app).put('/api/admin/eval/templates/t1').set('Authorization', adm)
      .send(Object.assign({}, valid, { status: '' }))).status).toBe(400);

    __mock.setRoutes([PERM, { match: /UPDATE dtest2\.evaluation_templates/, result: [{ template_id: 't1', name: 'n', description: 'd', question_count: 10, status: 'enabled' }] }]);
    const okRes = await request(app).put('/api/admin/eval/templates/t1').set('Authorization', adm).send(valid);
    expect(okRes.status).toBe(200);
    expect(okRes.body.data.name).toBe('n');

    __mock.setRoutes([PERM, { match: /UPDATE dtest2\.evaluation_templates/, result: boom() }]);
    expect((await request(app).put('/api/admin/eval/templates/t1').set('Authorization', adm)
      .send(valid)).status).toBe(500);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.evaluation_templates ORDER BY/, result: boom() }]);
    expect((await request(app).get('/api/admin/eval/templates').set('Authorization', adm)).status).toBe(500);
  });

  test('删除：不存在 404；抛错 500', async () => {
    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.evaluation_templates/, result: [] }]);
    expect((await request(app).delete('/api/admin/eval/templates/t1').set('Authorization', adm)).status).toBe(404);
    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.evaluation_templates/, result: boom() }]);
    expect((await request(app).delete('/api/admin/eval/templates/t1').set('Authorization', adm)).status).toBe(500);
  });
});

describe('评教开关写端点异常', () => {
  test('写入抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.system_settings/, result: boom() }]);
    expect((await request(app).put('/api/admin/eval-period').set('Authorization', adm)
      .send({ open: true })).status).toBe(500);
  });
});
