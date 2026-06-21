// 教师端域（roadmap #6）：角色守卫 + 工作台 + 我的课程 + 学生名单（归属鉴权）+ 录入成绩 + 评教结果。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const teacher = `Bearer ${signToken({ sub: 'T001', role: 'teacher' })}`;
const student = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;

// teacher_profiles 姓名解析（几乎每个端点先调用）
const NAME = { match: /FROM dtest2\.teacher_profiles WHERE teacher_id/, result: [{ name: '张伟' }] };

beforeEach(() => __mock.reset());

describe('角色守卫', () => {
  test('未授权 → 401', async () => {
    const res = await request(app).get('/api/teacher/dashboard');
    expect(res.status).toBe(401);
  });
  test('学生 token 访问教师端 → 403', async () => {
    const res = await request(app).get('/api/teacher/dashboard').set('Authorization', student);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/teacher/dashboard', () => {
  test('返回工作台四项 + 评教提交数', async () => {
    __mock.setRoutes([
      NAME,
      { match: /AS course_count/, result: [{ course_count: 3, student_count: 47, pending_grade_count: 2, eval_submitted: 10 }] }
    ]);
    const res = await request(app).get('/api/teacher/dashboard').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.courseCount).toBe(3);
    expect(res.body.data.studentCount).toBe(47);
    expect(res.body.data.pendingGradeCount).toBe(2);
    expect(res.body.data.evalAvg).toBeNull();
    // 姓名解析按 JWT 的 teacherId 收口
    const q = __mock.getLog().find((e) => e.sql.indexOf('FROM dtest2.teacher_profiles') >= 0);
    expect(q.params).toContain('T001');
  });
});

describe('GET /api/teacher/courses', () => {
  test('返回我的课程（数值字段转 number）', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks gt\s+LEFT JOIN dtest2\.courses/, result: [
        { task_id: 'gt-1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: '23U9', grade_status: 'inputting', input_progress: 40, code: 'CS101', name: '数据结构', category: 'required', credit: '3.0', student_count: 47 }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/courses').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].courseId).toBe('c1');
    expect(res.body.data[0].credit).toBe(3);
    expect(res.body.data[0].studentCount).toBe(47);
    expect(res.body.data[0].teachingClassName).toBe('23U9');
  });
});

describe('GET /api/teacher/courses/:courseId/students', () => {
  test('归属课程 → 200 名单（score/gradePoint 转 number|null）', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [
        { task_id: 'gt-1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: '23U9', status: 'inputting' }
      ] },
      { match: /FROM dtest2\.class_students cs\s+JOIN dtest2\.student_profiles sp[\s\S]*LEFT JOIN dtest2\.grades/, result: [
        { student_id: 'S1', name: '李四', class_name: '23U9', score: '88.00', grade_point: '3.80', status: 'scored' },
        { student_id: 'S2', name: '王五', class_name: '23U9', score: null, grade_point: null, status: 'none' }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/courses/c1/students').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.students).toHaveLength(2);
    expect(res.body.data.students[0].score).toBe(88);
    expect(res.body.data.students[1].score).toBeNull();
  });

  test('非本人课程（无 grade_task）→ 403', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }
    ]);
    const res = await request(app).get('/api/teacher/courses/cX/students').set('Authorization', teacher);
    expect(res.status).toBe(403);
  });
});

describe('POST /api/teacher/courses/:courseId/grades', () => {
  test('归属课程录入 → 200 并回进度', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2[\s\S]*FOR UPDATE/, result: [
        { task_id: 'gt-1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: '23U9', status: 'inputting' }
      ] },
      { match: /SELECT cs\.student_id FROM dtest2\.class_students cs/, result: [{ student_id: 'S1' }] },
      { match: /INSERT INTO dtest2\.grades/, result: [] },
      { match: /UPDATE dtest2\.grades g SET rank/, result: [] },
      { match: /AS total,/, result: [{ total: 1, scored: 1 }] },
      { match: /UPDATE dtest2\.grade_tasks SET input_progress/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/courses/c1/grades').set('Authorization', teacher).send({ scores: [{ studentId: 'S1', score: 90 }] });
    expect(res.status).toBe(200);
    expect(res.body.data.updated).toBe(1);
    expect(res.body.data.inputProgress).toBe(100);
    expect(res.body.data.status).toBe('pendingAudit');
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('非本人课程 → 403（不写库）', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2[\s\S]*FOR UPDATE/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/courses/cX/grades').set('Authorization', teacher).send({ scores: [{ studentId: 'S1', score: 90 }] });
    expect(res.status).toBe(403);
  });

  test('分数越界 → 400', async () => {
    const res = await request(app).post('/api/teacher/courses/c1/grades').set('Authorization', teacher).send({ scores: [{ studentId: 'S1', score: 150 }] });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/teacher/evaluations', () => {
  test('按课程聚合任务/已提交数', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.evaluation_tasks et/, result: [
        { course_id: 'c1', course_name: '数据结构', term: '2025-2026-2', task_count: 47, submitted_count: 30 }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/evaluations').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].taskCount).toBe(47);
    expect(res.body.data[0].submittedCount).toBe(30);
    expect(res.body.data[0].avgScore).toBeNull();
  });
});
