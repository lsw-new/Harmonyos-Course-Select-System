// 纯函数单测：选课周次解析 + 时间冲突判定（审查问题3 的核心逻辑，与前端 CourseRepository 同源）。
// 这两个函数从 index.js 导出，无需数据库；mock ./db 仅为避免 require 时建立真实连接池。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const app = require('../src/index');
const { parseCourseWeeks, coursesConflict } = app;

describe('parseCourseWeeks 周次文本解析', () => {
  test('解析连续区间 "1-16 周"', () => {
    expect(parseCourseWeeks('1-16 周')).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  });
  test('解析离散 "1,3,5 周"', () => {
    expect(parseCourseWeeks('1,3,5 周')).toEqual([1, 3, 5]);
  });
  test('解析混合 "1-8,10-16"', () => {
    expect(parseCourseWeeks('1-8,10-16')).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16]);
  });
  test('空/无效输入返回空数组', () => {
    expect(parseCourseWeeks('')).toEqual([]);
    expect(parseCourseWeeks(null)).toEqual([]);
    expect(parseCourseWeeks(undefined)).toEqual([]);
    expect(parseCourseWeeks('全周')).toEqual([]);
  });
  test('去重', () => {
    expect(parseCourseWeeks('1-3,2-4')).toEqual([1, 2, 3, 4]);
  });
});

describe('coursesConflict 时间冲突判定', () => {
  const mk = (weekday, ps, pe, weeks) => ({ weekday, period_start: ps, period_end: pe, weeks_text: weeks });

  test('同星期+节次重叠+周次相交 → 冲突', () => {
    expect(coursesConflict(mk(1, 1, 2, '1-16'), mk(1, 2, 3, '1-16'))).toBe(true);
  });
  test('不同星期 → 不冲突', () => {
    expect(coursesConflict(mk(1, 1, 2, '1-16'), mk(2, 1, 2, '1-16'))).toBe(false);
  });
  test('同星期但节次不重叠 → 不冲突', () => {
    expect(coursesConflict(mk(1, 1, 2, '1-16'), mk(1, 3, 4, '1-16'))).toBe(false);
  });
  test('同星期+节次重叠但周次不相交（前后半学期）→ 不冲突', () => {
    expect(coursesConflict(mk(1, 1, 2, '1-8'), mk(1, 1, 2, '9-16'))).toBe(false);
  });
  test('未排课（weekday 缺失，如集中实践）→ 不冲突', () => {
    expect(coursesConflict(mk(0, 1, 2, '1-16'), mk(1, 1, 2, '1-16'))).toBe(false);
    expect(coursesConflict(mk(null, null, null, ''), mk(1, 1, 2, '1-16'))).toBe(false);
  });
  test('边界相接（a 末节=b 首节）→ 冲突', () => {
    expect(coursesConflict(mk(3, 1, 2, '1-16'), mk(3, 2, 3, '8'))).toBe(true);
  });
});
