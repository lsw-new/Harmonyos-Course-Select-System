// 分支覆盖补测 #2：把 branches 拉过 80%。聚焦既有用例未触达的守卫/4xx/409/catch→500 分支：
// 教师端全域（无 profile 守卫、归属 403、状态机 409、catch、资料校验矩阵）+ 消息/推送/反馈/请假/评教/课表
// 的缺失 studentId、长度上限、404/409、catch。仅新增测试，不改业务代码。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const teacher = `Bearer ${signToken({ sub: 'T001', role: 'teacher' })}`;
const student = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
// 故意不带 sub：currentStudentId 返回空串，命中各端点「缺少 studentId」400 分支。
const noSub = `Bearer ${signToken({ role: 'student' })}`;

// teacher_profiles 姓名解析（教师端每个端点先调用）
const NAME = { match: /FROM dtest2\.teacher_profiles WHERE teacher_id/, result: [{ name: '张伟' }] };
const NO_NAME = { match: /FROM dtest2\.teacher_profiles WHERE teacher_id/, result: [] };
const boom = new Error('boom');

beforeEach(() => __mock.reset());

// ===================== 教师端：无 profile 守卫 + catch =====================
describe('教师端 无 profile 守卫与 catch→500', () => {
  test('dashboard 无 profile → 空概览', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/dashboard').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.courseCount).toBe(0);
    expect(res.body.data.evalAvg).toBeNull();
  });

  test('dashboard 主查询抛错 → 500', async () => {
    __mock.setRoutes([NAME, { match: /AS course_count/, result: boom }]);
    const res = await request(app).get('/api/teacher/dashboard').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('dashboard 评教答卷聚合数值评分 → evalAvg', async () => {
    __mock.setRoutes([
      NAME,
      { match: /AS course_count/, result: [{ course_count: 1, student_count: 2, pending_grade_count: 0, eval_submitted: 1 }] },
      { match: /FROM dtest2\.evaluation_submissions es/, result: [
        { answers_json: [{ questionId: 'q1', value: 5 }, { questionId: 'q2', value: '3' }, { questionId: 'q3', value: 'x' }] }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/dashboard').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.evalAvg).toBe(4);
  });

  test('courses 无 profile → 空数组', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/courses').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('courses 主查询抛错 → 500', async () => {
    __mock.setRoutes([NAME, { match: /gt\.task_id, gt\.course_id, gt\.term/, result: boom }]);
    const res = await request(app).get('/api/teacher/courses').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('courses 正常映射（默认值兜底）', async () => {
    __mock.setRoutes([NAME, { match: /gt\.task_id, gt\.course_id, gt\.term/, result: [
      { task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', grade_status: 'inputting', input_progress: null, code: '', name: '高数', category: '', credit: null, student_count: null }
    ] }]);
    const res = await request(app).get('/api/teacher/courses').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].credit).toBe(0);
    expect(res.body.data[0].studentCount).toBe(0);
  });

  test('evaluations 无 profile → 空数组', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/evaluations').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('evaluations 聚合均值 + catch', async () => {
    __mock.setRoutes([
      NAME,
      { match: /AS task_count/, result: [{ course_id: 'c1', course_name: '高数', term: '2025-2026-2', task_count: 2, submitted_count: 1 }] },
      { match: /FROM dtest2\.evaluation_submissions es/, result: [
        { course_id: 'c1', answers_json: [{ value: 4 }, { value: 6 }, { value: null }] }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/evaluations').set('Authorization', teacher);
    expect(res.status).toBe(200);
    // value:null 经 Number(null)=0 计入 → (4+6+0)/3 = 3.3
    expect(res.body.data[0].avgScore).toBe(3.3);
  });

  test('evaluations 主查询抛错 → 500', async () => {
    __mock.setRoutes([NAME, { match: /AS task_count/, result: boom }]);
    const res = await request(app).get('/api/teacher/evaluations').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('schedule 无 profile → 空数组', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/schedule').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('schedule 抛错 → 500；正常映射 classroom/week_text 兜底', async () => {
    __mock.setRoutes([NAME, { match: /FROM dtest2\.class_schedule_items\s+WHERE teacher =/, result: boom }]);
    let res = await request(app).get('/api/teacher/schedule').set('Authorization', teacher);
    expect(res.status).toBe(500);

    __mock.setRoutes([NAME, { match: /FROM dtest2\.class_schedule_items\s+WHERE teacher =/, result: [
      { item_id: 'i1', course_name: '高数', class_name: 'A', weekday: 1, period_start: 1, period_end: 2, start_time: '08:00', end_time: '09:40', classroom: null, week_text: null, term: '2025-2026-2' }
    ] }]);
    res = await request(app).get('/api/teacher/schedule').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].classroom).toBe('');
    expect(res.body.data[0].weekText).toBe('');
  });

  test('grade-distribution 无归属 → 403；catch → 500；正常兜底', async () => {
    __mock.setRoutes([NAME, { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }]);
    let res = await request(app).get('/api/teacher/courses/c1/grade-distribution').set('Authorization', teacher);
    expect(res.status).toBe(403);

    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /count\(\*\) FILTER \(WHERE score >= 90\)/, result: boom }
    ]);
    res = await request(app).get('/api/teacher/courses/c1/grade-distribution').set('Authorization', teacher);
    expect(res.status).toBe(500);

    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /count\(\*\) FILTER \(WHERE score >= 90\)/, result: [{ excellent: null, good: null, medium: null, pass: null, fail: null, total: null, avg_score: null }] }
    ]);
    res = await request(app).get('/api/teacher/courses/c1/grade-distribution').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.total).toBe(0);
    expect(res.body.data.avgScore).toBe(0);
  });

  test('students 无归属 → 403；catch → 500', async () => {
    __mock.setRoutes([NAME, { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }]);
    let res = await request(app).get('/api/teacher/courses/c1/students').set('Authorization', teacher);
    expect(res.status).toBe(403);

    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'published' }] },
      { match: /SELECT cs\.student_id, COALESCE\(sp\.name/, result: boom }
    ]);
    res = await request(app).get('/api/teacher/courses/c1/students').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('students 正常：published 标记 + null 成绩兜底', async () => {
    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'published' }] },
      { match: /SELECT cs\.student_id, COALESCE\(sp\.name/, result: [
        { student_id: 's1', name: '李四', class_name: 'A', score: null, grade_point: null, rank: null, status: 'none' }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/courses/c1/students').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.published).toBe(true);
    expect(res.body.data.students[0].score).toBeNull();
  });
});

