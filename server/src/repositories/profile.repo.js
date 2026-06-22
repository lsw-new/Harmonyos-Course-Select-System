'use strict';
// 用户资料仓储（P1-03 登录返回真实 profile）：学生查 student_profiles；管理员带角色名 + 权限矩阵。
const { pool } = require('../db');

// 前端权限词表用 evaluation.manage（单数），后端 permissions 表用 evaluations.manage（复数），下发前对齐。
function normalizePermCode(code) {
  return code === 'evaluations.manage' ? 'evaluation.manage' : code;
}

async function fetchStudentProfile(studentId) {
  const r = await pool.query(
    `SELECT student_id, name, avatar_url, college, major, class_name, grade, phone, email, address, emergency_contact, bio
     FROM dtest2.student_profiles WHERE student_id=$1`,
    [studentId]
  );
  if (r.rowCount === 0) return null;
  const p = r.rows[0];
  return {
    studentId: p.student_id, name: p.name, avatarUrl: p.avatar_url || '',
    college: p.college, major: p.major, className: p.class_name, grade: p.grade,
    phone: p.phone || '', email: p.email || '', address: p.address || '',
    emergencyContact: p.emergency_contact || '', bio: p.bio || '', role: 'student'
  };
}

async function fetchAdminProfile(adminId) {
  const r = await pool.query(
    `SELECT ap.admin_id, ap.name, ap.department, ap.role_id, ap.avatar_url, ap.online_status,
            COALESCE(ro.name, '') AS role_name
     FROM dtest2.admin_profiles ap LEFT JOIN dtest2.roles ro ON ro.role_id = ap.role_id
     WHERE ap.admin_id=$1`,
    [adminId]
  );
  if (r.rowCount === 0) return null;
  const a = r.rows[0];
  const permR = await pool.query(
    `SELECT rp.code, MIN(p.name) AS name, MIN(p.module) AS module, array_agg(rp.action ORDER BY rp.action) AS actions
     FROM dtest2.role_permissions rp
     LEFT JOIN dtest2.permissions p ON p.code = rp.code AND p.action = rp.action
     WHERE rp.role_id=$1 GROUP BY rp.code ORDER BY rp.code`,
    [a.role_id]
  );
  const permissions = permR.rows.map((row) => ({
    code: normalizePermCode(row.code),
    name: row.name || row.code,
    module: row.module || '',
    actions: Array.isArray(row.actions) ? row.actions : []
  }));
  return {
    adminId: a.admin_id, name: a.name, department: a.department, roleName: a.role_name,
    avatarUrl: a.avatar_url || '', onlineStatus: a.online_status, permissions
  };
}

async function fetchTeacherProfile(teacherId) {
  const r = await pool.query(
    `SELECT teacher_id, name, college, title, email, avatar_url FROM dtest2.teacher_profiles WHERE teacher_id=$1`,
    [teacherId]
  );
  if (r.rowCount === 0) return null;
  const t = r.rows[0];
  return {
    teacherId: t.teacher_id,
    name: t.name,
    college: t.college || '',
    title: t.title || '',
    email: t.email || '',
    avatarUrl: t.avatar_url || '',
    role: 'teacher'
  };
}

module.exports = { fetchStudentProfile, fetchAdminProfile, normalizePermCode, fetchTeacherProfile };
