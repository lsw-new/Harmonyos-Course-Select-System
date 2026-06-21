// 幂等种子：从 course_teachers（优先）/ courses 读出所有教师名，
// 按姓名排序分配稳定 ID（T001, T002...），在 accounts + teacher_profiles 各自 ON CONFLICT DO NOTHING。
// 用法：cd server && node scripts/seed-teacher-accounts.js
require('dotenv').config();
const { pool } = require('../src/db');
const { hashBcrypt } = require('../src/hash');

const DEFAULT_PASSWORD = 'Teacher@2024';

async function main() {
  // 优先取 course_teachers，再补 courses.teacher，合并去重
  const r1 = await pool.query(
    `SELECT DISTINCT teacher AS name FROM dtest2.course_teachers WHERE teacher IS NOT NULL AND teacher <> '' ORDER BY teacher`
  );
  const r2 = await pool.query(
    `SELECT DISTINCT teacher AS name FROM dtest2.courses WHERE teacher IS NOT NULL AND teacher <> '' ORDER BY teacher`
  );

  const nameSet = new Set();
  for (const row of r1.rows) { nameSet.add(row.name.trim()); }
  for (const row of r2.rows) { nameSet.add(row.name.trim()); }

  const names = Array.from(nameSet).sort();
  if (names.length === 0) {
    console.log('未找到任何教师姓名（course_teachers / courses 均无数据），退出。');
    await pool.end();
    return;
  }

  const passwordHash = await hashBcrypt(DEFAULT_PASSWORD);

  const client = await pool.connect();
  const results = [];
  try {
    await client.query('BEGIN');
    for (let i = 0; i < names.length; i++) {
      const teacherId = `T${String(i + 1).padStart(3, '0')}`;
      const name = names[i];

      // accounts：role='teacher'，salt 置空（bcrypt 自带盐）
      await client.query(
        `INSERT INTO dtest2.accounts (account_id, role, password_hash, salt, status)
         VALUES ($1, 'teacher', $2, '', 'active')
         ON CONFLICT (account_id) DO NOTHING`,
        [teacherId, passwordHash]
      );

      // teacher_profiles
      await client.query(
        `INSERT INTO dtest2.teacher_profiles (teacher_id, name, college, title, email)
         VALUES ($1, $2, '', '', '')
         ON CONFLICT (teacher_id) DO NOTHING`,
        [teacherId, name]
      );

      results.push({ teacherId, name });
    }
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
    await pool.end();
  }

  console.log('\n教师账号种子完成。默认密码：' + DEFAULT_PASSWORD);
  console.log('\nteacherId → 姓名：');
  for (const { teacherId, name } of results) {
    console.log(`  ${teacherId}  ${name}`);
  }
  console.log(`\n共 ${results.length} 位教师。`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