// ===================== 教师端：录入成绩状态机 =====================
describe('教师端 POST grades 校验/状态机/事务', () => {
  const base = '/api/teacher/courses/c1/grades';

  test('无 scores → 400', async () => {
    const res = await request(app).post(base).set('Authorization', teacher).send({});
    expect(res.status).toBe(400);
  });

  test('分数越界 → 400', async () => {
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 200 }] });
    expect(res.status).toBe(400);
  });

  test('无 profile → 403', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 80 }] });
    expect(res.status).toBe(403);
  });

  test('无归属任务 → 403 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE/, result: [] }]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 80 }] });
    expect(res.status).toBe(403);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('已发布 → 409', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'published' }] }]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 80 }] });
    expect(res.status).toBe(409);
  });

  test('名单外学生 → 400 + ROLLBACK', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FOR UPDATE/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [] }
    ]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 80 }] });
    expect(res.status).toBe(400);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('成功：进度满 100 → pendingAudit（含 <60 绩点=0）', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FOR UPDATE/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [{ student_id: 's1' }] },
      { match: /INSERT INTO dtest2\.grades/, result: [] },
      { match: /SET rank = r\.rnk/, result: [] },
      { match: /AS total,/, result: [{ total: 1, scored: 1 }] },
      { match: /UPDATE dtest2\.grade_tasks SET input_progress/, result: [] }
    ]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 50 }] });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('pendingAudit');
    expect(res.body.data.inputProgress).toBe(100);
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('成功：总数 0 → 进度 0 inputting', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FOR UPDATE/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [{ student_id: 's1' }] },
      { match: /INSERT INTO dtest2\.grades/, result: [] },
      { match: /SET rank = r\.rnk/, result: [] },
      { match: /AS total,/, result: [{ total: 0, scored: 0 }] },
      { match: /UPDATE dtest2\.grade_tasks SET input_progress/, result: [] }
    ]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 88 }] });
    expect(res.status).toBe(200);
    expect(res.body.data.inputProgress).toBe(0);
    expect(res.body.data.status).toBe('inputting');
  });

  test('事务内抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE/, result: boom }]);
    const res = await request(app).post(base).set('Authorization', teacher).send({ scores: [{ studentId: 's1', score: 80 }] });
    expect(res.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });
});

