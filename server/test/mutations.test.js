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
  test('DELETE /api/selections 命中 → 200', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.selections SET status='dropped'/, result: oneRow }]);
    const res = await request(app).delete('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(200);
    expect(res.body.data.dropped).toBe(true);
  });

  test('DELETE /api/selections 未选 → 404', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.selections SET status='dropped'/, result: [] }]);
    const res = await request(app).delete('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(404);
  });

  test('POST /api/notices/:id/read → 200', async () => {
    const res = await request(app).post('/api/notices/n1/read').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.read).toBe(true);
  });

  test('POST /api/leave 合法 → 200（事务建审批闭环）', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.leave_requests/, result: [{ leave_id: 'lv1', type: 'personal', start_date: '2026-06-01', end_date: '2026-06-02', reason: 'r', status: 'pending', feedback: '', submitted_at: 't' }] },
      { match: /SELECT name FROM dtest2\.student_profiles/, result: [{ name: '张三' }] },
      { match: /INSERT INTO dtest2\.approval_instances/, result: [] },
      { match: /INSERT INTO dtest2\.approval_steps/, result: [] }
    ]);
    const res = await request(app).post('/api/leave').set('Authorization', stu)
      .send({ type: 'personal', startDate: '2026-06-01', endDate: '2026-06-02', reason: '回家' });
    expect(res.status).toBe(200);
    expect(__mock.executed('INSERT INTO dtest2.approval_instances')).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
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

  test('POST /api/admin/approvals/:id/approve → 200（联动请假状态）', async () => {
    __mock.setRoutes([
      PERM,
      { match: /SELECT status, biz_type, biz_id FROM dtest2\.approval_instances/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1' }] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.leave_requests/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap1/approve').set('Authorization', adm).send({ comment: '准假' });
    expect(res.status).toBe(200);
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
