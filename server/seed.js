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
  await pool.end();
  console.log('seed done');
}

main().catch((e) => {
  console.error('seed failed:', e.message);
  process.exit(1);
});