// ===================== 教师端：课程通知发布/列表/撤回 =====================
describe('教师端 课程通知', () => {
  test('POST notices 标题为空 → 400', async () => {
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher).send({ courseId: 'c1', title: '', content: 'x' });
    expect(res.status).toBe(400);
  });

  test('POST notices 过长 → 400', async () => {
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher)
      .send({ courseId: 'c1', title: 'a'.repeat(101), content: 'x' });
    expect(res.status).toBe(400);
  });

  test('POST notices 无归属 → 403', async () => {
    __mock.setRoutes([NAME, { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher)
      .send({ courseId: 'c1', title: '通知', content: '内容' });
    expect(res.status).toBe(403);
  });

  test('POST notices 成功：写 notices + 给本班学生发消息（summary 截断）', async () => {
    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /COALESCE\(name,''\) AS name FROM dtest2\.courses/, result: [{ name: '高数' }] },
      { match: /INSERT INTO dtest2\.notices/, result: [] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [{ student_id: 's1' }, { student_id: 's2' }] }
    ]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher)
      .send({ courseId: 'c1', title: '停课通知', content: 'x'.repeat(80) });
    expect(res.status).toBe(200);
    expect(res.body.data.recipients).toBe(2);
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('POST notices 成功：课程名缺失回退「课程」', async () => {
    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /COALESCE\(name,''\) AS name FROM dtest2\.courses/, result: [] },
      { match: /INSERT INTO dtest2\.notices/, result: [] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher)
      .send({ courseId: 'c1', title: '短', content: '短内容' });
    expect(res.status).toBe(200);
    expect(res.body.data.recipients).toBe(0);
  });

  test('POST notices 事务抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([
      NAME,
      { match: /WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 't1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: 'A', status: 'inputting' }] },
      { match: /COALESCE\(name,''\) AS name FROM dtest2\.courses/, result: boom }
    ]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher)
      .send({ courseId: 'c1', title: '通知', content: '内容' });
    expect(res.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('GET notices 无 profile → 空数组', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/notices').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('GET notices 正常映射（summary null 兜底）+ catch', async () => {
    __mock.setRoutes([NAME, { match: /WHERE publisher=\$1 AND category=/, result: [
      { notice_id: 'n1', title: 'T', summary: null, category: '课程通知', urgency: 'normal', published_at: '2026-01-01' }
    ] }]);
    let res = await request(app).get('/api/teacher/notices').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].summary).toBe('');

    __mock.setRoutes([NAME, { match: /WHERE publisher=\$1 AND category=/, result: boom }]);
    res = await request(app).get('/api/teacher/notices').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('withdraw 无 profile → 403', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).post('/api/teacher/notices/n1/withdraw').set('Authorization', teacher);
    expect(res.status).toBe(403);
  });

  test('withdraw 非本人/不存在 → 403 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /WHERE notice_id=\$1 AND publisher=\$2/, result: [] }]);
    const res = await request(app).post('/api/teacher/notices/n1/withdraw').set('Authorization', teacher);
    expect(res.status).toBe(403);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('withdraw 成功：删消息 + 删通知', async () => {
    __mock.setRoutes([
      NAME,
      { match: /WHERE notice_id=\$1 AND publisher=\$2/, result: [{ notice_id: 'n1' }] },
      { match: /DELETE FROM dtest2\.messages WHERE route=/, result: [] },
      { match: /DELETE FROM dtest2\.notices WHERE notice_id=/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/notices/n1/withdraw').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.withdrawn).toBe(true);
  });

  test('withdraw 事务抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /WHERE notice_id=\$1 AND publisher=\$2/, result: boom }]);
    const res = await request(app).post('/api/teacher/notices/n1/withdraw').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });
});

// ===================== 教师端：评教细分 =====================
describe('教师端 eval-breakdown', () => {
  const url = '/api/teacher/courses/c1/eval-breakdown';
  test('无 profile → 403', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get(url).set('Authorization', teacher);
    expect(res.status).toBe(403);
  });

  test('无归属评教任务 → 403', async () => {
    __mock.setRoutes([NAME, { match: /SELECT 1 FROM dtest2\.evaluation_tasks WHERE course_id=/, result: [] }]);
    const res = await request(app).get(url).set('Authorization', teacher);
    expect(res.status).toBe(403);
  });

  test('正常：题目均分 + 跳过缺 questionId / 非数值', async () => {
    __mock.setRoutes([
      NAME,
      { match: /SELECT 1 FROM dtest2\.evaluation_tasks WHERE course_id=/, result: [{ '?column?': 1 }] },
      { match: /FROM dtest2\.evaluation_templates t/, result: [
        { questions_json: [{ id: 1, title: '教学态度' }, { id: 2, title: null }, { id: null, title: 'x' }] }
      ] },
      { match: /FROM dtest2\.evaluation_submissions es/, result: [
        { answers_json: [{ questionId: 1, value: 5 }, { questionId: 2, value: 'NaN' }, { questionId: null, value: 3 }, { value: 4 }] },
        { answers_json: 'not-array' }
      ] }
    ]);
    const res = await request(app).get(url).set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.find((d) => d.questionId === '1').avg).toBe(5);
    expect(res.body.data.find((d) => d.questionId === '1').title).toBe('教学态度');
    // id=2 标题为空 → 回退用 qid 作标题
    expect(res.body.data.find((d) => d.questionId === '2')).toBeUndefined();
  });

  test('catch → 500', async () => {
    __mock.setRoutes([NAME, { match: /SELECT 1 FROM dtest2\.evaluation_tasks WHERE course_id=/, result: boom }]);
    const res = await request(app).get(url).set('Authorization', teacher);
    expect(res.status).toBe(500);
  });
});

