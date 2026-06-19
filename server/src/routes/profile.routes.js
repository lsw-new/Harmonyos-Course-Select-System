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

// ---- 学籍详情（基础字段取 student_profiles；GPA/已修学分/门数实时聚合已发布成绩）----
// 数据库无的字段（导师/宿舍/学制/培养类别）返回 null，不编造假值。
router.get('/api/profile/record', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    // 一条 SQL：主表 + 子查询聚合（仅 published_at IS NOT NULL 计入），避免 N+1。
    const r = await pool.query(
      `SELECT sp.student_id, sp.name, sp.avatar_url, sp.college, sp.major, sp.class_name,
              sp.grade, sp.phone, sp.email, sp.address, sp.emergency_contact, sp.bio,
              agg.gpa, agg.earned_credits, agg.passed_count
       FROM dtest2.student_profiles sp
       LEFT JOIN (
         SELECT g.student_id,
                AVG(g.grade_point) AS gpa,
                SUM(COALESCE(c.credit, 0)) AS earned_credits,
                COUNT(*) AS passed_count
         FROM dtest2.grades g
         LEFT JOIN dtest2.courses c ON c.course_id = g.course_id
         WHERE g.student_id = $1 AND g.published_at IS NOT NULL
         GROUP BY g.student_id
       ) agg ON agg.student_id = sp.student_id
       WHERE sp.student_id = $1`,
      [studentId]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('学生资料不存在'));
    }
    const p = r.rows[0];
    const record = {
      studentId: p.student_id,
      name: p.name,
      avatarUrl: p.avatar_url || '',
      college: p.college,
      major: p.major,
      className: p.class_name,
      grade: p.grade,
      phone: p.phone || '',
      email: p.email || '',
      address: p.address || '',
      emergencyContact: p.emergency_contact || '',
      bio: p.bio || '',
      // 实时聚合（无已发布成绩时为 0 / null）
      gpa: p.gpa === null || p.gpa === undefined ? null : Number(Number(p.gpa).toFixed(2)),
      earnedCredits: p.earned_credits === null || p.earned_credits === undefined ? 0 : Number(p.earned_credits),
      passedCount: p.passed_count === null || p.passed_count === undefined ? 0 : Number(p.passed_count),
      // 数据库确无的字段，明确返回 null（不编造）
      advisor: null,
      dormitory: null,
      eduSystem: null,
      trainingType: null
    };
    res.json(ok(record));
  } catch (e) {
    serverError(res, '查询学籍详情失败', e);
  }
});

// ---- 登录历史（当前账号最近 10 条 action_type='login' 审计事件）----
router.get('/api/profile/login-history', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT log_id, action, result, ip, created_at
       FROM dtest2.audit_logs
       WHERE operator_id = $1 AND action_type = 'login'
       ORDER BY created_at DESC
       LIMIT 10`,
      [studentId]
    );
    const data = r.rows.map((row) => ({
      id: row.log_id,
      action: row.action,
      result: row.result,
      ip: row.ip || '',
      time: row.created_at
    }));
    res.json(ok(data));
  } catch (e) {
    serverError(res, '查询登录历史失败', e);
  }
});

module.exports = router;
