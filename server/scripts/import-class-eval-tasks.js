// 按班级生成评教任务（真实课程/教师，幂等可重跑）：
// 1) 班级课表的课程（含教师绑定）UPSERT 进选课目录 dtest2.courses（status=closed，不进选课中心，仅满足外键与展示）
// 2) 清空旧测试评教任务/答卷
// 3) 为「已注册（有 student_profiles）且在名册（class_students）」的学生 × 本班课程生成 evaluation_tasks
//    （未注册学生由注册流程在建号事务内自动生成，见 auth.routes.js）
// 用法：cd server && node scripts/import-class-eval-tasks.js
require('dotenv').config();
const { pool } = require('../src/db');

const TERM = '2025-2026-2';
const TEMPLATE_ID = 'qt-default'; // 教学质量评价问卷（seed 已建）
const CLOSE_AT = '2026-07-15 23:59:59+08';

function mapCategory(courseType) {
  if (courseType === '公选') {
    return 'public';
  }
  if (courseType === '选修') {
    return 'elective';
  }
  return 'required';
}

async function main() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1) 班级课表课程 → 选课目录（每门课取一条代表性排课行补充教室/校区等辅助信息）
    const courses = await client.query(
      `SELECT DISTINCT ON (course_id) course_id, course_name, teacher, course_type,
              campus, classroom, weekday, period_start, period_end, week_text
       FROM dtest2.class_schedule_items
       ORDER BY course_id, weekday, period_start`
    );
    for (const c of courses.rows) {
      await client.query(
        `INSERT INTO dtest2.courses
           (course_id, code, name, category, credit, teacher, campus, classroom,
            weeks_text, weekday, period_start, period_end, capacity, status)
         VALUES ($1, $1, $2, $3, 2.0, $4, $5, $6, $7, $8, $9, $10, 50, 'closed')
         ON CONFLICT (course_id) DO UPDATE SET
           name=EXCLUDED.name, category=EXCLUDED.category, teacher=EXCLUDED.teacher,
           campus=EXCLUDED.campus, classroom=EXCLUDED.classroom, weeks_text=EXCLUDED.weeks_text,
           weekday=EXCLUDED.weekday, period_start=EXCLUDED.period_start, period_end=EXCLUDED.period_end,
           updated_at=now()`,
        [c.course_id, c.course_name, mapCategory(c.course_type), c.teacher,
          c.campus, c.classroom, c.week_text, c.weekday, c.period_start, c.period_end]
      );
    }

    // 2) 旧评教数据全为测试数据（测试教师），整体清空后按真实课表重建
    const delSub = await client.query('DELETE FROM dtest2.evaluation_submissions');
    const delTask = await client.query('DELETE FROM dtest2.evaluation_tasks');

    // 3) 已注册名册学生 × 本班课程 → 评教任务（DISTINCT 防同课多排课行重复）
    const gen = await client.query(
      `INSERT INTO dtest2.evaluation_tasks
         (task_id, template_id, student_id, course_id, term, teacher_name, status, open_time, close_time)
       SELECT DISTINCT 'eval-' || csi.course_id || '-' || cs.student_id,
              $1, cs.student_id, csi.course_id, $2, csi.teacher, 'open',
              now() - interval '1 day', $3::timestamptz
       FROM dtest2.class_students cs
       JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
       JOIN dtest2.class_schedule_items csi ON csi.class_name = cs.class_name
       JOIN dtest2.courses c ON c.course_id = csi.course_id
       ON CONFLICT (task_id) DO NOTHING`,
      [TEMPLATE_ID, TERM, CLOSE_AT]
    );

    await client.query('COMMIT');
    console.log(`done. 课程目录 UPSERT ${courses.rowCount} 门（含教师绑定），清理旧任务 ${delTask.rowCount}/答卷 ${delSub.rowCount}，为已注册学生生成评教任务 ${gen.rowCount} 条。`);
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
