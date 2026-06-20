// 实践提交：学生提交（含报名校验/空内容拦截/upsert）/ 本人查询 / 管理端列表 / 打分认定。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const PERM_DENY = { match: /FROM dtest2\.admin_profiles ap/, result: [] };

const SIGNED_UP = { match: /FROM dtest2\.practice_signups\s+WHERE project_id/, result: [{ ok: 1 }] };
const NOT_SIGNED_UP = { match: /FROM dtest2\.practice_signups\s+WHERE project_id/, result: [] };
const NO_EXISTING = { match: /SELECT submission_id FROM dtest2\.practice_submissions\s+WHERE project_id/, result: [] };

const insertedSubmission = {
  submission_id: 'ps-1', project_id: 'pr-001', student_id: '2023307020941',
  content: '我的实践报告', attachments: [], status: 'submitted',
  score: null, feedback: null, scored_by: null, scored_at: null,
  submitted_at: '2026-06-20T08:00:00Z', updated_at: '2026-06-20T08:00:00Z'
};
const INSERT_SUBMISSION = { match: /INSERT INTO dtest2\.practice_submissions/, result: [insertedSubmission] };

beforeEach(() => __mock.reset());

describe('POST /api/practice/:id/submit（学生提交）', () => {
  test('未登录 → 401', async () => {
    const res = await request(app).post('/api/practice/pr-001/submit').send({ content: 'x' });
    expect(res.status).toBe(401);
  });

  test('content 为空 → 400', async () => {
    const res = await request(app).post('/api/practice/pr-001/submit')
      .set('Authorization', stu).send({ content: '   ' });
    expect(res.status).toBe(400);
  });

  test('content 过长 → 400', async () => {
    const res = await request(app).post('/api/practice/pr-001/submit')
      .set('Authorization', stu).send({ content: 'a'.repeat(5001) });
    expect(res.status).toBe(400);
  });

  test('未报名 → 403', async () => {
    __mock.setRoutes([NOT_SIGNED_UP]);
    const res = await request(app).post('/api/practice/pr-001/submit')
      .set('Authorization', stu).send({ content: '我的实践报告' });
    expect(res.status).toBe(403);
  });

  test('提交成功 → 200 返回 submitted 提交对象', async () => {
    __mock.setRoutes([SIGNED_UP, NO_EXISTING, INSERT_SUBMISSION]);
    const res = await request(app).post('/api/practice/pr-001/submit')
      .set('Authorization', stu).send({ content: '我的实践报告', attachments: ['a.pdf'] });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.submissionId).toBe('ps-1');
    expect(res.body.data.status).toBe('submitted');
    expect(res.body.data.studentId).toBe('2023307020941');
    expect(__mock.executed('INSERT INTO dtest2.practice_submissions')).toBe(true);
  });
});

describe('GET /api/practice/:id/submission（学生本人查询）', () => {
  test('无提交 → 200 data 为 null', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.practice_submissions\s+WHERE project_id/, result: [] }]);
    const res = await request(app).get('/api/practice/pr-001/submission').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data).toBeNull();
  });

  test('有提交 → 200 返回提交对象', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.practice_submissions\s+WHERE project_id/, result: [insertedSubmission] }]);
    const res = await request(app).get('/api/practice/pr-001/submission').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.submissionId).toBe('ps-1');
  });
});

describe('GET /api/admin/practice-submissions（管理端列表）', () => {
  test('无权限 → 403', async () => {
    __mock.setRoutes([PERM_DENY]);
    const res = await request(app).get('/api/admin/practice-submissions').set('Authorization', adm);
    expect(res.status).toBe(403);
  });

  test('未登录 → 401', async () => {
    const res = await request(app).get('/api/admin/practice-submissions');
    expect(res.status).toBe(401);
  });

  test('返回提交数组（含 studentName/projectTitle）', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.practice_submissions ps/, result: [
        Object.assign({}, insertedSubmission, { student_name: '李仕炜', project_title: '暑期实习' })
      ] }
    ]);
    const res = await request(app).get('/api/admin/practice-submissions?status=submitted&projectId=pr-001').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].studentName).toBe('李仕炜');
    expect(res.body.data[0].projectTitle).toBe('暑期实习');
  });
});

describe('POST /api/admin/practice-submissions/:id/score（打分认定）', () => {
  test('status 非法 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/practice-submissions/ps-1/score')
      .set('Authorization', adm).send({ status: 'maybe', score: 90 });
    expect(res.status).toBe(400);
  });

  test('分数越界 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/practice-submissions/ps-1/score')
      .set('Authorization', adm).send({ status: 'passed', score: 200 });
    expect(res.status).toBe(400);
  });

  test('提交不存在 → 404 且回滚', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FOR UPDATE/, result: [] }]);
    const res = await request(app).post('/api/admin/practice-submissions/ps-x/score')
      .set('Authorization', adm).send({ status: 'passed', score: 90 });
    expect(res.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('打分成功 → 200 返回 passed 提交对象', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [{ submission_id: 'ps-1' }] },
      { match: /UPDATE dtest2\.practice_submissions/, result: [
        Object.assign({}, insertedSubmission, { status: 'passed', score: 92, feedback: '优秀', scored_by: 'A20251001' })
      ] }
    ]);
    const res = await request(app).post('/api/admin/practice-submissions/ps-1/score')
      .set('Authorization', adm).send({ status: 'passed', score: 92, feedback: '优秀' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('passed');
    expect(res.body.data.score).toBe(92);
    expect(res.body.data.scoredBy).toBe('A20251001');
    expect(__mock.executed('COMMIT')).toBe(true);
  });
});