// ===================== 教师端：成绩申诉列表/处理 =====================
describe('教师端 成绩申诉', () => {
  test('GET 无 profile → 空数组', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).get('/api/teacher/grade-appeals').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('GET 正常映射（空值兜底）+ catch', async () => {
    __mock.setRoutes([NAME, { match: /FROM dtest2\.grade_appeals ga/, result: [
      { appeal_id: 'a1', student_id: 's1', course_id: null, term: null, reason: 'r', status: 'pending', reply: null, submitted_at: '2026-01-01', student_name: '李四', course_name: '高数' }
    ] }]);
    let res = await request(app).get('/api/teacher/grade-appeals').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].courseId).toBe('');
    expect(res.body.data[0].reply).toBe('');

    __mock.setRoutes([NAME, { match: /FROM dtest2\.grade_appeals ga/, result: boom }]);
    res = await request(app).get('/api/teacher/grade-appeals').set('Authorization', teacher);
    expect(res.status).toBe(500);
  });

  test('handle 决策不合法 → 400', async () => {
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'maybe' });
    expect(res.status).toBe(400);
  });

  test('handle 无 profile → 403', async () => {
    __mock.setRoutes([NO_NAME]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'accepted' });
    expect(res.status).toBe(403);
  });

  test('handle 非本人/不存在 → 403 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE OF ga/, result: [] }]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'rejected' });
    expect(res.status).toBe(403);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('handle 已处理 → 409', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE OF ga/, result: [{ status: 'accepted', task_id: 't1', student_id: 's1', course_name: '高数' }] }]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'accepted' });
    expect(res.status).toBe(409);
  });

  test('handle 受理成功：联动任务 appealed + 消息回执', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FOR UPDATE OF ga/, result: [{ status: 'pending', task_id: 't1', student_id: 's1', course_name: '高数' }] },
      { match: /UPDATE dtest2\.grade_appeals SET status=/, result: [] },
      { match: /UPDATE dtest2\.grade_tasks SET status='appealed'/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'accepted', reply: '已复核' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('accepted');
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('handle 驳回成功：无 task_id 不联动', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FOR UPDATE OF ga/, result: [{ status: 'pending', task_id: null, student_id: 's1', course_name: null }] },
      { match: /UPDATE dtest2\.grade_appeals SET status=/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'rejected' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('rejected');
  });

  test('handle 事务抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([NAME, { match: /FOR UPDATE OF ga/, result: boom }]);
    const res = await request(app).post('/api/teacher/grade-appeals/a1/handle').set('Authorization', teacher).send({ decision: 'accepted' });
    expect(res.status).toBe(500);
  });
});

// ===================== 教师端：本人资料更新校验矩阵 =====================
describe('教师端 PUT profile', () => {
  test('邮箱格式错误 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: 'bad' });
    expect(res.status).toBe(400);
  });

  test('头像非法 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ avatarUrl: 'ftp://x' });
    expect(res.status).toBe(400);
  });

  test('无可更新字段 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({});
    expect(res.status).toBe(400);
  });

  test('清空头像（空串）+ 邮箱更新成功', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: [{ teacher_id: 'T001' }] }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher)
      .send({ email: 'a@b.com', avatarUrl: '' });
    expect(res.status).toBe(200);
    expect(res.body.data.email).toBe('a@b.com');
  });

  test('http(s) 外链头像成功', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: [{ teacher_id: 'T001' }] }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher)
      .send({ avatarUrl: 'https://cdn.example.com/a.png' });
    expect(res.status).toBe(200);
  });

  test('对象存储 URL 头像成功', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: [{ teacher_id: 'T001' }] }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher)
      .send({ avatarUrl: '/api/uploads/up-12345678-1234-1234-1234-123456789abc' });
    expect(res.status).toBe(200);
  });

  test('教师资料不存在 → 404', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: [] }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: 'a@b.com' });
    expect(res.status).toBe(404);
  });

  test('更新抛错 → 500', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: boom }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: 'a@b.com' });
    expect(res.status).toBe(500);
  });

  test('空串邮箱（清除）不校验格式', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.teacher_profiles SET/, result: [{ teacher_id: 'T001' }] }]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: '   ' });
    expect(res.status).toBe(200);
  });
});

