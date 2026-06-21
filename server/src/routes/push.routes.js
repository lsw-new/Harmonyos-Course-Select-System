'use strict';
// 推送通知域（roadmap #8）：设备 token 注册 / 注销。
// 学号一律取自 JWT（currentStudentId），不信任 body，防 IDOR。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { genId } = require('../ids');

const router = express.Router();

// ---- 注册设备 token（登录后、推送权限授予后调用）----
// UPSERT：同一学生同一 token 再次上报 → 只更新 updated_at，不重复插入。
router.post('/api/push/tokens', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const { token, platform } = req.body || {};
  if (!token || String(token).trim().length === 0) {
    return res.status(400).json(fail('token 不能为空'));
  }
  try {
    const tokenId = genId('pt');
    await pool.query(
      `INSERT INTO dtest2.device_tokens (token_id, student_id, token, platform)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (student_id, token)
       DO UPDATE SET updated_at = now()`,
      [tokenId, studentId, String(token).trim(), platform ? String(platform).trim() : null]
    );
    res.json(ok({ registered: true }));
  } catch (e) {
    serverError(res, '注册推送 token 失败', e);
  }
});

// ---- 注销设备 token（登出时调用，清除该设备推送通道）----
router.delete('/api/push/tokens', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const { token } = req.body || {};
  if (!token || String(token).trim().length === 0) {
    return res.status(400).json(fail('token 不能为空'));
  }
  try {
    const r = await pool.query(
      `DELETE FROM dtest2.device_tokens
        WHERE student_id = $1 AND token = $2`,
      [studentId, String(token).trim()]
    );
    res.json(ok({ removed: r.rowCount }));
  } catch (e) {
    serverError(res, '注销推送 token 失败', e);
  }
});

module.exports = router;
