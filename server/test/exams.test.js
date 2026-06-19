// 考试安排域：学生按「本班课表∪已选课程」查考试 / 管理端 CRUD（细粒度权限）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const EXAM_ROW = {
  match: /FROM dtest2\.exams e/,
  result: [{
    exam_id: 'ex-1', course_id: 'c1', term: '2025-2026-2',
    exam_date: '2026-07-06', start_time: '09:00', end_time: '11:00',
    location: 'A101', seat_no: '12', exam_type: 'final',
    course_name: '高等数学', course_code: 'MATH101'
  }]
};

beforeEach(() => __mock.reset());

describe('GET /api/exams（学生）', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/exams');
    expect(res.status).toBe(401);
  });

  test('学生查询 → 200 且 camelCase 字段', async () => {
    __mock.setRoutes([EXAM_ROW]);
    const res = await request(app).get('/api/exams?term=2025-2026-2').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    const e = res.body.data[0];
    expect(e.examId).toBe('ex-1');
    expect(e.courseId).toBe('c1');
    expect(e.courseName).toBe('高等数学');
    expect(e.courseCode).toBe('MATH101');
    expect(e.examType).toBe('final');
  });
});

describe('GET /api/admin/exams（管理端列表）', () => {
  test('无权限 → 403', async () => {
    const res = await request(app).get('/api/admin/exams').set('Authorization', adm);
    expect(res.status).toBe(403);
  });

  test('有权限 → 200', async () => {
    __mock.setRoutes([PERM_GRANT, EXAM_ROW]);
    const res = await request(app).get('/api/admin/exams').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].examId).toBe('ex-1');
  });
});

describe('POST /api/admin/exams（新增）', () => {
  test('courseId 缺失 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/exams').set('Authorization', adm)
      .send({ term: '2025-2026-2' });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('courseId');
  });

  test('课程不存在 → 400', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /SELECT 1 FROM dtest2\.courses/, result: [] }]);
    const res = await request(app).post('/api/admin/exams').set('Authorization', adm)
      .send({ courseId: 'nope', term: '2025-2026-2' });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('课程不存在');
  });

  test('合法入参 → 200 并回显新建行', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /SELECT 1 FROM dtest2\.courses/, result: [{ ok: 1 }] },
      { match: /INSERT INTO dtest2\.exams/, result: [] },
      EXAM_ROW
    ]);
    const res = await request(app).post('/api/admin/exams').set('Authorization', adm)
      .send({ courseId: 'c1', term: '2025-2026-2', examDate: '2026-07-06', startTime: '09:00', endTime: '11:00', location: 'A101' });
    expect(res.status).toBe(200);
    expect(res.body.data.examId).toBe('ex-1');
    expect(__mock.executed('INSERT INTO dtest2.exams')).toBe(true);
  });
});

describe('PUT /api/admin/exams/:id（编辑）', () => {
  test('不存在 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /UPDATE dtest2\.exams/, result: [] }]);
    const res = await request(app).put('/api/admin/exams/ex-x').set('Authorization', adm)
      .send({ courseId: 'c1', term: '2025-2026-2' });
    expect(res.status).toBe(404);
  });
});

describe('DELETE /api/admin/exams/:id（删除）', () => {
  test('不存在 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /DELETE FROM dtest2\.exams/, result: [] }]);
    const res = await request(app).delete('/api/admin/exams/ex-x').set('Authorization', adm);
    expect(res.status).toBe(404);
  });

  test('存在 → 200', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /DELETE FROM dtest2\.exams/, result: [{ exam_id: 'ex-1' }] }]);
    const res = await request(app).delete('/api/admin/exams/ex-1').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.deleted).toBe(true);
  });
});
