// 消息中心域（roadmap #4）：服务端化的个人消息流，已读状态跨设备同步。
// 消息由既有写路径（成绩发布 / 审批结果 / 评教生成）经 ../messages.insertMessage 落库；
// 本路由只负责「读」与「标记已读」，一律按 currentStudentId 收口（防 IDOR 水平越权）。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');

const router = express.Router();

// ---- 当前学生的消息（时间倒序，最多 100 条）----
router.get('/api/messages', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT message_id, kind, title, body, route, param, read_at, created_at
       FROM dtest2.messages
       WHERE student_id = $1
       ORDER BY created_at DESC
       LIMIT 100`,
      [studentId]
    );
    const data = r.rows.map((row) => {
      return {
        messageId: row.message_id,
        kind: row.kind,
        title: row.title,
        body: row.body === null ? '' : row.body,
        route: row.route === null ? '' : row.route,
        param: row.param === null ? '' : row.param,
        read: row.read_at !== null,
        createdAt: row.created_at,
      };
    });
    res.json(ok(data));
  } catch (e) {
    serverError(res, '查询消息失败', e);
  }
});

// ---- 未读条数 ----
router.get('/api/messages/unread-count', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT COUNT(*)::int AS count FROM dtest2.messages
       WHERE student_id = $1 AND read_at IS NULL`,
      [studentId]
    );
    res.json(ok({ count: r.rows[0] ? Number(r.rows[0].count) : 0 }));
  } catch (e) {
    serverError(res, '查询未读消息数失败', e);
  }
});

// ---- 标记单条已读：按 (message_id, student_id) 收口，非本人/不存在 → 404 ----
router.post('/api/messages/:id/read', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `UPDATE dtest2.messages SET read_at = now()
       WHERE message_id = $1 AND student_id = $2
       RETURNING message_id`,
      [req.params.id, studentId]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('消息不存在'));
    }
    res.json(ok({ read: true }));
  } catch (e) {
    serverError(res, '标记消息已读失败', e);
  }
});

module.exports = router;
