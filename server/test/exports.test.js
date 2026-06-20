// 导出端点：成绩单 PDF（GET /api/grades/transcript）与课表 iCal（GET /api/schedule/ical）。
// 验证状态码、Content-Type、二进制魔数（%PDF）与 iCalendar 结构；无 token → 401。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const studentToken = signToken({ sub: '2023307020941', role: 'student' });

const profileRow = {
  student_id: '2023307020941',
  name: '李仕炜',
  college: '信息工程学院',
  major: '计算机科学与技术',
  class_name: '23计算机科学与技术U9',
  gpa: '3.85',
  earned_credits: 12,
  passed_count: 4
};

const gradeRow = {
  term: '2025-2026-1',
  score: 92,
  grade_point: 4.0,
  code: 'VDZ02119204',
  name: '鸿蒙应用开发初级认证',
  credit: 3
};

const scheduleRow = {
  item_id: 'imp-1',
  class_name: '23计算机科学与技术U9',
  term: '2025-2026-2',
  course_name: '鸿蒙应用开发初级认证',
  teacher: '方坚',
  weekday: 1,
  period_start: 1,
  period_end: 4,
  start_time: '08:00',
  end_time: '11:35',
  classroom: '上茶苑教7栋404',
  campus: '茶苑校区',
  weeks: [2, 3, 4, 5],
  week_text: '2-5 周',
  course_type: '必修'
};

beforeEach(() => __mock.reset());

describe('GET /api/grades/transcript（成绩单 PDF）', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/grades/transcript');
    expect(res.status).toBe(401);
  });

  test('200 + application/pdf + 魔数 %PDF', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.student_profiles sp/, result: [profileRow] },
      { match: /FROM dtest2\.grades g\s+LEFT JOIN dtest2\.courses/, result: [gradeRow] }
    ]);
    const res = await request(app)
      .get('/api/grades/transcript')
      .set('Authorization', `Bearer ${studentToken}`)
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (c) => chunks.push(c));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('application/pdf');
    expect(res.headers['content-disposition']).toContain('transcript-2023307020941.pdf');
    expect(Buffer.isBuffer(res.body)).toBe(true);
    expect(res.body.slice(0, 4).toString()).toBe('%PDF');
  });

  test('无已发布成绩仍能生成 PDF', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.student_profiles sp/, result: [{ ...profileRow, gpa: null, earned_credits: null, passed_count: null }] },
      { match: /FROM dtest2\.grades g\s+LEFT JOIN dtest2\.courses/, result: [] }
    ]);
    const res = await request(app)
      .get('/api/grades/transcript')
      .set('Authorization', `Bearer ${studentToken}`)
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (c) => chunks.push(c));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(res.status).toBe(200);
    expect(res.body.slice(0, 4).toString()).toBe('%PDF');
  });

  test('学生资料不存在 → 404', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.student_profiles sp/, result: [] }
    ]);
    const res = await request(app)
      .get('/api/grades/transcript')
      .set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(404);
  });
});

describe('GET /api/schedule/ical（课表 iCal）', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/schedule/ical');
    expect(res.status).toBe(401);
  });

  test('200 + text/calendar + VCALENDAR/VEVENT', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [{ class_name: '23计算机科学与技术U9' }] },
      { match: /FROM dtest2\.class_schedule_items/, result: [scheduleRow] }
    ]);
    const res = await request(app)
      .get('/api/schedule/ical')
      .set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/calendar');
    expect(res.headers['content-disposition']).toContain('schedule.ics');
    expect(res.text).toContain('BEGIN:VCALENDAR');
    expect(res.text).toContain('END:VCALENDAR');
    expect(res.text).toContain('BEGIN:VEVENT');
    expect(res.text).toContain('RRULE:FREQ=WEEKLY');
    expect(res.text).toContain('鸿蒙应用开发初级认证');
    // CRLF 行尾
    expect(res.text).toContain('\r\n');
  });

  test('名册缺失 → 回退 student_profiles 班级', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [] },
      { match: /FROM dtest2\.student_profiles/, result: [{ class_name: '23计算机科学与技术U9' }] },
      { match: /FROM dtest2\.class_schedule_items/, result: [scheduleRow] }
    ]);
    const res = await request(app)
      .get('/api/schedule/ical')
      .set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(res.text).toContain('BEGIN:VEVENT');
  });

  test('无班级 → 404', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [] },
      { match: /FROM dtest2\.student_profiles/, result: [{ class_name: '待完善' }] }
    ]);
    const res = await request(app)
      .get('/api/schedule/ical')
      .set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(404);
  });
});
