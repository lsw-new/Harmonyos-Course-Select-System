// 写操作广覆盖：学生侧（退课/已读/请假/反馈/评教提交/取消报名）+ 管理端（成绩录入审核驳回/审批/通知发布/问卷模板 CRUD）。
// 通过 mock 驱动各事务/语句，覆盖成功 200 与典型 4xx 分支，提升 index.js 写路径覆盖率。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const oneRow = [{}]; // rowCount=1，用于模拟 UPDATE/DELETE 命中

beforeEach(() => __mock.reset());

describe('学生写操作', () => {
  // 退课与选课同口径：须有 running 且在时间窗口内的轮次
  const ROUND_OPEN = { match: /FROM dtest2\.selection_rounds/, result: [{ round_id: 'r1' }] };

  test('DELETE /api/selections 命中 → 200', async () => {
    __mock.setRoutes([ROUND_OPEN, { match: /UPDATE dtest2\.selections SET status='dropped'/, result: oneRow }]);
    const res = await request(app).delete('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(200);
    expect(res.body.data.dropped).toBe(true);
  });

  test('DELETE /api/selections 未选 → 404', async () => {
    __mock.setRoutes([ROUND_OPEN, { match: /UPDATE dtest2\.selections SET status='dropped'/, result: [] }]);
    const res = await request(app).delete('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(404);
  });

  test('DELETE /api/selections 选课关闭期 → 409 且不触发 UPDATE', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.selection_rounds/, result: [] }]);
    const res = await request(app).delete('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('退课');
    expect(__mock.executed("UPDATE dtest2.selections SET status='dropped'")).toBe(false);
  });

  test('POST /api/notices/:id/read → 200', async () => {
    const res = await request(app).post('/api/notices/n1/read').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.read).toBe(true);
  });

  test('POST /api/leave 合法 → 200（事务建审批闭环 + 多级有序步骤，首步激活）', async () => {
    const insertedSteps = [];
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.leave_requests/, result: [{ leave_id: 'lv1', type: 'personal', start_date: '2026-06-01', end_date: '2026-06-02', reason: 'r', status: 'pending', feedback: '', submitted_at: 't' }] },
      { match: /SELECT name FROM dtest2\.student_profiles/, result: [{ name: '张三' }] },
      { match: /INSERT INTO dtest2\.approval_instances/, result: [] },
      { match: /FROM dtest2\.approval_flow_nodes/, result: [
        { name: '辅导员审批', approver_role: '教务管理员', node_order: 1 },
        { name: '教务审批', approver_role: '教务管理员', node_order: 2 },
        { name: '院领导审批', approver_role: '教务管理员', node_order: 3 }
      ] },
      { match: /INSERT INTO dtest2\.approval_steps/, result: (params) => { insertedSteps.push({ order: params[2], status: params[5] }); return []; } },
      { match: /SELECT step_order, node_name.*FROM dtest2\.approval_steps WHERE approval_id/s, result: [
        { step_order: 1, node_name: '辅导员审批', approver_role: '教务管理员', operator_id: null, status: 'pending', handled_at: null, comment: null },
        { step_order: 2, node_name: '教务审批', approver_role: '教务管理员', operator_id: null, status: 'waiting', handled_at: null, comment: null },
        { step_order: 3, node_name: '院领导审批', approver_role: '教务管理员', operator_id: null, status: 'waiting', handled_at: null, comment: null }
      ] }
    ]);
    const res = await request(app).post('/api/leave').set('Authorization', stu)
      .send({ type: 'personal', startDate: '2026-06-01', endDate: '2026-06-02', reason: '回家' });
    expect(res.status).toBe(200);
    expect(__mock.executed('INSERT INTO dtest2.approval_instances')).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
    // 建了 3 个有序步骤，首步 pending（激活），其余 waiting
    expect(insertedSteps.length).toBe(3);
    expect(insertedSteps[0]).toEqual({ order: 1, status: 'pending' });
    expect(insertedSteps[1].status).toBe('waiting');
    expect(insertedSteps[2].status).toBe('waiting');
    // 响应带回 steps 进度
    expect(res.body.data.steps.length).toBe(3);
    expect(res.body.data.steps[0].order).toBe(1);
    expect(res.body.data.steps[0].title).toBe('辅导员审批');
    expect(res.body.data.steps[0].status).toBe('pending');
  });

  test('POST /api/leave/:id/withdraw → 关闭未完结步骤并置请假 withdrawn', async () => {
    __mock.setRoutes([
      { match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: [{ status: 'pending' }] },
      { match: /UPDATE dtest2\.leave_requests SET status = 'withdrawn'/, result: [{ leave_id: 'lv1', type: 'personal', start_date: '2026-06-01', end_date: '2026-06-02', reason: 'r', status: 'withdrawn', feedback: '', submitted_at: 't' }] },
      { match: /UPDATE dtest2\.approval_steps SET status = 'rejected'/, result: [] },
      { match: /UPDATE dtest2\.approval_instances SET status = 'withdrawn'/, result: [] }
    ]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.state).toBe('withdrawn');
    // 撤回时关闭 pending/waiting 步骤
    expect(__mock.executed("UPDATE dtest2.approval_steps SET status = 'rejected'")).toBe(true);
    expect(__mock.executed("UPDATE dtest2.approval_instances SET status = 'withdrawn'")).toBe(true);
  });

  test('POST /api/leave 类型非法 → 400', async () => {
    const res = await request(app).post('/api/leave').set('Authorization', stu)
      .send({ type: 'badtype', startDate: '2026-06-01', endDate: '2026-06-02', reason: 'x' });
    expect(res.status).toBe(400);
  });

  test('POST /api/feedback 合法 → 200', async () => {
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.feedback_items/, result: [{ feedback_id: 'fb1', category: 'bug', title: 't', content: 'c', contact: '', state: 'submitted', submitted_at: 't' }] }]);
    const res = await request(app).post('/api/feedback').set('Authorization', stu)
      .send({ category: 'bug', title: '闪退', content: '点击崩溃' });
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('fb1');
  });

  test('POST /api/feedback 类型非法 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', stu)
      .send({ category: 'invalid', title: 't', content: 'c' });
    expect(res.status).toBe(400);
  });

  test('POST /api/evaluations/:taskId/submit 开放中 → 200', async () => {
    __mock.setRoutes([
      { match: /SELECT status FROM dtest2\.evaluation_tasks/, result: [{ status: 'open' }] },
      { match: /INSERT INTO dtest2\.evaluation_submissions/, result: [] },
      { match: /UPDATE dtest2\.evaluation_tasks/, result: [] }
    ]);
    const res = await request(app).post('/api/evaluations/ev1/submit').set('Authorization', stu)
      .send({ answers: [{ q: 1, a: 5 }] });
    expect(res.status).toBe(200);
    expect(res.body.data.submitted).toBe(true);
  });

  test('POST /api/evaluations/:taskId/submit 任务不存在 → 404', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.evaluation_tasks/, result: [] }]);
    const res = await request(app).post('/api/evaluations/ev1/submit').set('Authorization', stu)
      .send({ answers: [{ q: 1, a: 5 }] });
    expect(res.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('DELETE /api/practice/:id/signup 命中 → 200', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.practice_signups SET status='cancelled'/, result: oneRow },
      { match: /FROM dtest2\.practice_projects p/, result: [{ project_id: 'p1', title: 't', org: 'o', category: 'c', credits: 2, period: '2026', slots_total: 8, requirements_json: [] }] }
    ]);
    const res = await request(app).delete('/api/practice/p1/signup').set('Authorization', stu);
    expect(res.status).toBe(200);
  });
});

