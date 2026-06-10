// 班级课表域路由：按当前学生所在班级（class_students 名册，兜底 student_profiles）返回本班课表。
// 课表数据来自 class_schedule_items（含课程-教师绑定），由 scripts/import-class-schedule.js 导入。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');

const router = express.Router();

// ---- 班级课表（当前学生所在班级）----
router.get('/api/schedule', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    // 班级优先取名册（注册白名单的权威来源），名册没有时回退学生资料
    let className = '';
    const roster = await pool.query(
      'SELECT class_name FROM dtest2.class_students WHERE student_id=$1',
      [studentId]
    );
    if (roster.rowCount > 0) {
      className = roster.rows[0].class_name;
    } else {
      const profile = await pool.query(
        'SELECT class_name FROM dtest2.student_profiles WHERE student_id=$1',
        [studentId]
      );
      if (profile.rowCount > 0) {
        className = profile.rows[0].class_name;
      }
    }
    if (!className || className === '待完善') {
      return res.status(404).json(fail('未找到所在班级，暂无班级课表'));
    }
    const r = await pool.query(
      `SELECT item_id, class_name, term, type, course_id, course_name, teacher,
              weekday, period_start, period_end, start_time, end_time,
              classroom, campus, weeks, week_text, course_type
       FROM dtest2.class_schedule_items
       WHERE class_name = $1
       ORDER BY weekday, period_start, item_id`,
      [className]
    );
    const items = r.rows.map((row) => {
      return {
        id: row.item_id,
        term: row.term,
        type: row.type,
        courseId: row.course_id,
        courseName: row.course_name,
        teacher: row.teacher,
        weekday: Number(row.weekday),
        periodStart: Number(row.period_start),
        periodEnd: Number(row.period_end),
        startTime: row.start_time,
        endTime: row.end_time,
        classroom: row.classroom,
        campus: row.campus || undefined,
        weeks: Array.isArray(row.weeks) ? row.weeks.map(Number) : [],
        weekText: row.week_text,
        courseType: row.course_type
      };
    });
    res.json(ok({ className: className, items: items }));
  } catch (e) {
    serverError(res, '查询班级课表失败', e);
  }
});

module.exports = router;