// ===================== 消息中心：缺少 studentId + catch =====================
describe('消息中心 守卫与 catch', () => {
  test('GET messages 缺 studentId → 400', async () => {
    const res = await request(app).get('/api/messages').set('Authorization', noSub);
    expect(res.status).toBe(400);
  });
  test('GET messages catch → 500；正常 null 字段兜底', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.messages/, result: boom }]);
    let res = await request(app).get('/api/messages').set('Authorization', student);
    expect(res.status).toBe(500);
    __mock.setRoutes([{ match: /FROM dtest2\.messages\s+WHERE student_id/, result: [
      { message_id: 'm1', kind: 'system', title: 'T', body: null, route: null, param: null, read_at: null, created_at: '2026-01-01' }
    ] }]);
    res = await request(app).get('/api/messages').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.body.data[0].read).toBe(false);
    expect(res.body.data[0].body).toBe('');
  });
  test('unread-count 缺 studentId → 400；空结果 → 0；catch', async () => {
    let res = await request(app).get('/api/messages/unread-count').set('Authorization', noSub);
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /COUNT\(\*\)::int AS count/, result: [] }]);
    res = await request(app).get('/api/messages/unread-count').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.body.data.count).toBe(0);
    __mock.setRoutes([{ match: /COUNT\(\*\)::int AS count/, result: boom }]);
    res = await request(app).get('/api/messages/unread-count').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('read-all 缺 studentId → 400；catch', async () => {
    let res = await request(app).post('/api/messages/read-all').set('Authorization', noSub);
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /UPDATE dtest2\.messages SET read_at/, result: boom }]);
    res = await request(app).post('/api/messages/read-all').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('单条已读 缺 studentId → 400；不存在 → 404；catch', async () => {
    let res = await request(app).post('/api/messages/m1/read').set('Authorization', noSub);
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /UPDATE dtest2\.messages SET read_at = now\(\)\s+WHERE message_id/, result: [] }]);
    res = await request(app).post('/api/messages/m1/read').set('Authorization', student);
    expect(res.status).toBe(404);
    __mock.setRoutes([{ match: /UPDATE dtest2\.messages SET read_at = now\(\)\s+WHERE message_id/, result: boom }]);
    res = await request(app).post('/api/messages/m1/read').set('Authorization', student);
    expect(res.status).toBe(500);
  });
});

// ===================== 推送 token：缺少 studentId + catch =====================
describe('推送 token 守卫与 catch', () => {
  test('POST 缺 studentId → 400', async () => {
    const res = await request(app).post('/api/push/tokens').set('Authorization', noSub).send({ token: 'x' });
    expect(res.status).toBe(400);
  });
  test('POST token 为空 → 400', async () => {
    const res = await request(app).post('/api/push/tokens').set('Authorization', student).send({ token: '  ' });
    expect(res.status).toBe(400);
  });
  test('POST catch → 500；成功（platform 缺省 null）', async () => {
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.device_tokens/, result: boom }]);
    let res = await request(app).post('/api/push/tokens').set('Authorization', student).send({ token: 'tk1' });
    expect(res.status).toBe(500);
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.device_tokens/, result: [] }]);
    res = await request(app).post('/api/push/tokens').set('Authorization', student).send({ token: 'tk1' });
    expect(res.status).toBe(200);
    expect(res.body.data.registered).toBe(true);
  });
  test('DELETE 缺 studentId → 400；token 空 → 400；catch；成功', async () => {
    let res = await request(app).delete('/api/push/tokens').set('Authorization', noSub).send({ token: 'x' });
    expect(res.status).toBe(400);
    res = await request(app).delete('/api/push/tokens').set('Authorization', student).send({ token: '' });
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /DELETE FROM dtest2\.device_tokens/, result: boom }]);
    res = await request(app).delete('/api/push/tokens').set('Authorization', student).send({ token: 'tk1' });
    expect(res.status).toBe(500);
    __mock.setRoutes([{ match: /DELETE FROM dtest2\.device_tokens/, result: [{ token_id: 'p1' }] }]);
    res = await request(app).delete('/api/push/tokens').set('Authorization', student).send({ token: 'tk1' });
    expect(res.status).toBe(200);
    expect(res.body.data.removed).toBe(1);
  });
});

