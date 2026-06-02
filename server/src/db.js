// Postgres 连接池（dtest2 schema，表名在查询中显式限定）
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: parseInt(process.env.PGPORT || '15432', 10),
  database: process.env.PGDATABASE || 'dtest2_harmony',
  user: process.env.PGUSER || 'dtest2_app',
  password: process.env.PGPASSWORD || '',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 8000
});

pool.on('error', (e) => console.error('[pg pool error]', e.message));

module.exports = { pool };
