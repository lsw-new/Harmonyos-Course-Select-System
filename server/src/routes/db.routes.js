// 数据库管理域路由：dtest2 schema 表级增删改查（Web 管理控制台「数据库管理」用）。
// 安全：仅 system.config 权限；表名/列名一律经 information_schema 白名单校验后再拼接
//（标识符双引号转义），值全部参数化绑定，杜绝 SQL 注入；更新/删除必须按主键定位。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');

const router = express.Router();
const GUARD = permissionRequired('system.config:update', 'system.config:view');

const IDENT_RE = /^[a-z_][a-z0-9_]*$/;

function qid(name) {
  return '"' + String(name).replace(/"/g, '""') + '"';
}

async function assertTable(table) {
  if (!IDENT_RE.test(table)) {
    return false;
  }
  const r = await pool.query(
    `SELECT 1 FROM information_schema.tables
     WHERE table_schema='dtest2' AND table_name=$1 AND table_type='BASE TABLE'`,
    [table]
  );
  return r.rowCount > 0;
}

async function tableColumns(table) {
  const r = await pool.query(
    `SELECT column_name, data_type, is_nullable, column_default
     FROM information_schema.columns
     WHERE table_schema='dtest2' AND table_name=$1
     ORDER BY ordinal_position`,
    [table]
  );
  return r.rows;
}

async function tablePk(table) {
  const r = await pool.query(
    `SELECT a.attname AS column_name
     FROM pg_index i
     JOIN pg_class c ON c.oid = i.indrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
     WHERE i.indisprimary AND n.nspname='dtest2' AND c.relname=$1`,
    [table]
  );
  return r.rows.map((x) => x.column_name);
}

// json/jsonb 列的入参为 JSON 文本，绑定时显式 cast；其余类型 pg 按列类型自动转换
function castOf(dataType) {
  return (dataType === 'json' || dataType === 'jsonb') ? '::jsonb' : '';
}

// 从请求体挑出「真实存在的列」键值对（顺带丢弃任何非法键）
function pickColumns(body, cols) {
  const byName = new Map(cols.map((c) => [c.column_name, c]));
  const out = [];
  for (const key of Object.keys(body || {})) {
    const col = byName.get(key);
    if (col) {
      out.push({ col, value: body[key] });
    }
  }
  return out;
}

// ---- 表清单（含行数）----
router.get('/api/admin/db/tables', GUARD, async (req, res) => {
  try {
    const tables = await pool.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema='dtest2' AND table_type='BASE TABLE' ORDER BY table_name`
    );
    // 各表行数互不依赖：并行 COUNT（约 36 张表，串行等于 36 次往返）
    const out = await Promise.all(tables.rows.map(async (t) => {
      const cnt = await pool.query(`SELECT count(*) AS n FROM dtest2.${qid(t.table_name)}`);
      return { name: t.table_name, rows: Number(cnt.rows[0].n) };
    }));
    res.json(ok(out));
  } catch (e) {
    serverError(res, '查询表清单失败', e);
  }
});

// ---- 行查询（按主键排序分页；q 对全部文本列 ILIKE）----
router.get('/api/admin/db/tables/:table/rows', GUARD, async (req, res) => {
  const table = String(req.params.table || '');
  try {
    if (!(await assertTable(table))) {
      return res.status(404).json(fail('表不存在'));
    }
    const cols = await tableColumns(table);
    const pk = await tablePk(table);
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit || '50', 10) || 50));
    const offset = Math.max(0, parseInt(req.query.offset || '0', 10) || 0);
    const q = req.query.q ? String(req.query.q) : '';
    let where = '';
    const params = [];
    if (q) {
      const textCols = cols
        .filter((c) => c.data_type === 'text' || c.data_type === 'character varying')
        .map((c) => qid(c.column_name));
      if (textCols.length > 0) {
        params.push('%' + q + '%');
        where = ' WHERE ' + textCols.map((c) => `${c}::text ILIKE $1`).join(' OR ');
      }
    }
    const total = await pool.query(`SELECT count(*) AS n FROM dtest2.${qid(table)}${where}`, params);
    const orderBy = pk.length > 0 ? ' ORDER BY ' + pk.map(qid).join(', ') : '';
    const rows = await pool.query(
      `SELECT * FROM dtest2.${qid(table)}${where}${orderBy} LIMIT ${limit} OFFSET ${offset}`,
      params
    );
    res.json(ok({
      columns: cols.map((c) => ({
        name: c.column_name,
        type: c.data_type,
        nullable: c.is_nullable === 'YES',
        hasDefault: c.column_default !== null,
        pk: pk.indexOf(c.column_name) >= 0
      })),
      pk,
      total: Number(total.rows[0].n),
      limit,
      offset,
      rows: rows.rows
    }));
  } catch (e) {
    serverError(res, '查询数据失败', e);
  }
});

// ---- 新增行（body.values：列→值；未提供的列走默认值/NULL）----
router.post('/api/admin/db/tables/:table/rows', GUARD, async (req, res) => {
  const table = String(req.params.table || '');
  try {
    if (!(await assertTable(table))) {
      return res.status(404).json(fail('表不存在'));
    }
    const cols = await tableColumns(table);
    const entries = pickColumns((req.body || {}).values, cols);
    if (entries.length === 0) {
      return res.status(400).json(fail('请至少提供一个有效列的值'));
    }
    const names = entries.map((e) => qid(e.col.column_name)).join(', ');
    const placeholders = entries.map((e, i) => `$${i + 1}${castOf(e.col.data_type)}`).join(', ');
    const values = entries.map((e) => e.value);
    const r = await pool.query(
      `INSERT INTO dtest2.${qid(table)} (${names}) VALUES (${placeholders}) RETURNING *`,
      values
    );
    res.json(ok({ inserted: true, row: r.rows[0] }));
  } catch (e) {
    if (e && e.code) {
      // pg 约束类错误回精确原因（23xxx=完整性约束、22xxx=数据格式），便于在页面直接纠正
      return res.status(400).json(fail(`写入失败：${e.message}`));
    }
    serverError(res, '新增数据失败', e);
  }
});

// ---- 更新行（body.pk：主键定位；body.values：要更新的列→值）----
router.put('/api/admin/db/tables/:table/rows', GUARD, async (req, res) => {
  const table = String(req.params.table || '');
  try {
    if (!(await assertTable(table))) {
      return res.status(404).json(fail('表不存在'));
    }
    const cols = await tableColumns(table);
    const pk = await tablePk(table);
    if (pk.length === 0) {
      return res.status(409).json(fail('该表无主键，不支持按行更新'));
    }
    const body = req.body || {};
    const pkBody = body.pk || {};
    for (const k of pk) {
      if (pkBody[k] === undefined || pkBody[k] === null) {
        return res.status(400).json(fail(`缺少主键 ${k}`));
      }
    }
    const entries = pickColumns(body.values, cols).filter((e) => pk.indexOf(e.col.column_name) < 0);
    if (entries.length === 0) {
      return res.status(400).json(fail('请至少提供一个要更新的非主键列'));
    }
    const sets = entries.map((e, i) => `${qid(e.col.column_name)} = $${i + 1}${castOf(e.col.data_type)}`);
    const params = entries.map((e) => e.value);
    const wheres = pk.map((k, i) => `${qid(k)} = $${entries.length + i + 1}`);
    pk.forEach((k) => params.push(pkBody[k]));
    const r = await pool.query(
      `UPDATE dtest2.${qid(table)} SET ${sets.join(', ')} WHERE ${wheres.join(' AND ')} RETURNING *`,
      params
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('未找到该行（主键不匹配）'));
    }
    res.json(ok({ updated: true, row: r.rows[0] }));
  } catch (e) {
    if (e && e.code) {
      return res.status(400).json(fail(`更新失败：${e.message}`));
    }
    serverError(res, '更新数据失败', e);
  }
});

// ---- 删除行（body.pk：主键定位）----
router.delete('/api/admin/db/tables/:table/rows', GUARD, async (req, res) => {
  const table = String(req.params.table || '');
  try {
    if (!(await assertTable(table))) {
      return res.status(404).json(fail('表不存在'));
    }
    const pk = await tablePk(table);
    if (pk.length === 0) {
      return res.status(409).json(fail('该表无主键，不支持按行删除'));
    }
    const pkBody = (req.body || {}).pk || {};
    for (const k of pk) {
      if (pkBody[k] === undefined || pkBody[k] === null) {
        return res.status(400).json(fail(`缺少主键 ${k}`));
      }
    }
    const wheres = pk.map((k, i) => `${qid(k)} = $${i + 1}`);
    const params = pk.map((k) => pkBody[k]);
    const r = await pool.query(
      `DELETE FROM dtest2.${qid(table)} WHERE ${wheres.join(' AND ')}`,
      params
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('未找到该行（主键不匹配）'));
    }
    res.json(ok({ deleted: true }));
  } catch (e) {
    if (e && e.code) {
      // 外键引用等约束错误给精确提示（如先删子表行）
      return res.status(400).json(fail(`删除失败：${e.message}`));
    }
    serverError(res, '删除数据失败', e);
  }
});

module.exports = router;