// ===================== 反馈：长度上限 + catch =====================
describe('反馈 校验上限与 catch', () => {
  test('GET feedback 缺 studentId → 400；catch', async () => {
    let res = await request(app).get('/api/feedback').set('Authorization', noSub);
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.feedback_items f/, result: boom }]);
    res = await request(app).get('/api/feedback').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('信息不完整 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'bug', title: '', content: 'x' });
    expect(res.status).toBe(400);
  });
  test('类型不合法 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'weird', title: 'T', content: 'x' });
    expect(res.status).toBe(400);
  });
  test('标题过长 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'bug', title: 'a'.repeat(101), content: 'x' });
    expect(res.status).toBe(400);
  });
  test('内容过长 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'bug', title: 'T', content: 'a'.repeat(5001) });
    expect(res.status).toBe(400);
  });
  test('联系方式过长 → 400', async () => {
    const res = await request(app).post('/api/feedback').set('Authorization', student)
      .send({ category: 'bug', title: 'T', content: 'x', contact: 'a'.repeat(101) });
    expect(res.status).toBe(400);
  });
  test('提交成功（contact 空 → null）+ catch', async () => {
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.feedback_items/, result: [
      { feedback_id: 'fb1', student_id: '2023307020941', category: 'bug', title: 'T', content: 'x', contact: '', state: 'submitted', submitted_at: '2026-01-01', reply: null, replied_by: null, replied_at: null }
    ] }]);
    let res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'bug', title: 'T', content: 'x' });
    expect(res.status).toBe(200);
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.feedback_items/, result: boom }]);
    res = await request(app).post('/api/feedback').set('Authorization', student).send({ category: 'bug', title: 'T', content: 'x' });
    expect(res.status).toBe(500);
  });
});

