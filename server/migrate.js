// 数据库迁移 runner（P1-08）
// 按 migrations/NNN_*.sql 文件名顺序应用未记录于 dtest2.schema_migrations 的迁移；
// 每个迁移在单独事务内执行并记录版本，幂等可重复运行（已应用的版本会跳过）。
// 用法：cd server && node migrate.js   （读取 .env 的 PG* 连接配置）
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./src/db');

const MIG_DIR = path.join(__dirname, 'migrations');

// 确保迁移登记表存在（与既有 schema_migrations 约定一致：version/name/applied_at）。
async function ensureMigrationsTable(client) {
  await client.query('CREATE SCHEMA IF NOT EXISTS dtest2');
  await client.query(
    `CREATE TABLE IF NOT EXISTS dtest2.schema_migrations (
       version integer PRIMARY KEY,
       name text NOT NULL,
       applied_at timestamptz NOT NULL DEFAULT now()
     )`
  );
}

// 文件名形如 001_initial_dtest2_schema.sql → { version:1, name:'initial_dtest2_schema' }
function parseMigration(file) {
  const m = /^(\d+)_(.+)\.sql$/.exec(file);
  if (!m) {
    return null;
  }
  return { version: parseInt(m[1], 10), name: m[2], file };
}

async function main() {
  if (!fs.existsSync(MIG_DIR)) {
    console.error('未找到 migrations 目录：' + MIG_DIR);
    process.exit(1);
  }
  const migrations = fs
    .readdirSync(MIG_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort()
    .map(parseMigration)
    .filter((m) => m !== null);

  const client = await pool.connect();
  let applied = 0;
  try {
    await ensureMigrationsTable(client);
    const doneRows = await client.query('SELECT version FROM dtest2.schema_migrations');
    const done = new Set(doneRows.rows.map((r) => Number(r.version)));

    for (const mig of migrations) {
      if (done.has(mig.version)) {
        console.log(`skip   ${mig.version} ${mig.name}（已应用）`);
        continue;
      }
      const sql = fs.readFileSync(path.join(MIG_DIR, mig.file), 'utf8');
      console.log(`apply  ${mig.version} ${mig.name} ...`);
      await client.query('BEGIN');
      try {
        await client.query(sql);
        // 迁移文件自身可能已写入登记行；用 NOT EXISTS 兜底，避免重复或缺失。
        await client.query(
          `INSERT INTO dtest2.schema_migrations (version, name)
           SELECT $1, $2 WHERE NOT EXISTS (SELECT 1 FROM dtest2.schema_migrations WHERE version = $1)`,
          [mig.version, mig.name]
        );
        await client.query('COMMIT');
        applied++;
      } catch (e) {
        await client.query('ROLLBACK');
        throw new Error(`迁移 ${mig.version} ${mig.name} 失败：${e.message}`);
      }
    }
    console.log(`done. 新应用 ${applied} 个迁移，共 ${migrations.length} 个。`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
