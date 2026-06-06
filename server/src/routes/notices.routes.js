// 通知域路由：通知列表 / 通知详情 / 标记已读。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapNotice } = require('../mappers');

const router = express.Router();

// ---- 通知列表 ----
router.get('/api/notices', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const category = req.query.category ? String(req.query.category) : null;
  try {
    const r = await pool.query(
      `SELECT n.notice_id, n.title, n.publisher, n.summary, n.content, n.category, n.published_at,
              CASE WHEN nr.notice_id IS NULL THEN false ELSE true END AS is_read
       FROM dtest2.notices n
       LEFT JOIN dtest2.notice_reads nr ON nr.notice_id = n.notice_id AND nr.student_id = $1
       WHERE ($2::text IS NULL OR n.category = $2)
       ORDER BY n.published_at DESC`,
      [studentId, category]
    );
    res.json(ok(r.rows.map(mapNotice)));
  } catch (e) {
    serverError(res, '查询通知失败', e);
  }
});

// ---- 通知详情 ----
router.get('/api/notices/:id', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  try {
    const r = await pool.query(
      `SELECT n.notice_id, n.title, n.publisher, n.summary, n.content, n.category, n.published_at,
              CASE WHEN nr.notice_id IS NULL THEN false ELSE true END AS is_read
       FROM dtest2.notices n
       LEFT JOIN dtest2.notice_reads nr ON nr.notice_id = n.notice_id AND nr.student_id = $1
       WHERE n.notice_id = $2 LIMIT 1`,
      [studentId, req.params.id]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('通知不存在'));
    }
    res.json(ok(mapNotice(r.rows[0])));
  } catch (e) {
    serverError(res, '查询通知失败', e);
  }
});

// ---- 通知标记已读 ----
router.post('/api/notices/:id/read', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    await pool.query(
      `INSERT INTO dtest2.notice_reads (notice_id, student_id, read_at) VALUES ($1, $2, now())
       ON CONFLICT (notice_id, student_id) DO NOTHING`,
      [req.params.id, studentId]
    );
    res.json(ok({ read: true }));
  } catch (e) {
    serverError(res, '标记已读失败', e);
  }
});

module.exports = router;
