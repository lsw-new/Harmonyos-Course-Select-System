'use strict';
// 管理端·教师管理域：教师账号 + 资料的增删改查（teachers.manage 细粒度权限，fail-closed）。
// 教师身份 = accounts(role='teacher') + teacher_profiles（teacher_id 同主键，姓名唯一）。
// 编号沿用稳定 T 序号（T001、T002…），与 seed-teacher-accounts 同口径。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { permissionRequired } = require('../middleware/permission');
const { serverError, pgClientError } = require('../middleware/errorHandler');
const { hashBcrypt } = require('../hash');

const router = express.Router();

const DEFAULT_TEACHER_PASSWORD = 'Teacher@2024';
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

function emailError(email) {
  if (email.length > 0 && !EMAIL_RE.test(email)) {
    return '邮箱格式不正确';
  }
  return '';
}

// ---- 教师列表（资料 + 账号状态 + 授课门数）----
router.get('/api/admin/teachers', permissionRequired('teachers.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT tp.teacher_id, tp.name, tp.college, tp.title, tp.email, tp.avatar_url,
              COALESCE(a.status, 'active') AS status,
              (SELECT count(*)::int FROM dtest2.course_teachers ct WHERE ct.teacher = tp.name) AS course_count
         FROM dtest2.teacher_profiles tp
         LEFT JOIN dtest2.accounts a ON a.account_id = tp.teacher_id
        ORDER BY tp.teacher_id`
    );
    res.json(ok(r.rows.map((row) => ({
      teacherId: row.teacher_id,
      name: row.name,
      college: row.college || '',
      title: row.title || '',
      email: row.email || '',
      avatarUrl: row.avatar_url || '',
      status: row.status,
      courseCount: Number(row.course_count || 0)
    }))));
  } catch (e) {
    serverError(res, '获取教师列表失败', e);
  }
});

// ---- 新增教师：生成稳定 T 编号，建账号(role=teacher)+资料，默认密码可由请求覆盖 ----
router.post('/api/admin/teachers', permissionRequired('teachers.manage:create'), async (req, res) => {
  const b = req.body || {};
  const name = String(b.name || '').trim();
  const college = String(b.college || '').trim();
  const title = String(b.title || '').trim();
  const email = String(b.email || '').trim();
  const password = String(b.password || '').trim() || DEFAULT_TEACHER_PASSWORD;
  if (!name) {
    return res.status(400).json(fail('教师姓名不能为空'));
  }
  if (name.length > 50) {
    return res.status(400).json(fail('教师姓名过长'));
  }
  const eErr = emailError(email);
  if (eErr) {
    return res.status(400).json(fail(eErr));
  }
  if (password.length < 8 || password.length > 72) {
    return res.status(400).json(fail('密码需为 8-72 位'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 下一个稳定 T 编号（取现有 T 数字最大值 +1）
    const idr = await client.query(
      `SELECT COALESCE(MAX((substring(teacher_id from 2))::int), 0) + 1 AS n
         FROM dtest2.teacher_profiles WHERE teacher_id ~ '^T[0-9]+$'`
    );
    const teacherId = 'T' + String(idr.rows[0].n).padStart(3, '0');
    const hash = await hashBcrypt(password);
    await client.query(
      `INSERT INTO dtest2.accounts (account_id, role, password_hash, salt, status)
       VALUES ($1, 'teacher', $2, '', 'active')`,
      [teacherId, hash]
    );
    await client.query(
      `INSERT INTO dtest2.teacher_profiles (teacher_id, name, college, title, email)
       VALUES ($1, $2, $3, $4, $5)`,
      [teacherId, name, college, title, email]
    );
    await client.query('COMMIT');
    res.json(ok({ teacherId, name, college, title, email, status: 'active' }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    // 23505：姓名唯一约束冲突 → 安全文案；其余交回 500
    pgClientError(res, '新增教师失败', e);
  } finally {
    client.release();
  }
});

// ---- 编辑教师资料（仅提交的字段）----
router.put('/api/admin/teachers/:id', permissionRequired('teachers.manage:update'), async (req, res) => {
  const b = req.body || {};
  const sets = [];
  const params = [];
  if (typeof b.name === 'string') {
    const v = b.name.trim();
    if (!v) {
      return res.status(400).json(fail('教师姓名不能为空'));
    }
    if (v.length > 50) {
      return res.status(400).json(fail('教师姓名过长'));
    }
    params.push(v);
    sets.push(`name=$${params.length}`);
  }
  if (typeof b.college === 'string') {
    params.push(b.college.trim());
    sets.push(`college=$${params.length}`);
  }
  if (typeof b.title === 'string') {
    params.push(b.title.trim());
    sets.push(`title=$${params.length}`);
  }
  if (typeof b.email === 'string') {
    const v = b.email.trim();
    const eErr = emailError(v);
    if (eErr) {
      return res.status(400).json(fail(eErr));
    }
    params.push(v);
    sets.push(`email=$${params.length}`);
  }
  if (sets.length === 0) {
    return res.status(400).json(fail('没有可更新的字段'));
  }
  try {
    params.push(req.params.id);
    const r = await pool.query(
      `UPDATE dtest2.teacher_profiles SET ${sets.join(', ')} WHERE teacher_id=$${params.length}`,
      params
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('教师不存在'));
    }
    res.json(ok({ updated: true }));
  } catch (e) {
    pgClientError(res, '编辑教师失败', e);
  }
});

// ---- 重置教师密码（bcrypt，置空 salt）----
router.post('/api/admin/teachers/:id/reset-password', permissionRequired('teachers.manage:update'), async (req, res) => {
  const password = String((req.body || {}).password || '').trim() || DEFAULT_TEACHER_PASSWORD;
  if (password.length < 8 || password.length > 72) {
    return res.status(400).json(fail('密码需为 8-72 位'));
  }
  try {
    const hash = await hashBcrypt(password);
    const r = await pool.query(
      `UPDATE dtest2.accounts SET password_hash=$2, salt='', updated_at=now()
       WHERE account_id=$1 AND role='teacher'`,
      [req.params.id, hash]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('教师账号不存在'));
    }
    res.json(ok({ reset: true }));
  } catch (e) {
    serverError(res, '重置教师密码失败', e);
  }
});

// ---- 删除教师（资料 + 账号，事务）----
router.delete('/api/admin/teachers/:id', permissionRequired('teachers.manage:delete'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const r = await client.query(`DELETE FROM dtest2.teacher_profiles WHERE teacher_id=$1`, [req.params.id]);
    await client.query(`DELETE FROM dtest2.accounts WHERE account_id=$1 AND role='teacher'`, [req.params.id]);
    await client.query('COMMIT');
    if (r.rowCount === 0) {
      return res.status(404).json(fail('教师不存在'));
    }
    res.json(ok({ deleted: true }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '删除教师失败', e);
  } finally {
    client.release();
  }
});

module.exports = router;
