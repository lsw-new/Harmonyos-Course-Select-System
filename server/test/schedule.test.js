// 班级课表端点：按名册班级返回本班课表（含课程-教师绑定字段），名册缺失回退学生资料，无班级 404。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const studentToken = signToken({ sub: '2023307020941', role: 'student' });

const scheduleRow = {
  item_id: 'imp-1',
  class_name: '23计算机科学与技术U9',
  term: '2025-2026-2',
  type: 'normal',
  course_id: 'VDZ02119204',
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

describe('GET /api/schedule', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/schedule');
    expect(res.status).toBe(401);
  });

  test('名册命中 → 200 返回本班课表（含教师绑定）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [{ class_name: '23计算机科学与技术U9' }] },
      { match: /FROM dtest2\.class_schedule_items/, result: [scheduleRow] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.className).toBe('23计算机科学与技术U9');
    expect(res.body.data.items).toHaveLength(1);
    const item = res.body.data.items[0];
    expect(item.courseName).toBe('鸿蒙应用开发初级认证');
    expect(item.teacher).toBe('方坚');
    expect(item.weekday).toBe(1);
    expect(item.weeks).toEqual([2, 3, 4, 5]);
  });

  test('名册缺失 → 回退 student_profiles 班级', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [] },
      { match: /FROM dtest2\.student_profiles/, result: [{ class_name: '23计算机科学与技术U9' }] },
      { match: /FROM dtest2\.class_schedule_items/, result: [scheduleRow] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.items).toHaveLength(1);
  });

  test('无班级（资料为「待完善」）→ 404', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [] },
      { match: /FROM dtest2\.student_profiles/, result: [{ class_name: '待完善' }] }
    ]);
    const res = await request(app).get('/api/schedule').set('Authorization', `Bearer ${studentToken}`);
    expect(res.status).toBe(404);
    expect(res.body.error).toContain('班级');
  });
});
