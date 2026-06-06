// 管理端域路由（需 role=admin + 细粒度权限）：学生管理 / 成绩审核录入 / 审批 /
// 通知发布 / 角色权限矩阵 / 操作日志 / 评教问卷模板 CRUD。
// 所有端点经 permissionRequired 细粒度鉴权（DB 读取角色权限，fail-closed）。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');
const { mapStudent, mapGradeTask, mapApproval, mapAuditLog, mapTemplate } = require('../mappers');

const router = express.Router();

// ---- 学生管理（列表）----
router.get('/api/admin/students', permissionRequired('students.manage:view'), async (req, res) => {
  const q = req.query.q ? String(req.query.q) : null;
  const college = req.query.college ? String(req.query.college) : null;
  try {
    const r = await pool.query(
      `SELECT student_id, name, college, major, class_name, grade FROM dtest2.student_profiles
       WHERE ($1::text IS NULL OR name ILIKE '%'||$1||'%' OR student_id ILIKE '%'||$1||'%' OR class_name ILIKE '%'||$1||'%')
         AND ($2::text IS NULL OR college = $2)
       ORDER BY student_id`,
      [q, college]
    );
    res.json(ok(r.rows.map(mapStudent)));
  } catch (e) {
    serverError(res, '查询学生失败', e);
  }
});

// ---- 成绩审核（列表）----
router.get('/api/admin/grades', permissionRequired('grades.approve:view', 'grades.input:view'), async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT gt.task_id, gt.teaching_class_name, gt.teacher_name, gt.input_progress, gt.status, gt.reject_reason, gt.updated_at,
              COALESCE(c.name, '') AS course_name
       FROM dtest2.grade_tasks gt LEFT JOIN dtest2.courses c ON c.course_id = gt.course_id
       WHERE ($1::text IS NULL OR gt.status = $1)
       ORDER BY gt.updated_at DESC`,
      [status]
    );
    res.json(ok(r.rows.map(mapGradeTask)));
  } catch (e) {
    serverError(res, '查询成绩审核失败', e);
  }
});

// ---- 成绩录入 ----
router.post('/api/admin/grades/:id/input', permissionRequired('grades.input:update', 'grades.input:create'), async (req, res) => {
  const inputProgress = Number((req.body || {}).inputProgress);
  if (!Number.isInteger(inputProgress) || inputProgress < 0 || inputProgress > 100) {
    return res.status(400).json(fail('录入进度需为 0-100 的整数'));
  }
  try {
    const cur = await pool.query(`SELECT status FROM dtest2.grade_tasks WHERE task_id=$1`, [req.params.id]);
    if (cur.rowCount === 0) {
      return res.status(404).json(fail('成绩任务不存在'));
    }
    const st = cur.rows[0].status;
    if (st !== 'inputting' && st !== 'rejected' && st !== 'appealed') {
      return res.status(409).json(fail('当前状态不可录入'));
    }
    const nextStatus = inputProgress === 100 ? 'pendingAudit' : 'inputting';
    await pool.query(
      `UPDATE dtest2.grade_tasks SET input_progress=$2, status=$3, reject_reason=NULL, updated_at=now() WHERE task_id=$1`,
      [req.params.id, inputProgress, nextStatus]
    );
    const updated = await pool.query(
      `SELECT gt.task_id, gt.teaching_class_name, gt.teacher_name, gt.input_progress, gt.status, gt.reject_reason, gt.updated_at,
              COALESCE(c.name, '') AS course_name
       FROM dtest2.grade_tasks gt LEFT JOIN dtest2.courses c ON c.course_id = gt.course_id WHERE gt.task_id=$1`,
      [req.params.id]
    );
    res.json(ok(mapGradeTask(updated.rows[0])));
  } catch (e) {
    serverError(res, '录入成绩失败', e);
  }
});

// ---- 成绩审核通过 ----
router.post('/api/admin/grades/:id/approve', permissionRequired('grades.approve:approve'), async (req, res) => {
  try {
    const cur = await pool.query(`SELECT status, input_progress FROM dtest2.grade_tasks WHERE task_id=$1`, [req.params.id]);
    if (cur.rowCount === 0) {
      return res.status(404).json(fail('成绩任务不存在'));
    }
    if (cur.rows[0].status !== 'pendingAudit') {
      return res.status(409).json(fail('当前状态不可审核'));
    }
    if (cur.rows[0].input_progress !== 100) {
      return res.status(409).json(fail('录入进度达到 100% 后才能审核通过'));
    }
    await pool.query(`UPDATE dtest2.grade_tasks SET status='published', updated_at=now() WHERE task_id=$1`, [req.params.id]);
    res.json(ok({ approved: true }));
  } catch (e) {
    serverError(res, '审核成绩失败', e);
  }
});

// ---- 成绩驳回 ----
router.post('/api/admin/grades/:id/reject', permissionRequired('grades.approve:approve'), async (req, res) => {
  const reason = ((req.body || {}).reason || '').trim();
  if (!reason) {
    return res.status(400).json(fail('请填写驳回理由'));
  }
  try {
    const cur = await pool.query(`SELECT status FROM dtest2.grade_tasks WHERE task_id=$1`, [req.params.id]);
    if (cur.rowCount === 0) {
      return res.status(404).json(fail('成绩任务不存在'));
    }
    if (cur.rows[0].status !== 'pendingAudit') {
      return res.status(409).json(fail('当前状态不可驳回'));
    }
    await pool.query(`UPDATE dtest2.grade_tasks SET status='rejected', reject_reason=$2, updated_at=now() WHERE task_id=$1`, [req.params.id, reason]);
    res.json(ok({ rejected: true }));
  } catch (e) {
    serverError(res, '驳回成绩失败', e);
  }
});

// ---- 审批（列表）----
router.get('/api/admin/approvals', permissionRequired('approvals.handle:view'), async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT approval_id, biz_type, applicant_name, applicant_id, title, COALESCE(reason, '') AS reason, status, is_urgent, submitted_at
       FROM dtest2.approval_instances WHERE ($1::text IS NULL OR status = $1) ORDER BY submitted_at DESC`,
      [status]
    );
    res.json(ok(r.rows.map(mapApproval)));
  } catch (e) {
    serverError(res, '查询审批失败', e);
  }
});