// ===================== 请假：校验/状态机/catch =====================
describe('请假 校验与状态机', () => {
  test('GET leave 缺 studentId → 400；catch', async () => {
    let res = await request(app).get('/api/leave').set('Authorization', noSub);
    expect(res.status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.leave_requests WHERE student_id/, result: boom }]);
    res = await request(app).get('/api/leave').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('GET leave 正常：挂多级审批步骤', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.leave_requests WHERE student_id/, result: [{ leave_id: 'lv1', type: 'sick', start_date: '2026-01-01', end_date: '2026-01-02', reason: 'r', status: 'pending', feedback: '', submitted_at: '2026-01-01' }] },
      { match: /FROM dtest2\.approval_steps WHERE approval_id = ANY/, result: [
        { approval_id: 'ap-lv1', step_order: 1, node_name: '教务审批', approver_role: '教务管理员', operator_id: null, status: 'pending', handled_at: null, comment: null }
      ] }
    ]);
    const res = await request(app).get('/api/leave').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.body.data[0].steps.length).toBe(1);
  });
  test('POST leave 信息不完整 → 400', async () => {
    const res = await request(app).post('/api/leave').set('Authorization', student).send({ type: 'sick' });
    expect(res.status).toBe(400);
  });
  test('POST leave 类型不合法 → 400', async () => {
    const res = await request(app).post('/api/leave').set('Authorization', student)
      .send({ type: 'weird', startDate: '2026-01-01', endDate: '2026-01-02', reason: 'r' });
    expect(res.status).toBe(400);
  });
  test('POST leave 理由过长 → 400', async () => {
    const res = await request(app).post('/api/leave').set('Authorization', student)
      .send({ type: 'sick', startDate: '2026-01-01', endDate: '2026-01-02', reason: 'a'.repeat(501) });
    expect(res.status).toBe(400);
  });
  test('POST leave 成功：无审批流配置回退单节点', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.leave_requests/, result: [{ leave_id: 'lv1', type: 'sick', start_date: '2026-01-01', end_date: '2026-01-02', reason: 'r', status: 'pending', feedback: '', submitted_at: '2026-01-01' }] },
      { match: /SELECT name FROM dtest2\.student_profiles WHERE student_id/, result: [] },
      { match: /INSERT INTO dtest2\.approval_instances/, result: [] },
      { match: /FROM dtest2\.approval_flow_nodes/, result: [] },
      { match: /INSERT INTO dtest2\.approval_steps/, result: [] },
      { match: /FROM dtest2\.approval_steps WHERE approval_id = \$1/, result: [
        { step_order: 1, node_name: '教务审批', approver_role: '教务管理员', operator_id: null, status: 'pending', handled_at: null, comment: null }
      ] }
    ]);
    const res = await request(app).post('/api/leave').set('Authorization', student)
      .send({ type: 'sick', startDate: '2026-01-01', endDate: '2026-01-02', reason: 'r' });
    expect(res.status).toBe(200);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
  test('POST leave 成功：多节点审批流（首步 pending 余步 waiting）', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.leave_requests/, result: [{ leave_id: 'lv2', type: 'personal', start_date: '2026-01-01', end_date: '2026-01-02', reason: 'r', status: 'pending', feedback: '', submitted_at: '2026-01-01' }] },
      { match: /SELECT name FROM dtest2\.student_profiles WHERE student_id/, result: [{ name: '王五' }] },
      { match: /INSERT INTO dtest2\.approval_instances/, result: [] },
      { match: /FROM dtest2\.approval_flow_nodes/, result: [
        { name: '辅导员审批', approver_role: '辅导员', node_order: 1 },
        { name: '教务审批', approver_role: '教务管理员', node_order: 2 }
      ] },
      { match: /INSERT INTO dtest2\.approval_steps/, result: [] },
      { match: /FROM dtest2\.approval_steps WHERE approval_id = \$1/, result: [] }
    ]);
    const res = await request(app).post('/api/leave').set('Authorization', student)
      .send({ type: 'personal', startDate: '2026-01-01', endDate: '2026-01-02', reason: 'r' });
    expect(res.status).toBe(200);
  });
  test('POST leave 事务抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.leave_requests/, result: boom }]);
    const res = await request(app).post('/api/leave').set('Authorization', student)
      .send({ type: 'sick', startDate: '2026-01-01', endDate: '2026-01-02', reason: 'r' });
    expect(res.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });
  test('withdraw 缺 studentId → 400', async () => {
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', noSub);
    expect(res.status).toBe(400);
  });
  test('withdraw 不存在 → 404', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: [] }]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', student);
    expect(res.status).toBe(404);
  });
  test('withdraw 已撤回 → 409（专属文案）', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: [{ status: 'withdrawn' }] }]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', student);
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('已撤回');
  });
  test('withdraw 已驳回 → 409（通用文案）', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: [{ status: 'rejected' }] }]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', student);
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('不可撤回');
  });
  test('withdraw 成功', async () => {
    __mock.setRoutes([
      { match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: [{ status: 'pending' }] },
      { match: /UPDATE dtest2\.leave_requests SET status = 'withdrawn'/, result: [{ leave_id: 'lv1', type: 'sick', start_date: '2026-01-01', end_date: '2026-01-02', reason: 'r', status: 'withdrawn', feedback: '', submitted_at: '2026-01-01' }] }
    ]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
  test('withdraw 事务抛错 → 500', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.leave_requests WHERE leave_id/, result: boom }]);
    const res = await request(app).post('/api/leave/lv1/withdraw').set('Authorization', student);
    expect(res.status).toBe(500);
  });
});

// ===================== 评教：缺 studentId / 上限 / 状态机 =====================
describe('评教 守卫与状态机', () => {
  test('GET evaluations 缺 studentId → 400', async () => {
    const res = await request(app).get('/api/evaluations').set('Authorization', noSub);
    expect(res.status).toBe(400);
  });
  test('submit 缺 studentId → 400', async () => {
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', noSub).send({ answers: [{}] });
    expect(res.status).toBe(400);
  });
  test('submit 答案为空 → 400', async () => {
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [] });
    expect(res.status).toBe(400);
  });
  test('submit 答案条目过多 → 400', async () => {
    const answers = new Array(101).fill({ questionId: 1, value: 5 });
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers });
    expect(res.status).toBe(400);
  });
  test('submit 答案格式不合法 → 400', async () => {
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: ['x'] });
    expect(res.status).toBe(400);
  });
  test('submit 评教期未开放 → 409', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.system_settings WHERE key/, result: [{ value_json: false }] }]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(409);
  });
  test('submit 评教期查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.system_settings WHERE key/, result: boom }]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(500);
  });
  test('submit 任务不存在 → 404', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.system_settings WHERE key/, result: [] },
      { match: /SELECT status FROM dtest2\.evaluation_tasks WHERE task_id/, result: [] }
    ]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(404);
  });
  test('submit 任务非开放 → 409', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.system_settings WHERE key/, result: [] },
      { match: /SELECT status FROM dtest2\.evaluation_tasks WHERE task_id/, result: [{ status: 'submitted' }] }
    ]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(409);
  });
  test('submit 成功', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.system_settings WHERE key/, result: [] },
      { match: /SELECT status FROM dtest2\.evaluation_tasks WHERE task_id/, result: [{ status: 'open' }] },
      { match: /INSERT INTO dtest2\.evaluation_submissions/, result: [] },
      { match: /UPDATE dtest2\.evaluation_tasks SET status='submitted'/, result: [] }
    ]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(200);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
  test('submit 事务抛错 → 500 + ROLLBACK', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.system_settings WHERE key/, result: [] },
      { match: /SELECT status FROM dtest2\.evaluation_tasks WHERE task_id/, result: boom }
    ]);
    const res = await request(app).post('/api/evaluations/t1/submit').set('Authorization', student).send({ answers: [{ questionId: 1, value: 5 }] });
    expect(res.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });
});

