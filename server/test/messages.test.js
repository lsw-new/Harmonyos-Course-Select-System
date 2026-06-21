// 消息中心域（roadmap #4）：服务端化的个人消息流 + 已读状态跨设备同步。
// 覆盖：列表（camelCase + read 布尔）、标记已读（200 + 按学生收口，他人消息→404）、未读数；
// 以及触发点（成绩发布 / 审批终态）确实往 dtest2.messages 写入了消息。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

beforeEach(() => __mock.reset());

describe('GET /api/messages', () => {
  test('未授权 → 401', async () => {
    const res = await request(app).get('/api/messages');
    expect(res.status).toBe(401);
  });

  test('返回当前学生消息（camelCase + read 布尔 + 时间倒序）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.messages\s+WHERE student_id = \$1\s+ORDER BY created_at DESC/, result: [
        { message_id: 'msg-1', kind: 'grade', title: '《数据结构》成绩已发布', body: '成绩已发布', route: 'pages/GradesPage', param: null, read_at: null, created_at: '2026-06-20T08:00:00Z' },
        { message_id: 'msg-2', kind: 'approval', title: '请假申请已通过', body: '审批已通过', route: 'pages/LeaveDetailPage', param: 'lv1', read_at: '2026-06-19T09:00:00Z', created_at: '2026-06-19T08:00:00Z' }
      ] }
    ]);
    const res = await request(app).get('/api/messages').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    const m0 = res.body.data[0];
    expect(m0.messageId).toBe('msg-1');
    expect(m0.kind).toBe('grade');
    expect(m0.route).toBe('pages/GradesPage');
    expect(m0.read).toBe(false); // read_at NULL → 未读
    const m1 = res.body.data[1];
    expect(m1.read).toBe(true); // read_at 有值 → 已读
    expect(m1.param).toBe('lv1');
    // 查询按当前 JWT 学号收口（不信任 body/query）
    const q = __mock.getLog().find((e) => e.sql.indexOf('FROM dtest2.messages') >= 0);
    expect(q.params).toContain('2023307020941');
  });
});

describe('POST /api/messages/:id/read', () => {
  test('命中本人消息 → 200 并写 read_at', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.messages SET read_at = now\(\)/, result: [{ message_id: 'msg-1' }] }
    ]);
    const res = await request(app).post('/api/messages/msg-1/read').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.read).toBe(true);
    // 防 IDOR：UPDATE 同时按 message_id + 当前学号 收口
    const upd = __mock.getLog().find((e) => e.sql.indexOf('UPDATE dtest2.messages') >= 0);
    expect(upd.params).toEqual(['msg-1', '2023307020941']);
  });

  test('他人/不存在的消息 → 404（rowCount 0）', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.messages SET read_at = now\(\)/, result: [] }
    ]);
    const res = await request(app).post('/api/messages/msg-other/read').set('Authorization', stu);
    expect(res.status).toBe(404);
  });
});

describe('POST /api/messages/read-all', () => {
  test('全部标记已读 → 200 返回更新条数，且按当前学号收口', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.messages SET read_at = now\(\)\s+WHERE student_id = \$1 AND read_at IS NULL/, result: [{}, {}, {}] }
    ]);
    const res = await request(app).post('/api/messages/read-all').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.updated).toBe(3);
    // 防 IDOR：UPDATE 仅按当前 JWT 学号过滤，不接受 body/query
    const upd = __mock.getLog().find((e) => e.sql.indexOf('read_at IS NULL') >= 0);
    expect(upd.params).toEqual(['2023307020941']);
  });
});

describe('GET /api/messages/unread-count', () => {
  test('返回未读条数', async () => {
    __mock.setRoutes([
      { match: /SELECT COUNT\(\*\)::int AS count FROM dtest2\.messages/, result: [{ count: 3 }] }
    ]);
    const res = await request(app).get('/api/messages/unread-count').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.count).toBe(3);
  });
});

describe('触发点：成绩发布 → 写入消息', () => {
  test('审核通过发布 → 每名学生一条 grade 消息', async () => {
    __mock.setRoutes([
      PERM,
      { match: /FOR UPDATE OF gt/, result: [{ status: 'pendingAudit', input_progress: 100, term: '2025-2026-2', teaching_class_name: '23U9', course_name: '数据结构' }] },
      { match: /UPDATE dtest2\.grade_tasks SET status='published'/, result: [] },
      { match: /UPDATE dtest2\.grades SET published_at/, result: [] },
      { match: /SELECT DISTINCT student_id FROM dtest2\.grades WHERE task_id/, result: [{ student_id: 'S1' }, { student_id: 'S2' }] },
      { match: /INSERT INTO dtest2\.messages/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt-1/approve').set('Authorization', adm);
    expect(res.status).toBe(200);
    const inserts = __mock.getLog().filter((e) => e.sql.indexOf('INSERT INTO dtest2.messages') >= 0);
    expect(inserts).toHaveLength(2);
    expect(inserts[0].params).toContain('grade');
    expect(inserts[0].params).toContain('S1');
    expect(__mock.executed('COMMIT')).toBe(true);
  });
});

describe('触发点：审批终态 → 写入消息', () => {
  test('末步通过（请假）→ 给申请人一条 approval 消息（深链请假详情）', async () => {
    __mock.setRoutes([
      PERM,
      { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv1', applicant_id: 'S9', title: '请假申请' }] },
      { match: /status='pending' ORDER BY step_order ASC LIMIT 1/, result: [{ step_order: 1 }] },
      { match: /MAX\(step_order\)/, result: [{ max_order: 1 }] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] },
      { match: /UPDATE dtest2\.leave_requests/, result: [] },
      { match: /INSERT INTO dtest2\.messages/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap1/approve').set('Authorization', adm).send({ comment: '准假' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('approved');
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.messages') >= 0);
    expect(ins).toBeDefined();
    expect(ins.params).toContain('approval');
    expect(ins.params).toContain('S9');
    expect(ins.params).toContain('pages/LeaveDetailPage');
    expect(ins.params).toContain('lv1');
  });

  test('驳回（请假）→ 给申请人一条 approval 消息', async () => {
    __mock.setRoutes([
      PERM,
      { match: /FROM dtest2\.approval_instances WHERE approval_id/, result: [{ status: 'pending', biz_type: 'leave', biz_id: 'lv2', applicant_id: 'S8', title: '请假申请' }] },
      { match: /status='pending' ORDER BY step_order ASC LIMIT 1/, result: [{ step_order: 1 }] },
      { match: /MAX\(step_order\)/, result: [{ max_order: 1 }] },
      { match: /UPDATE dtest2\.approval_steps/, result: [] },
      { match: /UPDATE dtest2\.approval_instances/, result: [] },
      { match: /UPDATE dtest2\.leave_requests/, result: [] },
      { match: /INSERT INTO dtest2\.messages/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/approvals/ap2/reject').set('Authorization', adm).send({ comment: '不予批准' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('rejected');
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.messages') >= 0);
    expect(ins).toBeDefined();
    expect(ins.params).toContain('approval');
    expect(ins.params).toContain('S8');
  });
});
