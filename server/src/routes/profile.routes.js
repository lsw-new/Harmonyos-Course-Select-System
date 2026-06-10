// 个人资料域路由：学生更新本人资料（头像/联系方式等）。
// 学号一律取自 JWT（防越权）；头像以压缩后的 base64 data URL 存 student_profiles.avatar_url。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { fetchStudentProfile } = require('../repositories/profile.repo');

const router = express.Router();

const AVATAR_DATA_RE = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/;
const AVATAR_MAX_LEN = 200000; // base64 头像上限约 150KB 原图

function validateAvatar(value) {
  if (value === '') {
    return null; // 允许清除头像
  }
  if (value.length > AVATAR_MAX_LEN) {
    return '头像图片过大，请重新选择';
  }
  if (AVATAR_DATA_RE.test(value)) {
    return null;
  }
  if ((value.startsWith('https://') || value.startsWith('http://')) && value.length <= 500) {
    return null;
  }
  return '头像格式不合法';
}

// ---- 更新本人资料（仅提交的字段会被更新）----
router.put('/api/profile', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId || (req.auth && req.auth.role !== 'student')) {
    return res.status(403).json(fail('仅学生可更新个人资料'));
  }
  const b = req.body || {};
  // 列名 ↔ 请求字段映射；不在表内/未提交的字段一律忽略
  const updatable = [
    ['avatar_url', 'avatarUrl'],
    ['phone', 'phone'],
    ['email', 'email'],
    ['address', 'address'],
    ['emergency_contact', 'emergencyContact'],
    ['bio', 'bio']
  ];
  const sets = [];
  const params = [];
  for (const pair of updatable) {
    const value = b[pair[1]];
    if (typeof value !== 'string') {
      continue;
    }
    if (pair[1] === 'avatarUrl') {
      const err = validateAvatar(value);
      if (err) {
        return res.status(400).json(fail(err));
      }
    } else if (value.length > 200) {
      return res.status(400).json(fail(`${pair[1]} 过长（≤200 字符）`));
    }
    params.push(value);
    sets.push(`${pair[0]} = $${params.length}`);
  }
  if (sets.length === 0) {
    return res.status(400).json(fail('没有可更新的字段'));
  }
  try {
    params.push(studentId);
    const r = await pool.query(
      `UPDATE dtest2.student_profiles SET ${sets.join(', ')}, updated_at = now() WHERE student_id = $${params.length}`,
      params
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('学生资料不存在'));
    }
    const profile = await fetchStudentProfile(studentId);
    res.json(ok(profile));
  } catch (e) {
    serverError(res, '更新资料失败', e);
  }
});

module.exports = router;
