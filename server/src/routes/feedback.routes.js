// 反馈域路由：我的反馈列表 / 提交反馈。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapFeedback } = require('../mappers');

const router = express.Router();

// ---- 反馈 ----
router.get('/api/feedback', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT feedback_id, category, title, content, COALESCE(contact, '') AS contact, state, submitted_at
       FROM dtest2.feedback_items WHERE student_id = $1 ORDER BY submitted_at DESC`,
      [studentId]
    );
    res.json(ok(r.rows.map(mapFeedback)));
  } catch (e) {
    serverError(res, '查询反馈失败', e);
  }
});

const FEEDBACK_CATEGORIES = ['bug', 'suggestion', 'service', 'other'];
router.post('/api/feedback', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = currentStudentId(req);
  const category = ((b.category) || '').trim();
  const title = ((b.title) || '').trim();
  const content = ((b.content) || '').trim();
  const contact = ((b.contact) || '').trim();
  if (!studentId || !category || !title || !content) {
    return res.status(400).json(fail('反馈信息不完整'));
  }
  if (FEEDBACK_CATEGORIES.indexOf(category) < 0) {
    return res.status(400).json(fail('反馈类型不合法'));
  }
  try {
    const id = `fb-${Date.now()}`;
    const r = await pool.query(
      `INSERT INTO dtest2.feedback_items (feedback_id, student_id, category, title, content, contact, state, submitted_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'submitted', now(), now())
       RETURNING feedback_id, category, title, content, COALESCE(contact, '') AS contact, state, submitted_at`,
      [id, studentId, category, title, content, contact || null]
    );
    res.json(ok(mapFeedback(r.rows[0])));
  } catch (e) {
    serverError(res, '提交反馈失败', e);
  }
});

module.exports = router;
