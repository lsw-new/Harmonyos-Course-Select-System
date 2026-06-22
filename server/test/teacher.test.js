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

describe('POST /api/teacher/notices（课程通知三端闭环）', () => {
  test('归属课程 → 200，写通知 + 给本班学生发消息', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [
        { task_id: 'gt-1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: '23U9', status: 'inputting' }
      ] },
      { match: /COALESCE\(name,''\) AS name FROM dtest2\.courses/, result: [{ name: '编译原理' }] },
      { match: /INSERT INTO dtest2\.notices/, result: [] },
      { match: /FROM dtest2\.class_students cs\s+JOIN dtest2\.student_profiles/, result: [{ student_id: 'S1' }, { student_id: 'S2' }] },
      { match: /INSERT INTO dtest2\.messages/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher).send({ courseId: 'c1', title: '周五停课', content: '本周五补考，正常课程暂停' });
    expect(res.status).toBe(200);
    expect(res.body.data.recipients).toBe(2);
    const msgs = __mock.getLog().filter((e) => e.sql.indexOf('INSERT INTO dtest2.messages') >= 0);
    expect(msgs).toHaveLength(2); // 本班 2 名学生各一条
    expect(__mock.executed('COMMIT')).toBe(true);
  });

  test('非本人课程 → 403', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher).send({ courseId: 'cX', title: 'x', content: 'y' });
    expect(res.status).toBe(403);
  });

  test('空标题 → 400', async () => {
    const res = await request(app).post('/api/teacher/notices').set('Authorization', teacher).send({ courseId: 'c1', title: '', content: 'y' });
    expect(res.status).toBe(400);
  });
});

describe('POST /api/teacher/grade-appeals/:id/handle（成绩申诉三端闭环）', () => {
  test('归属申诉受理 → 200，写回执消息给学生', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_appeals ga\s+JOIN dtest2\.grade_tasks gt[\s\S]*FOR UPDATE OF ga/, result: [
        { status: 'pending', task_id: 'gt-1', student_id: 'S9', course_name: '编译原理' }
      ] },
      { match: /UPDATE dtest2\.grade_appeals SET status/, result: [] },
      { match: /UPDATE dtest2\.grade_tasks SET status='appealed'/, result: [] },
      { match: /INSERT INTO dtest2\.messages/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/grade-appeals/ga1/handle').set('Authorization', teacher).send({ decision: 'accepted', reply: '已复核，调整 2 分' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('accepted');
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.messages') >= 0);
    expect(ins).toBeDefined();
    expect(ins.params).toContain('S9');
    expect(ins.params).toContain('grade');
  });

  test('非本人课程的申诉 → 403', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_appeals ga\s+JOIN dtest2\.grade_tasks gt[\s\S]*FOR UPDATE OF ga/, result: [] }
    ]);
    const res = await request(app).post('/api/teacher/grade-appeals/gaX/handle').set('Authorization', teacher).send({ decision: 'rejected' });
    expect(res.status).toBe(403);
  });

  test('非法处理结果 → 400', async () => {
    const res = await request(app).post('/api/teacher/grade-appeals/ga1/handle').set('Authorization', teacher).send({ decision: 'maybe' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/teacher/courses/:id/grade-distribution', () => {
  test('归属课程 → 200 分桶+均分', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [{ task_id: 'gt-1', course_id: 'c1', term: '2025-2026-2', teaching_class_name: '23U9', status: 'inputting' }] },
      { match: /FILTER \(WHERE score >= 90\)/, result: [{ excellent: 3, good: 10, medium: 20, pass: 8, fail: 6, total: 47, avg_score: '76.5' }] }
    ]);
    const res = await request(app).get('/api/teacher/courses/c1/grade-distribution').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data.total).toBe(47);
    expect(res.body.data.avgScore).toBe(76.5);
  });
  test('非本人课程 → 403', async () => {
    __mock.setRoutes([NAME, { match: /FROM dtest2\.grade_tasks\s+WHERE course_id=\$1 AND teacher_name=\$2/, result: [] }]);
    const res = await request(app).get('/api/teacher/courses/cX/grade-distribution').set('Authorization', teacher);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/teacher/schedule', () => {
  test('按姓名返回课表项', async () => {
    __mock.setRoutes([
      NAME,
      { match: /FROM dtest2\.class_schedule_items\s+WHERE teacher = \$1/, result: [
        { item_id: 'it1', course_name: '编译原理', class_name: '23U9', weekday: 1, period_start: 1, period_end: 2, start_time: '08:00', end_time: '09:40', classroom: 'A101', week_text: '1-16周', term: '2025-2026-2' }
      ] }
    ]);
    const res = await request(app).get('/api/teacher/schedule').set('Authorization', teacher);
    expect(res.status).toBe(200);
    expect(res.body.data[0].courseName).toBe('编译原理');
    expect(res.body.data[0].weekday).toBe(1);
  });
});

describe('PUT /api/teacher/profile（教师改邮箱）', () => {
  test('合法邮箱 → 200', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.teacher_profiles SET email/, result: [{}] }
    ]);
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: 'zhang@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.data.email).toBe('zhang@example.com');
  });
  test('非法邮箱 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ email: 'not-an-email' });
    expect(res.status).toBe(400);
  });
  test('学生 token → 403', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', student).send({ email: 'a@b.com' });
    expect(res.status).toBe(403);
  });
  test('对象存储头像 URL → 200 回写 avatar_url', async () => {
    __mock.setRoutes([
      { match: /UPDATE dtest2\.teacher_profiles SET avatar_url/, result: [{}] }
    ]);
    const url = '/api/uploads/up-12345678-1234-1234-1234-1234567890ab';
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ avatarUrl: url });
    expect(res.status).toBe(200);
    expect(res.body.data.avatarUrl).toBe(url);
  });
  test('非法头像格式 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({ avatarUrl: 'javascript:alert(1)' });
    expect(res.status).toBe(400);
  });
  test('无任何字段 → 400', async () => {
    const res = await request(app).put('/api/teacher/profile').set('Authorization', teacher).send({});
    expect(res.status).toBe(400);
  });
});

describe('POST /api/auth/change-password（任意角色）', () => {
  test('原密码正确 → 200 改密（更新 accounts）', async () => {
    const { hashBcrypt } = require('../src/hash');
    const h = await hashBcrypt('OldPass@1');
    __mock.setRoutes([
      { match: /SELECT password_hash, salt FROM dtest2\.accounts/, result: [{ password_hash: h, salt: '' }] },
      { match: /UPDATE dtest2\.accounts SET password_hash/, result: [] }
    ]);
    const res = await request(app).post('/api/auth/change-password').set('Authorization', teacher).send({ oldPassword: 'OldPass@1', newPassword: 'NewPass@2x' });
    expect(res.status).toBe(200);
    expect(res.body.data.changed).toBe(true);
  });
  test('原密码错误 → 400', async () => {
    const { hashBcrypt } = require('../src/hash');
    const h = await hashBcrypt('OldPass@1');
    __mock.setRoutes([
      { match: /SELECT password_hash, salt FROM dtest2\.accounts/, result: [{ password_hash: h, salt: '' }] }
    ]);
    const res = await request(app).post('/api/auth/change-password').set('Authorization', teacher).send({ oldPassword: 'WRONGpass', newPassword: 'NewPass@2x' });
    expect(res.status).toBe(400);
  });
  test('未登录 → 401', async () => {
    const res = await request(app).post('/api/auth/change-password').send({ oldPassword: 'x', newPassword: 'yyyyyyyy' });
    expect(res.status).toBe(401);
  });
});
