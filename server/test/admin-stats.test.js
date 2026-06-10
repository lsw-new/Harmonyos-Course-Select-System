// 管理端统计域 + 课程管理域：仪表盘聚合、选课/评教统计、课程 CRUD 与 timeText 解析。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

beforeEach(() => __mock.reset());

describe('GET /api/admin/dashboard', () => {
  test('学生 token → 403', async () => {
    const res = await request(app).get('/api/admin/dashboard').set('Authorization', stu);
    expect(res.status).toBe(403);
  });

  test('返回统计卡/趋势/分布/待审批', async () => {
    __mock.setRoutes([
      { match: /AS students/, result: [{ students: '1', roster: '47', courses: '11', pending_approvals: '2', grade_pending: '0', grade_published: '1', eval_submitted: '0', notices: '3' }] },
      { match: /generate_series/, result: [{ label: '06-10', value: 2 }] },
      { match: /GROUP BY category/, result: [{ category: 'required', value: 8 }, { category: 'public', value: 2 }] },
      { match: /FROM dtest2\.approval_instances/, result: [] }
    ]);
    const res = await request(app).get('/api/admin/dashboard').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.statCards.find((c) => c.key === 'roster').value).toBe(47);
    expect(res.body.data.courseTypeDistribution[0]).toEqual({ name: '必修', value: 8 });
    expect(res.body.data.selectionTrend[0].value).toBe(2);
  });
});

describe('GET /api/admin/selection/stats', () => {
  test('轮次聚合统计与进度', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.selection_rounds r/, result: [{
        round_id: 'round-2026-main', name: '2026 春主轮', status: 'running',
        start_time: '2026-06-01T00:00:00Z', end_time: '2026-07-01T00:00:00Z',
        participants: '1', selections: '2', avg_credit: '4.50'
      }] }
    ]);
    const res = await request(app).get('/api/admin/selection/stats').set('Authorization', adm);
    expect(res.status).toBe(200);
    const r = res.body.data[0];
    expect(r.participantCount).toBe(1);
    expect(r.selectionCount).toBe(2);
    expect(r.averageCredit).toBe(4.5);
    expect(r.progressPercent).toBeGreaterThanOrEqual(0);
  });
});

describe('GET /api/admin/eval/stats', () => {
  test('参与率/完成率/星级分布', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /AS total_tasks/, result: [{ total_tasks: '9', submitted_tasks: '3', task_students: '1', submitted_students: '1', term: '2025-2026-2' }] },
      { match: /SELECT answers_json/, result: [
        { answers_json: [{ questionId: 'q-1', score: 5 }, { questionId: 'q-4', score: 4 }] }
      ] }
    ]);
    const res = await request(app).get('/api/admin/eval/stats').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.participationRate).toBe(100);
    expect(res.body.data.completionRate).toBe(33);
    expect(res.body.data.averageScore).toBe(4.5);
    expect(res.body.data.ratingDistribution.find((b) => b.star === 5).count).toBe(1);
  });
});

describe('GET /api/admin/students/:id', () => {
  test('学生不存在 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [] }]);
    const res = await request(app).get('/api/admin/students/nosuch').set('Authorization', adm);
    expect(res.status).toBe(404);
  });

  test('返回真实档案字段', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [{
      student_id: '2023307020941', name: '李仕炜', college: '电子信息工程学院', major: '计算机科学与技术',
      class_name: '23计算机科学与技术U9', grade: '2023级', phone: null, email: 'a@qq.com'
    }] }]);
    const res = await request(app).get('/api/admin/students/2023307020941').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('李仕炜');
    expect(res.body.data.grade).toBe('2023级');
    expect(res.body.data.phone).toBe('');
  });
});

describe('课程管理 CRUD', () => {
  const courseRow = {
    course_id: 'ac-1', code: 'CS101', name: '测试课程', teacher: '张老师', category: 'required',
    credit: '2.0', capacity: 50, status: 'open', weekday: 1, period_start: 3, period_end: 4,
    weeks_text: null, selected_count: 0
  };

  test('GET 列表 → mapCourse 形状', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FROM dtest2\.courses c/, result: [courseRow] }]);
    const res = await request(app).get('/api/admin/courses').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data[0].timeText).toBe('周一 3-4 节');
  });

  test('POST 非法载荷 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/courses').set('Authorization', adm)
      .send({ code: '', name: 'x', teacher: 'y', category: 'required', credit: 2, capacity: 50, status: 'open', timeText: '周一 3-4 节' });
    expect(res.status).toBe(400);
  });

  test('POST 解析 timeText 落结构化排课', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /INSERT INTO dtest2\.courses/, result: [] },
      { match: /FROM dtest2\.courses c/, result: [courseRow] }
    ]);
    const res = await request(app).post('/api/admin/courses').set('Authorization', adm)
      .send({ code: 'CS101', name: '测试课程', teacher: '张老师', category: 'required', credit: 2, capacity: 50, status: 'open', timeText: '周一 3-4 节' });
    expect(res.status).toBe(200);
    const insert = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.courses') >= 0);
    expect(insert.params).toContain(1);
    expect(insert.params).toContain(3);
    expect(insert.params).toContain(4);
  });

  test('PUT 课程不存在 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /UPDATE dtest2\.courses SET/, result: [] }]);
    const res = await request(app).put('/api/admin/courses/nosuch').set('Authorization', adm)
      .send({ code: 'CS101', name: '测试课程', teacher: '张老师', category: 'required', credit: 2, capacity: 50, status: 'open', timeText: '集中实践' });
    expect(res.status).toBe(404);
  });

  test('DELETE 成功', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /DELETE FROM dtest2\.courses/, result: [{ d: 1 }] }]);
    const res = await request(app).delete('/api/admin/courses/ac-1').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.deleted).toBe(true);
  });
});