async function handleApproval(req, res, newStatus, comment) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(`SELECT status, biz_type, biz_id FROM dtest2.approval_instances WHERE approval_id=$1`, [req.params.id]);
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('审批记录不存在'));
    }
    if (cur.rows[0].status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前状态不可操作'));
    }
    await client.query(`UPDATE dtest2.approval_instances SET status=$2, updated_at=now() WHERE approval_id=$1`, [req.params.id, newStatus]);
    await client.query(
      `UPDATE dtest2.approval_steps SET status=$2, comment=$3, handled_at=now() WHERE approval_id=$1 AND step_order=1`,
      [req.params.id, newStatus, comment]
    );
    if (cur.rows[0].biz_type === 'leave') {
      await client.query(
        `UPDATE dtest2.leave_requests SET status=$2, feedback=$3, updated_at=now() WHERE leave_id=$1`,
        [cur.rows[0].biz_id, newStatus, comment]
      );
    }
    await client.query('COMMIT');
    res.json(ok({ handled: true, status: newStatus }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '审批处理失败', e);
  } finally {
    client.release();
  }
}

// ---- 审批通过 ----
router.post('/api/admin/approvals/:id/approve', permissionRequired('approvals.handle:approve'), async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写审批意见'));
  }
  await handleApproval(req, res, 'approved', comment);
});

// ---- 审批驳回 ----
router.post('/api/admin/approvals/:id/reject', permissionRequired('approvals.handle:approve'), async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写驳回意见'));
  }
  await handleApproval(req, res, 'rejected', comment);
});

// ---- 通知发布 ----
const NOTICE_URGENCIES = ['normal', 'important', 'urgent'];
const NOTICE_RECEIVER_TYPES = ['all', 'students', 'teachers', 'custom'];
router.post('/api/admin/notices', permissionRequired('notices.publish:publish', 'notices.publish:create'), async (req, res) => {
  const b = req.body || {};
  const title = ((b.title) || '').trim();
  const content = ((b.content) || '').trim();
  const category = ((b.category) || '').trim() || '通知';
  const publisher = ((b.publisher) || '').trim() || '教务处';
  const urgency = ((b.urgency) || 'normal').trim();
  const receiverType = ((b.receiverType) || 'all').trim();
  const receiverScope = Array.isArray(b.receiverScope) ? b.receiverScope : [];
  if (!title || !content) {
    return res.status(400).json(fail('标题和正文不能为空'));
  }
  if (NOTICE_URGENCIES.indexOf(urgency) < 0) {
    return res.status(400).json(fail('紧急程度不合法'));
  }
  if (NOTICE_RECEIVER_TYPES.indexOf(receiverType) < 0) {
    return res.status(400).json(fail('接收类型不合法'));
  }
  try {
    const id = `notice-${Date.now()}`;
    const summary = content.length > 60 ? content.substring(0, 60) + '...' : content;
    const r = await pool.query(
      `INSERT INTO dtest2.notices
        (notice_id, title, publisher, category, urgency, summary, content, receiver_type, receiver_scope_json, publish_time, published_at, created_by, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, now(), now(), NULL, now())
       RETURNING notice_id, title, publisher, summary, content, category, published_at`,
      [id, title, publisher, category, urgency, summary, content, receiverType, JSON.stringify(receiverScope)]
    );
    const row = r.rows[0];
    res.json(ok({
      id: row.notice_id,
      title: row.title,
      publisher: row.publisher,
      publishedAt: row.published_at,
      summary: row.summary || '',
      content: row.content,
      isRead: false,
      category: row.category,
      attachments: []
    }));
  } catch (e) {
    serverError(res, '发布通知失败', e);
  }
});

