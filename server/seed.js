// 种子脚本：把 2 个测试账号的密码重置为 App 端约定密码（用本后端哈希方案），
// 并把演示选课轮次置为 running，便于联调验证选/退课。幂等。
require('dotenv').config();
const { pool } = require('./src/db');
const { genSalt, hashPassword } = require('./src/hash');

async function setPassword(accountId, password) {
  const salt = genSalt();
  const hash = hashPassword(password, salt);
  const r = await pool.query(
    `UPDATE dtest2.accounts
       SET password_hash=$2, salt=$3, status='active', failed_login_count=0, locked_until=NULL, updated_at=now()
     WHERE account_id=$1`,
    [accountId, hash, salt]
  );
  console.log(`account ${accountId}: ${r.rowCount} row(s) updated`);
}

async function main() {
  await setPassword('2023307020941', 'Elysia@2024');
  await setPassword('A20251001', 'Admin@2024');
  const r = await pool.query(
    `UPDATE dtest2.selection_rounds
       SET status='running', start_time=now() - interval '1 hour', end_time=now() + interval '30 days', updated_at=now()
     WHERE round_id='round-2026-main'`
  );
  console.log(`round round-2026-main -> running: ${r.rowCount} row(s)`);
  // 演示成绩（先清后插，幂等）：测试学生在 cs101/se201 的已发布成绩
  await pool.query(`DELETE FROM dtest2.grades WHERE student_id='2023307020941'`);
  await pool.query(
    `INSERT INTO dtest2.grades (grade_id, student_id, course_id, term, score, grade_point, published_at) VALUES
       ('grade-cs101-2025','2023307020941','course-cs101','2025-2026-1',92,4.0,now()),
       ('grade-se201-2025','2023307020941','course-se201','2025-2026-1',85,3.5,now())`
  );
  console.log('demo grades seeded: 2');
  // 演示评教任务（幂等，CASCADE 清提交）：cs101 开放评教
  await pool.query(`DELETE FROM dtest2.evaluation_tasks WHERE student_id='2023307020941'`);
  await pool.query(
    `INSERT INTO dtest2.evaluation_tasks (task_id, student_id, course_id, term, teacher_name, status, open_time, close_time)
     VALUES ('eval-cs101-2025','2023307020941','course-cs101','2025-2026-1','王鑫','open', now() - interval '1 day', now() + interval '30 days')`
  );
  console.log('demo eval task seeded: 1');
  // 演示实践项目（幂等，CASCADE 清报名）
  await pool.query(`DELETE FROM dtest2.practice_projects WHERE project_id IN ('prac-001','prac-002')`);
  await pool.query(
    `INSERT INTO dtest2.practice_projects (project_id, title, org, category, credits, period, location, mentor, slots_total, description, requirements_json) VALUES
       ('prac-001','景德镇陶瓷文化数字化志愿服务','景德镇艺术职业大学','volunteer',2.0,'2026 暑期','景德镇','李导师',20,'参与陶瓷文物数字化采集与线上展示。', '["细心负责","了解摄影优先"]'::jsonb),
       ('prac-002','鸿蒙应用开发企业实习','华为技术有限公司','internship',4.0,'2026 春季','南昌','王工',10,'参与 HarmonyOS 应用开发实战项目。', '["熟悉 ArkTS","有项目经验优先"]'::jsonb)`
  );
  console.log('demo practice projects seeded: 2');
  // 演示成绩审核任务（幂等）：一条待审、一条录入中
  await pool.query(`DELETE FROM dtest2.grade_tasks WHERE task_id IN ('gt-cs101','gt-se201')`);
  await pool.query(
    `INSERT INTO dtest2.grade_tasks (task_id, course_id, term, teaching_class_name, teacher_name, input_progress, status) VALUES
       ('gt-cs101','course-cs101','2025-2026-1','CS101-01','王鑫',100,'pendingAudit'),
       ('gt-se201','course-se201','2025-2026-1','SE201-01','黄卫东',60,'inputting')`
  );
  console.log('demo grade tasks seeded: 2');
  // 演示评教问卷模板（幂等）
  await pool.query(`DELETE FROM dtest2.evaluation_templates WHERE template_id IN ('qt-default','qt-lab')`);
  await pool.query(
    `INSERT INTO dtest2.evaluation_templates (template_id, name, description, question_count, status) VALUES
       ('qt-default','教学质量评价问卷','面向理论课的标准评教问卷',10,'enabled'),
       ('qt-lab','实验课评价问卷','面向实验与实践课的评教问卷',8,'disabled')`
  );
  console.log('demo eval templates seeded: 2');
  // 演示操作日志（幂等）
  await pool.query(`DELETE FROM dtest2.audit_logs WHERE log_id IN ('log-seed-1','log-seed-2')`);
  await pool.query(
    `INSERT INTO dtest2.audit_logs (log_id, operator_id, operator_name, action, action_type, target, result, ip, created_at) VALUES
       ('log-seed-1','A20251001','爱莉希雅','管理员登录','login','系统','success','127.0.0.1', now() - interval '2 hour'),
       ('log-seed-2','A20251001','爱莉希雅','发布通知','notice','通知中心','success','127.0.0.1', now() - interval '1 hour')`
  );
  console.log('demo audit logs seeded: 2');
  await pool.end();
  console.log('seed done');
}

main().catch((e) => {
  console.error('seed failed:', e.message);
  process.exit(1);
});