// ===================== 课表（学生端）：缺 studentId / 404 / ical =====================
describe('班级课表 守卫与导出', () => {
  test('GET schedule 缺 studentId → 400', async () => {
    const res = await request(app).get('/api/schedule').set('Authorization', noSub);
    expect(res.status).toBe(400);
  });
  test('GET schedule 无班级 → 404（名册空 + 资料空）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [] },
      { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', student);
    expect(res.status).toBe(404);
  });
  test('GET schedule 班级=待完善 → 404（资料回退）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [] },
      { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [{ class_name: '待完善' }] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', student);
    expect(res.status).toBe(404);
  });
  test('GET schedule catch → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.class_students WHERE student_id/, result: boom }]);
    const res = await request(app).get('/api/schedule').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('GET schedule 正常（campus/weeks 兜底）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [{ class_name: '软件2301' }] },
      { match: /FROM dtest2\.class_schedule_items\s+WHERE class_name/, result: [
        { item_id: 'i1', class_name: '软件2301', term: '2025-2026-2', type: 'theory', course_id: 'c1', course_name: '高数', teacher: '张伟', weekday: 1, period_start: 1, period_end: 2, start_time: '08:00', end_time: '09:40', classroom: 'A101', campus: null, weeks: null, week_text: '1-16', course_type: '必修' }
      ] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.body.data.items[0].campus).toBeUndefined();
    expect(res.body.data.items[0].weeks).toEqual([]);
  });
  test('GET ical 缺 studentId → 400', async () => {
    const res = await request(app).get('/api/schedule/ical').set('Authorization', noSub);
    expect(res.status).toBe(400);
  });
  test('GET ical 无班级 → 404', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [] },
      { match: /FROM dtest2\.student_profiles WHERE student_id/, result: [] }
    ]);
    const res = await request(app).get('/api/schedule/ical').set('Authorization', student);
    expect(res.status).toBe(404);
  });
  test('GET ical catch → 500', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [{ class_name: '软件2301' }] },
      { match: /FROM dtest2\.class_schedule_items\s+WHERE class_name/, result: boom }
    ]);
    const res = await request(app).get('/api/schedule/ical').set('Authorization', student);
    expect(res.status).toBe(500);
  });
  test('GET ical 正常：含 VEVENT（termStart 覆盖 + 时间/周次解析分支）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [{ class_name: '软件2301' }] },
      { match: /FROM dtest2\.class_schedule_items\s+WHERE class_name/, result: [
        { item_id: 'i1', class_name: '软件2301', term: '2025-2026-2', course_name: '高数', teacher: '张伟', weekday: 1, period_start: 1, period_end: 2, start_time: '08:00', end_time: '09:40', classroom: 'A101', campus: '中心校区', weeks: [1, 2, 3], week_text: '1-3周', course_type: '必修' },
        { item_id: 'i2', class_name: '软件2301', term: '2025-2026-2', course_name: '英语', teacher: null, weekday: 9, period_start: 3, period_end: 4, start_time: 'bad', end_time: null, classroom: null, campus: null, weeks: null, week_text: null, course_type: null }
      ] }
    ]);
    const res = await request(app).get('/api/schedule/ical?termStart=2026-03-02').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/calendar');
    expect(res.text).toContain('BEGIN:VEVENT');
    expect(res.text).toContain('RRULE:FREQ=WEEKLY;COUNT=3');
  });
  test('GET ical 非法 termStart → 回退默认起始周一', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students WHERE student_id/, result: [{ class_name: '软件2301' }] },
      { match: /FROM dtest2\.class_schedule_items\s+WHERE class_name/, result: [] }
    ]);
    const res = await request(app).get('/api/schedule/ical?termStart=not-a-date').set('Authorization', student);
    expect(res.status).toBe(200);
    expect(res.text).toContain('END:VCALENDAR');
  });
});
