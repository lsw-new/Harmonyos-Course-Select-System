// 班级课表域路由：按当前学生所在班级（class_students 名册，兜底 student_profiles）返回本班课表。
// 课表数据来自 class_schedule_items（含课程-教师绑定），由 scripts/import-class-schedule.js 导入。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');

const router = express.Router();

// 学期第 1 教学周的周一（默认值）。课表行只含 weekday+节次+weeks(周次数组)，
// 无绝对日期，故约定一个学期起始周一，把「第 N 周 + 周几 + 起止时间」映射为真实 datetime。
// 不同学期可经 ?termStart=YYYY-MM-DD 覆盖（需为周一）。
const DEFAULT_TERM_START = '2026-02-23'; // 2025-2026-2 学期第 1 周周一（约定值）

function pad2(n) {
  return n < 10 ? `0${n}` : String(n);
}

// 将 HH:MM 字符串解析为 {h, m}，非法时回退默认。
function parseHm(value, fallbackH, fallbackM) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));
  if (!m) {
    return { h: fallbackH, m: fallbackM };
  }
  return { h: Math.min(23, Number(m[1])), m: Math.min(59, Number(m[2])) };
}

// 本地（无 TZID，floating time）时间戳：YYYYMMDDTHHMMSS。课表时间为校园本地时间。
function icsLocalStamp(date) {
  return (
    `${date.getFullYear()}${pad2(date.getMonth() + 1)}${pad2(date.getDate())}` +
    `T${pad2(date.getHours())}${pad2(date.getMinutes())}${pad2(date.getSeconds())}`
  );
}

// RFC5545 文本转义：反斜杠、分号、逗号、换行。
function icsEscape(text) {
  return String(text === null || text === undefined ? '' : text)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n');
}

// 由「学期起始周一 + 第 firstWeek 周 + weekday(1=周一)」算出该事件首次发生日期（本地 00:00）。
function occurrenceDate(termStartMonday, firstWeek, weekday) {
  const d = new Date(termStartMonday.getTime());
  const dayOffset = (Math.max(1, firstWeek) - 1) * 7 + (Math.max(1, Math.min(7, weekday)) - 1);
  d.setDate(d.getDate() + dayOffset);
  return d;
}

// 把单条课表项构建为一个 weekly RRULE 的 VEVENT（COUNT=出现周数）。
function buildVEvent(item, termStartMonday, nowStamp) {
  const weeks = Array.isArray(item.weeks) && item.weeks.length > 0
    ? item.weeks.map(Number).filter((n) => n > 0).sort((a, b) => a - b)
    : [1];
  const firstWeek = weeks[0];
  const occ = occurrenceDate(termStartMonday, firstWeek, Number(item.weekday) || 1);
  const start = parseHm(item.start_time, 8, 0);
  const end = parseHm(item.end_time, start.h + 1, start.m);
  const startDt = new Date(occ.getFullYear(), occ.getMonth(), occ.getDate(), start.h, start.m, 0);
  const endDt = new Date(occ.getFullYear(), occ.getMonth(), occ.getDate(), end.h, end.m, 0);
  const count = weeks.length;

  const uid = `schedule-${icsEscape(item.item_id)}@dtest2`;
  const summary = icsEscape(item.course_name || '课程');
  const locParts = [item.classroom, item.campus].filter((x) => x);
  const location = icsEscape(locParts.join(' '));
  const descParts = [];
  if (item.teacher) descParts.push(`教师：${item.teacher}`);
  if (item.week_text) descParts.push(`周次：${item.week_text}`);
  if (item.course_type) descParts.push(`类型：${item.course_type}`);
  const description = icsEscape(descParts.join('  '));

  const lines = [
    'BEGIN:VEVENT',
    `UID:${uid}`,
    `DTSTAMP:${nowStamp}`,
    `DTSTART:${icsLocalStamp(startDt)}`,
    `DTEND:${icsLocalStamp(endDt)}`,
    `RRULE:FREQ=WEEKLY;COUNT=${count}`,
    `SUMMARY:${summary}`
  ];
  if (location) lines.push(`LOCATION:${location}`);
  if (description) lines.push(`DESCRIPTION:${description}`);
  lines.push('END:VEVENT');
  return lines;
}

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

// 解析当前学生所在班级（名册优先，回退学生资料）。无班级返回 ''。
async function resolveClassName(studentId) {
  const roster = await pool.query(
    'SELECT class_name FROM dtest2.class_students WHERE student_id=$1',
    [studentId]
  );
  if (roster.rowCount > 0) {
    return roster.rows[0].class_name;
  }
  const profile = await pool.query(
    'SELECT class_name FROM dtest2.student_profiles WHERE student_id=$1',
    [studentId]
  );
  if (profile.rowCount > 0) {
    return profile.rows[0].class_name;
  }
  return '';
}

// ---- 课表导出（iCalendar / .ics）：与 GET /api/schedule 同源班级 + 课表查询 ----
// 数据仅含 weekday+节次+周次数组，无绝对日期：约定学期起始周一（DEFAULT_TERM_START，可经
// ?termStart=YYYY-MM-DD 覆盖），把每条课表项映射为 weekly RRULE（COUNT=上课周数）的 VEVENT。
// 时间为校园本地时间（floating，不带 TZID）。
router.get('/api/schedule/ical', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const className = await resolveClassName(studentId);
    if (!className || className === '待完善') {
      return res.status(404).json(fail('未找到所在班级，暂无班级课表'));
    }
    const r = await pool.query(
      `SELECT item_id, class_name, term, course_name, teacher,
              weekday, period_start, period_end, start_time, end_time,
              classroom, campus, weeks, week_text, course_type
       FROM dtest2.class_schedule_items
       WHERE class_name = $1
       ORDER BY weekday, period_start, item_id`,
      [className]
    );

    // 学期起始周一：默认 DEFAULT_TERM_START，?termStart= 覆盖（仅接受 YYYY-MM-DD）。
    const override = typeof req.query.termStart === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.termStart)
      ? req.query.termStart
      : DEFAULT_TERM_START;
    const [ty, tm, td] = override.split('-').map(Number);
    const termStartMonday = new Date(ty, tm - 1, td, 0, 0, 0);
    const nowStamp = icsLocalStamp(new Date());

    const lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//dtest2//schedule//CN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      `X-WR-CALNAME:${icsEscape(`${className} 课表`)}`
    ];
    for (const row of r.rows) {
      const ev = buildVEvent(row, termStartMonday, nowStamp);
      for (const l of ev) {
        lines.push(l);
      }
    }
    lines.push('END:VCALENDAR');

    const body = lines.join('\r\n') + '\r\n';
    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="schedule.ics"');
    res.send(body);
  } catch (e) {
    serverError(res, '导出课表失败', e);
  }
});

module.exports = router;