describe('管理端写操作（具备权限）', () => {
  test('POST /api/admin/grades/:id/input → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status FROM dtest2\.grade_tasks/, result: [{ status: 'inputting' }] },
      { match: /UPDATE dtest2\.grade_tasks SET input_progress/, result: [] },
      { match: /FROM dtest2\.grade_tasks gt/, result: [{ task_id: 'gt1', status: 'pendingAudit', input_progress: 100, course_name: '高数' }] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt1/input').set('Authorization', adm).send({ inputProgress: 100 });
    expect(res.status).toBe(200);
  });

  test('POST /api/admin/grades/:id/approve → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status, input_progress FROM dtest2\.grade_tasks/, result: [{ status: 'pendingAudit', input_progress: 100 }] },
      { match: /UPDATE dtest2\.grade_tasks SET status='published'/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt1/approve').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.approved).toBe(true);
  });

  test('POST /api/admin/grades/:id/reject 无理由 → 400', async () => {
    __mock.setRoutes([PERM]);
    const res = await request(app).post('/api/admin/grades/gt1/reject').set('Authorization', adm).send({ reason: '' });
    expect(res.status).toBe(400);
  });

  test('POST /api/admin/grades/:id/reject 有理由 → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status FROM dtest2\.grade_tasks/, result: [{ status: 'pendingAudit' }] },
      { match: /UPDATE dtest2\.grade_tasks SET status='rejected'/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt1/reject').set('Authorization', adm).send({ reason: '缺平时分' });
    expect(res.status).toBe(200);
  });

  test('POST /api/admin/approvals/:id/approve → 200（单步=末步，联动请假 approved）', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status, biz_type, biz_id FROM dtest2\.approval_instances/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1' }] },
      { match: /status='pending' ORDER BY step_order ASC LIMIT 1/, result: [{ step_order: 1 }] },
      { match: /MAX\(step_order\)/, result: [{ max_order: 1 }] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.leave_requests/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap1/approve').set('Authorization', adm).send({ comment: '准假' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('approved');
    expect(res.body.data.finalized).toBe(true);
    expect(__mock.executed('UPDATE dtest2.leave_requests')).toBe(true);
  });

  test('POST /api/admin/approvals/:id/approve 非末步 → 仍 pending 并激活下一步', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status, biz_type, biz_id FROM dtest2\.approval_instances/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1' }] },
      { match: /status='pending' ORDER BY step_order ASC LIMIT 1/, result: [{ step_order: 1 }] },
      { match: /MAX\(step_order\)/, result: [{ max_order: 3 }] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap1/approve').set('Authorization', adm).send({ comment: '同意' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.finalized).toBe(false);
    expect(res.body.data.nextStep).toBe(2);
    // 非末步不应联动请假最终状态
    expect(__mock.executed('UPDATE dtest2.leave_requests')).toBe(false);
  });

  test('POST /api/admin/approvals/:id/reject 激活步 → 终止流程并置请假 rejected', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status, biz_type, biz_id FROM dtest2\.approval_instances/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1' }] },
      { match: /status='pending' ORDER BY step_order ASC LIMIT 1/, result: [{ step_order: 2 }] },
      { match: /MAX\(step_order\)/, result: [{ max_order: 3 }] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] },
      { match: /UPDATE dtest2\.leave_requests/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap1/reject').set('Authorization', adm).send({ comment: '不予批准' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('rejected');
    expect(res.body.data.finalized).toBe(true);
    expect(__mock.executed('UPDATE dtest2.leave_requests')).toBe(true);
  });

  test('POST /api/admin/approvals/:id/reject 无意见 → 400', async () => {
    __mock.setRoutes([PERM]);
    const res = await request(app).post('/api/admin/approvals/ap1/reject').set('Authorization', adm).send({ comment: '' });
    expect(res.status).toBe(400);
  });

  test('POST /api/admin/notices 合法 → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /INSERT INTO dtest2\.notices/, result: [{ notice_id: 'n1', title: 't', publisher: '教务处', summary: 's', content: 'c', category: '通知', published_at: 't' }] }
    ]);
    const res = await request(app).post('/api/admin/notices').set('Authorization', adm)
      .send({ title: '停课通知', content: '本周五停课' });
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('n1');
  });

  test('POST /api/admin/notices 空标题 → 400', async () => {
    __mock.setRoutes([PERM]);
    const res = await request(app).post('/api/admin/notices').set('Authorization', adm).send({ title: '', content: 'c' });
    expect(res.status).toBe(400);
  });

  test('POST /api/admin/eval/templates 合法 → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /INSERT INTO dtest2\.evaluation_templates/, result: [{ template_id: 'qt1', name: '问卷', description: '', question_count: 5, status: 'enabled' }] }
    ]);
    const res = await request(app).post('/api/admin/eval/templates').set('Authorization', adm)
      .send({ name: '教学评价', questionCount: 5, status: 'enabled' });
    expect(res.status).toBe(200);
  });

  test('PUT /api/admin/eval/templates/:id 不存在 → 404', async () => {
    __mock.setRoutes([
      PERM,
      { match: /UPDATE dtest2\.evaluation_templates/, result: [] }
    ]);
    const res = await request(app).put('/api/admin/eval/templates/qtX').set('Authorization', adm)
      .send({ name: '教学评价', questionCount: 5, status: 'enabled' });
    expect(res.status).toBe(404);
  });

  test('DELETE /api/admin/eval/templates/:id 命中 → 200', async () => {
    __mock.setRoutes([
      PERM,
      { match: /DELETE FROM dtest2\.evaluation_templates/, result: oneRow }
    ]);
    const res = await request(app).delete('/api/admin/eval/templates/qt1').set('Authorization', adm);
    expect(res.status).toBe(200);
  });
});
