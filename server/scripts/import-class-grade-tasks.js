// 按班级课程初始化成绩任务（幂等可重跑）：
// 1) 删除旧测试成绩任务（gt-cs101/gt-se201 等非班级课程任务）及测试课程上的演示成绩行
// 2) 为班级课表的每门课程建 grade_tasks（task_id=gt-<courseId>，教学班=班级名，教师=课表绑定教师）
//    已存在的任务不重置状态（ON CONFLICT 仅更新教师/班级名，保留打分进度）
// 用法：cd server && node scripts/import-class-grade-tasks.js
require('dotenv').config();
const { pool } = require('../src/db');

const TERM = '2025-2026-2';

async function main() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 班级课程清单（课程-教师绑定来自班级课表）
    const courses = await client.query(
      `SELECT DISTINCT ON (course_id) course_id, course_name, teacher, class_name
       FROM dtest2.class_schedule_items
       ORDER BY course_id, weekday, period_start`
    );
    const classCourseIds = courses.rows.map((c) => c.course_id);

    // 旧测试数据清理：非班级课程的成绩任务与成绩行（course-cs101/course-se201 等演示数据）
    const delGrades = await client.query(
      `DELETE FROM dtest2.grades WHERE NOT (course_id = ANY($1::text[]))`,
      [classCourseIds]
    );
    const delTasks = await client.query(
      `DELETE FROM dtest2.grade_tasks WHERE NOT (course_id = ANY($1::text[]))`,
      [classCourseIds]
    );

    let created = 0;
    for (const c of courses.rows) {
      const r = await client.query(
        `INSERT INTO dtest2.grade_tasks (task_id, course_id, term, teaching_class_name, teacher_name, input_progress, status)
         VALUES ($1, $2, $3, $4, $5, 0, 'inputting')
         ON CONFLICT (task_id) DO UPDATE
           SET teaching_class_name=EXCLUDED.teaching_class_name, teacher_name=EXCLUDED.teacher_name, updated_at=now()`,
        [`gt-${c.course_id}`, c.course_id, TERM, c.class_name, c.teacher]
      );
      created += r.rowCount;
    }

    await client.query('COMMIT');
    console.log(`done. 清理测试成绩任务 ${delTasks.rowCount} 条/测试成绩 ${delGrades.rowCount} 行，班级课程成绩任务就绪 ${created}/${courses.rowCount} 门。`);
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
