// 导入班级学生名册：scripts/class-students.json → dtest2.class_students（UPSERT，幂等可重跑）
// 用法：cd server && node scripts/import-class-students.js
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

const JSON_PATH = path.join(__dirname, 'class-students.json');

async function main() {
  const raw = fs.readFileSync(JSON_PATH, 'utf8');
  const students = JSON.parse(raw);
  if (!Array.isArray(students) || students.length === 0) {
    throw new Error('class-students.json 为空或格式不正确');
  }

  const client = await pool.connect();
  let upserted = 0;
  try {
    await client.query('BEGIN');
    for (const s of students) {
      const studentId = String(s.studentId || '').trim();
      const name = String(s.name || '').trim();
      const className = String(s.className || '').trim();
      const gender = String(s.gender || '').trim() || null;
      if (!studentId || !name || !className) {
        throw new Error(`名册行缺少必填字段：${JSON.stringify(s)}`);
      }
      await client.query(
        `INSERT INTO dtest2.class_students (student_id, name, class_name, gender)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (student_id) DO UPDATE
           SET name = EXCLUDED.name, class_name = EXCLUDED.class_name, gender = EXCLUDED.gender`,
        [studentId, name, className, gender]
      );
      upserted++;
    }
    await client.query('COMMIT');
    console.log(`done. 名册导入/更新 ${upserted} 条。`);
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
