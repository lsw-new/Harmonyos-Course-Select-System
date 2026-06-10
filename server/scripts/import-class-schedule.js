// 导入班级课表：scripts/class-schedule.json → dtest2.class_schedule_items（UPSERT，幂等可重跑）
// 同时派生课程-教师绑定 → dtest2.course_teachers。
// 用法：cd server && node scripts/import-class-schedule.js
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

const JSON_PATH = path.join(__dirname, 'class-schedule.json');

async function main() {
  const raw = fs.readFileSync(JSON_PATH, 'utf8');
  const items = JSON.parse(raw);
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('class-schedule.json 为空或格式不正确');
  }

  const client = await pool.connect();
  let upserted = 0;
  const teachers = new Map();
  try {
    await client.query('BEGIN');
    for (const it of items) {
      const required = ['id', 'className', 'term', 'courseId', 'courseName', 'teacher', 'weekday', 'periodStart', 'periodEnd', 'startTime', 'endTime'];
      for (const k of required) {
        if (it[k] === undefined || it[k] === null || it[k] === '') {
          throw new Error(`课表行缺少字段 ${k}：${JSON.stringify(it)}`);
        }
      }
      await client.query(
        `INSERT INTO dtest2.class_schedule_items
           (item_id, class_name, term, type, course_id, course_name, teacher,
            weekday, period_start, period_end, start_time, end_time,
            classroom, campus, weeks, week_text, course_type)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
         ON CONFLICT (item_id) DO UPDATE SET
           class_name=EXCLUDED.class_name, term=EXCLUDED.term, type=EXCLUDED.type,
           course_id=EXCLUDED.course_id, course_name=EXCLUDED.course_name, teacher=EXCLUDED.teacher,
           weekday=EXCLUDED.weekday, period_start=EXCLUDED.period_start, period_end=EXCLUDED.period_end,
           start_time=EXCLUDED.start_time, end_time=EXCLUDED.end_time,
           classroom=EXCLUDED.classroom, campus=EXCLUDED.campus,
           weeks=EXCLUDED.weeks, week_text=EXCLUDED.week_text, course_type=EXCLUDED.course_type`,
        [
          it.id, it.className, it.term, it.type === 'practice' ? 'practice' : 'normal',
          it.courseId, it.courseName, it.teacher,
          it.weekday, it.periodStart, it.periodEnd, it.startTime, it.endTime,
          it.classroom || '', it.campus || null,
          JSON.stringify(it.weeks || []), it.weekText || '', it.courseType || ''
        ]
      );
      upserted++;
      if (!teachers.has(it.courseId)) {
        teachers.set(it.courseId, { courseName: it.courseName, teacher: it.teacher });
      }
    }
    for (const [courseId, t] of teachers) {
      await client.query(
        `INSERT INTO dtest2.course_teachers (course_id, course_name, teacher)
         VALUES ($1, $2, $3)
         ON CONFLICT (course_id) DO UPDATE
           SET course_name = EXCLUDED.course_name, teacher = EXCLUDED.teacher, updated_at = now()`,
        [courseId, t.courseName, t.teacher]
      );
    }
    await client.query('COMMIT');
    console.log(`done. 课表导入/更新 ${upserted} 条，课程-教师绑定 ${teachers.size} 门。`);
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