// ---- 角色权限矩阵 ----
router.get('/api/admin/roles', permissionRequired('roles.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT r.role_id, r.name AS role_name, COALESCE(r.description, '') AS description, r.member_count,
              p.code, MIN(p.name) AS perm_name, MIN(p.module) AS module, array_agg(p.action ORDER BY p.action) AS actions
       FROM dtest2.roles r
       LEFT JOIN dtest2.role_permissions rp ON rp.role_id = r.role_id
       LEFT JOIN dtest2.permissions p ON p.code = rp.code AND p.action = rp.action
       GROUP BY r.role_id, r.name, r.description, r.member_count, p.code
       ORDER BY r.role_id, p.code`
    );
    const order = [];
    const map = {};
    for (const row of r.rows) {
      if (!map[row.role_id]) {
        map[row.role_id] = {
          id: row.role_id,
          name: row.role_name,
          description: row.description,
          memberCount: row.member_count,
          permissions: []
        };
        order.push(row.role_id);
      }
      if (row.code) {
        map[row.role_id].permissions.push({
          code: row.code,
          name: row.perm_name,
          module: row.module,
          actions: Array.isArray(row.actions) ? row.actions : []
        });
      }
    }
    res.json(ok(order.map((id) => map[id])));
  } catch (e) {
    serverError(res, '查询角色失败', e);
  }
});

// ---- 操作日志 ----
router.get('/api/admin/audit-logs', permissionRequired('audit.view:view'), async (req, res) => {
  const type = req.query.type ? String(req.query.type) : null;
  try {
    const r = await pool.query(
      `SELECT log_id, COALESCE(operator_name, '') AS operator_name, COALESCE(operator_id, '') AS operator_id,
              action, action_type, target, result, COALESCE(ip, '') AS ip, created_at
       FROM dtest2.audit_logs WHERE ($1::text IS NULL OR action_type = $1) ORDER BY created_at DESC LIMIT 200`,
      [type]
    );
    res.json(ok(r.rows.map(mapAuditLog)));
  } catch (e) {
    serverError(res, '查询操作日志失败', e);
  }
});

// ---- 评教问卷模板（CRUD）----
const TEMPLATE_STATUSES = ['enabled', 'disabled'];
router.get('/api/admin/eval/templates', permissionRequired('evaluations.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT template_id, name, description, question_count, status FROM dtest2.evaluation_templates ORDER BY created_at DESC`
    );
    res.json(ok(r.rows.map(mapTemplate)));
  } catch (e) {
    serverError(res, '查询问卷模板失败', e);
  }
});

router.post('/api/admin/eval/templates', permissionRequired('evaluations.manage:create'), async (req, res) => {
  const b = req.body || {};
  const name = ((b.name) || '').trim();
  const description = ((b.description) || '').trim();
  const questionCount = Number(b.questionCount);
  const status = ((b.status) || '').trim();
  if (!name) {
    return res.status(400).json(fail('问卷名称不能为空'));
  }
  if (!Number.isInteger(questionCount) || questionCount < 1 || questionCount > 50) {
    return res.status(400).json(fail('题目数量需为 1-50 的整数'));
  }
  if (TEMPLATE_STATUSES.indexOf(status) < 0) {
    return res.status(400).json(fail('问卷状态不合法'));
  }
  try {
    const id = `qt-${Date.now()}`;
    const r = await pool.query(
      `INSERT INTO dtest2.evaluation_templates (template_id, name, description, question_count, status)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING template_id, name, description, question_count, status`,
      [id, name, description, questionCount, status]
    );
    res.json(ok(mapTemplate(r.rows[0])));
  } catch (e) {
    serverError(res, '新建问卷模板失败', e);
  }
});

router.put('/api/admin/eval/templates/:id', permissionRequired('evaluations.manage:update'), async (req, res) => {
  const b = req.body || {};
  const name = ((b.name) || '').trim();
  const description = ((b.description) || '').trim();
  const questionCount = Number(b.questionCount);
  const status = ((b.status) || '').trim();
  if (!name) {
    return res.status(400).json(fail('问卷名称不能为空'));
  }
  if (!Number.isInteger(questionCount) || questionCount < 1 || questionCount > 50) {
    return res.status(400).json(fail('题目数量需为 1-50 的整数'));
  }
  if (TEMPLATE_STATUSES.indexOf(status) < 0) {
    return res.status(400).json(fail('问卷状态不合法'));
  }
  try {
    const r = await pool.query(
      `UPDATE dtest2.evaluation_templates SET name=$2, description=$3, question_count=$4, status=$5, updated_at=now()
       WHERE template_id=$1
       RETURNING template_id, name, description, question_count, status`,
      [req.params.id, name, description, questionCount, status]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('问卷模板不存在'));
    }
    res.json(ok(mapTemplate(r.rows[0])));
  } catch (e) {
    serverError(res, '更新问卷模板失败', e);
  }
});

router.delete('/api/admin/eval/templates/:id', permissionRequired('evaluations.manage:delete'), async (req, res) => {
  try {
    const r = await pool.query(`DELETE FROM dtest2.evaluation_templates WHERE template_id=$1`, [req.params.id]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('问卷模板不存在'));
    }
    res.json(ok({ deleted: true }));
  } catch (e) {
    serverError(res, '删除问卷模板失败', e);
  }
});

module.exports = router;
