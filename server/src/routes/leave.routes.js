// 请假域路由：我的请假列表 / 提交请假（事务内同步创建审批实例，leave -> approval 闭环）。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapLeave, leaveTypeLabel } = require('../mappers');

const router = express.Router();

// ---- 我的请假 ----
router.get('/api/leave', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT leave_id, type, to_char(start_date, 'YYYY-MM-DD') AS start_date, to_char(end_date, 'YYYY-MM-DD') AS end_date,
              reason, status, COALESCE(feedback, '') AS feedback, submitted_at
       FROM dtest2.leave_requests WHERE student_id = $1 ORDER BY submitted_at DESC`,
      [studentId]
    );
    res.json(ok(r.rows.map(mapLeave)));
  } catch (e) {
    serverError(res, '查询请假失败', e);
  }
});

// ---- 提交请假（事务内同步创建审批实例，leave -> approval 闭环）----
const LEAVE_TYPES = ['sick', 'personal', 'public', 'other'];
router.post('/api/leave', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = currentStudentId(req);
  const type = ((b.type) || '').trim();
  const startDate = ((b.startDate) || '').trim();
  const endDate = ((b.endDate) || '').trim();
  const reason = ((b.reason) || '').trim();
  if (!studentId || !type || !startDate || !endDate || !reason) {
    return res.status(400).json(fail('请假信息不完整'));
  }
  if (LEAVE_TYPES.indexOf(type) < 0) {
    return res.status(400).json(fail('请假类型不合法'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const leaveId = `lv-${Date.now()}`;
    const r = await client.query(
      `INSERT INTO dtest2.leave_requests (leave_id, student_id, type, start_date, end_date, reason, status, submitted_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending', now(), now())
       RETURNING leave_id, type, to_char(start_date, 'YYYY-MM-DD') AS start_date, to_char(end_date, 'YYYY-MM-DD') AS end_date,
                 reason, status, COALESCE(feedback, '') AS feedback, submitted_at`,
      [leaveId, studentId, type, startDate, endDate, reason]
    );
    const nameRow = await client.query(`SELECT name FROM dtest2.student_profiles WHERE student_id=$1`, [studentId]);
    const applicantName = nameRow.rowCount > 0 ? nameRow.rows[0].name : studentId;
    const approvalId = `ap-${leaveId}`;
    await client.query(
      `INSERT INTO dtest2.approval_instances
        (approval_id, biz_type, biz_id, applicant_id, applicant_name, title, reason, status, is_urgent, current_step, submitted_at, updated_at)
       VALUES ($1, 'leave', $2, $3, $4, $5, $6, 'pending', false, 1, now(), now())
       ON CONFLICT (biz_type, biz_id) DO NOTHING`,
      [approvalId, leaveId, studentId, applicantName, leaveTypeLabel(type) + '请假申请', reason]
    );
    await client.query(
      `INSERT INTO dtest2.approval_steps (step_id, approval_id, step_order, node_name, approver_role, status)
       VALUES ($1, $2, 1, '教务审批', '教务管理员', 'pending')
       ON CONFLICT (approval_id, step_order) DO NOTHING`,
      [`step-${approvalId}-1`, approvalId]
    );
    await client.query('COMMIT');
    res.json(ok(mapLeave(r.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '提交请假失败', e);
  } finally {
    client.release();
  }
});

module.exports = router;
