// 管理端域路由（需 role=admin + 细粒度权限）：学生管理 / 成绩审核录入 / 审批 /
// 通知发布 / 角色权限矩阵 / 操作日志 / 评教问卷模板 CRUD。
// 所有端点经 permissionRequired 细粒度鉴权（DB 读取角色权限，fail-closed）。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');
const { mapStudent, mapGradeTask, mapApproval, mapAuditLog, mapTemplate, mapFeedback, mapApprovalStep } = require('../mappers');
const { genId } = require('../ids');
const { insertMessage } = require('../messages');

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

// ---- 学生详情（student_profiles 全字段，供管理端学籍详情页）----
router.get('/api/admin/students/:id', permissionRequired('students.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT student_id, name, college, major, class_name, grade, phone, email
       FROM dtest2.student_profiles WHERE student_id=$1`,
      [req.params.id]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('学生不存在'));
    }
    const s = r.rows[0];
    res.json(ok({
      studentId: s.student_id,
      name: s.name,
      college: s.college,
      major: s.major,
      className: s.class_name,
      grade: s.grade || '',
      phone: s.phone || '',
      email: s.email || ''
    }));
  } catch (e) {
    serverError(res, '查询学生详情失败', e);
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

// ---- 成绩打分名单（任务对应班级的已注册学生 + 已录分数）----
router.get('/api/admin/grades/:id/scores', permissionRequired('grades.input:view', 'grades.approve:view'), async (req, res) => {
  try {
    const task = await pool.query(
      `SELECT task_id, course_id, term, teaching_class_name FROM dtest2.grade_tasks WHERE task_id=$1`,
      [req.params.id]
    );
    if (task.rowCount === 0) {
      return res.status(404).json(fail('成绩任务不存在'));
    }
    const t = task.rows[0];
    // 打分对象 = 名册中已注册（有 student_profiles，grades 外键要求）的本班学生
    const r = await pool.query(
      `SELECT cs.student_id, cs.name, g.score
       FROM dtest2.class_students cs
       JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
       LEFT JOIN dtest2.grades g ON g.student_id = cs.student_id AND g.course_id = $2 AND g.term = $3
       WHERE cs.class_name = $1
       ORDER BY cs.student_id`,
      [t.teaching_class_name, t.course_id, t.term]
    );
    const students = r.rows.map((row) => {
      return { studentId: row.student_id, name: row.name, score: row.score === null ? null : Number(row.score) };
    });
    res.json(ok({ taskId: t.task_id, students }));
  } catch (e) {
    serverError(res, '查询打分名单失败', e);
  }
});

// 百分制 → 绩点（4.0 制常用换算：60 分 1.0 起步，每 10 分 +1，封顶 4.0）
function gradePointOf(score) {
  if (score < 60) {
    return 0;
  }
  return Math.min(4.0, Math.round(((score - 50) / 10) * 10) / 10);
}

// ---- 成绩打分（按学生写真实分数；进度按已打分人数自动计算，满员转待审核）----
router.post('/api/admin/grades/:id/scores', permissionRequired('grades.input:update', 'grades.input:create'), async (req, res) => {
  const scores = (req.body || {}).scores;
  if (!Array.isArray(scores) || scores.length === 0) {
    return res.status(400).json(fail('请提供打分数据'));
  }
  for (const s of scores) {
    const score = Number(s && s.score);
    if (!s || typeof s.studentId !== 'string' || !s.studentId.trim() || !Number.isFinite(score) || score < 0 || score > 100) {
      return res.status(400).json(fail('分数需为 0-100 的数字'));
    }
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const task = await client.query(
      `SELECT course_id, term, teaching_class_name, status FROM dtest2.grade_tasks WHERE task_id=$1 FOR UPDATE`,
      [req.params.id]
    );
    if (task.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('成绩任务不存在'));
    }
    const t = task.rows[0];
    if (t.status === 'published') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('成绩已发布，不可再打分'));
    }
    // 校验打分名单：仅允许给本教学班「已注册」学生打分，杜绝向任意学号写成绩（数据污染）
    const roster = await client.query(
      `SELECT cs.student_id FROM dtest2.class_students cs
       JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
       WHERE cs.class_name = $1`,
      [t.teaching_class_name]
    );
    const allowed = new Set(roster.rows.map((x) => x.student_id));
    const sids = [];
    const scoreVals = [];
    const gradePoints = [];
    for (const s of scores) {
      const sid = s.studentId.trim();
      if (!allowed.has(sid)) {
        await client.query('ROLLBACK');
        return res.status(400).json(fail('打分名单包含不属于该教学班的学生'));
      }
      const score = Number(s.score);
      sids.push(sid);
      scoreVals.push(score);
      gradePoints.push(gradePointOf(score));
    }
    // 批量 UPSERT：原本逐人一条 INSERT（47 人=47 次往返、占用行锁更久）合并为 1 条 UNNEST 语句
    await client.query(
      `INSERT INTO dtest2.grades (grade_id, task_id, student_id, course_id, term, score, grade_point, rank, published_at)
       SELECT 'g-' || $2 || '-' || x.sid, $1, x.sid, $2, $3, x.score, x.gp, 0, NULL
       FROM unnest($4::text[], $5::numeric[], $6::numeric[]) AS x(sid, score, gp)
       ON CONFLICT (student_id, course_id, term) DO UPDATE
         SET score=EXCLUDED.score, grade_point=EXCLUDED.grade_point, task_id=EXCLUDED.task_id, published_at=NULL`,
      [req.params.id, t.course_id, t.term, sids, scoreVals, gradePoints]
    );
    // 重算该课程本学期排名（同分同名次）
    await client.query(
      `UPDATE dtest2.grades g SET rank = r.rnk
       FROM (SELECT grade_id, RANK() OVER (ORDER BY score DESC) AS rnk
             FROM dtest2.grades WHERE course_id=$1 AND term=$2) r
       WHERE g.grade_id = r.grade_id`,
      [t.course_id, t.term]
    );
    // 进度 = 已打分人数 / 本班已注册人数；满 100 自动转待审核
    const counts = await client.query(
      `SELECT
         (SELECT count(*) FROM dtest2.class_students cs
            JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
            WHERE cs.class_name = $1) AS total,
         (SELECT count(*) FROM dtest2.grades g
            JOIN dtest2.class_students cs2 ON cs2.student_id = g.student_id AND cs2.class_name = $1
            WHERE g.course_id = $2 AND g.term = $3) AS scored`,
      [t.teaching_class_name, t.course_id, t.term]
    );
    const total = Number(counts.rows[0].total);
    const scored = Number(counts.rows[0].scored);
    const progress = total > 0 ? Math.min(100, Math.floor((scored / total) * 100)) : 0;
    const nextStatus = progress === 100 ? 'pendingAudit' : 'inputting';
    await client.query(
      `UPDATE dtest2.grade_tasks SET input_progress=$2, status=$3, reject_reason=NULL, updated_at=now() WHERE task_id=$1`,
      [req.params.id, progress, nextStatus]
    );
    await client.query('COMMIT');
    // COMMIT 后用同一 client（仍持有至 finally release）读回，避免事务块内混用 pool 另取连接
    const updated = await client.query(
      `SELECT gt.task_id, gt.teaching_class_name, gt.teacher_name, gt.input_progress, gt.status, gt.reject_reason, gt.updated_at,
              COALESCE(c.name, '') AS course_name
       FROM dtest2.grade_tasks gt LEFT JOIN dtest2.courses c ON c.course_id = gt.course_id WHERE gt.task_id=$1`,
      [req.params.id]
    );
    res.json(ok(mapGradeTask(updated.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '保存打分失败', e);
  } finally {
    client.release();
  }
});

// ---- 成绩审核通过（同时发布该任务的全部成绩行，学生端即可见）----
router.post('/api/admin/grades/:id/approve', permissionRequired('grades.approve:approve'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(
      `SELECT gt.status, gt.input_progress, gt.term, gt.teaching_class_name,
              COALESCE(c.name, '') AS course_name
       FROM dtest2.grade_tasks gt
       LEFT JOIN dtest2.courses c ON c.course_id = gt.course_id
       WHERE gt.task_id=$1 FOR UPDATE OF gt`,
      [req.params.id]
    );
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('成绩任务不存在'));
    }
    if (cur.rows[0].status !== 'pendingAudit') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前状态不可审核'));
    }
    if (cur.rows[0].input_progress !== 100) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('录入进度达到 100% 后才能审核通过'));
    }
    await client.query(`UPDATE dtest2.grade_tasks SET status='published', updated_at=now() WHERE task_id=$1`, [req.params.id]);
    await client.query(`UPDATE dtest2.grades SET published_at=now() WHERE task_id=$1 AND published_at IS NULL`, [req.params.id]);
    // 消息中心（roadmap #4）：成绩发布后，给该任务下每名有成绩行的学生各发一条 kind:'grade' 消息。
    // 复用同一事务，消息与发布同生共死；插入失败走外层 catch 的 ROLLBACK。
    const task = cur.rows[0];
    const courseLabel = task.course_name || task.teaching_class_name || '课程';
    const affected = await client.query(
      `SELECT DISTINCT student_id FROM dtest2.grades WHERE task_id=$1`,
      [req.params.id]
    );
    for (const row of affected.rows) {
      await insertMessage(client, {
        studentId: row.student_id,
        kind: 'grade',
        title: `《${courseLabel}》成绩已发布`,
        body: `${courseLabel} · ${task.term || ''} 成绩已发布，点击查看`,
        route: 'pages/GradesPage',
      });
    }
    await client.query('COMMIT');
    res.json(ok({ approved: true }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '审核成绩失败', e);
  } finally {
    client.release();
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
    // 多级审批进度：按 approval_id 批量拉取有序步骤，挂到每条审批的 steps 上（前端进度条）。
    const ids = r.rows.map((row) => row.approval_id);
    const stepsByApproval = {};
    if (ids.length > 0) {
      const sr = await pool.query(
        `SELECT approval_id, step_order, node_name, approver_role, operator_id, status, handled_at, comment
         FROM dtest2.approval_steps WHERE approval_id = ANY($1::text[]) ORDER BY approval_id, step_order`,
        [ids]
      );
      for (const srow of sr.rows) {
        (stepsByApproval[srow.approval_id] = stepsByApproval[srow.approval_id] || []).push(mapApprovalStep(srow));
      }
    }
    res.json(ok(r.rows.map((row) => {
      const ap = mapApproval(row);
      ap.steps = stepsByApproval[row.approval_id] || [];
      return ap;
    })));
  } catch (e) {
    serverError(res, '查询审批失败', e);
  }
});

// 审批终态 → 申请人消息（roadmap #4）。inst 为 approval_instances 行（含 applicant_id/biz_type/biz_id/title）。
// 请假类深链到请假详情（param=leave_id）；其余审批不带路由参数。同事务调用，插入失败由外层 catch 回滚。
async function insertApprovalMessage(client, inst, result, comment) {
  if (!inst || !inst.applicant_id) {
    return;
  }
  const subject = inst.title || '申请';
  const approved = result === 'approved';
  const title = approved ? `${subject}已通过` : `${subject}被驳回`;
  let body = approved ? '审批已通过' : '审批被驳回';
  if (comment) {
    body = `${body} · ${comment}`;
  }
  const isLeave = inst.biz_type === 'leave';
  await insertMessage(client, {
    studentId: inst.applicant_id,
    kind: 'approval',
    title,
    body,
    route: isLeave ? 'pages/LeaveDetailPage' : undefined,
    param: isLeave ? inst.biz_id : undefined,
  });
}

// 多级审批推进：审批人对“当前激活步骤”操作。
//  - approve 非末步 → 该步 approved，激活下一步（waiting→pending），实例/请假仍 pending；
//  - approve 末步 → 该步 approved，实例/请假置 approved；
//  - reject 任意激活步 → 该步 rejected，剩余未完结步骤一并 rejected（终止），实例/请假置 rejected。
// 事务内对实例与步骤加 FOR UPDATE 行锁，避免并发双处理。
async function handleApproval(req, res, newStatus, comment) {
  const operatorId = req.auth && req.auth.sub ? req.auth.sub : null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(
      `SELECT status, biz_type, biz_id, applicant_id, COALESCE(title, '') AS title FROM dtest2.approval_instances WHERE approval_id=$1 FOR UPDATE`,
      [req.params.id]
    );
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('审批记录不存在'));
    }
    if (cur.rows[0].status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前状态不可操作'));
    }
    // 当前激活步骤 = 最小 step_order 的 pending 步；加锁后再读 steps 总数判断是否末步。
    const active = await client.query(
      `SELECT step_order FROM dtest2.approval_steps
       WHERE approval_id=$1 AND status='pending' ORDER BY step_order ASC LIMIT 1 FOR UPDATE`,
      [req.params.id]
    );
    // 无激活步骤时回退兼容旧单步数据（按 step_order=1 处理）。
    const activeOrder = active.rowCount > 0 ? active.rows[0].step_order : 1;
    const totalRow = await client.query(
      `SELECT COALESCE(MAX(step_order), 1) AS max_order FROM dtest2.approval_steps WHERE approval_id=$1`,
      [req.params.id]
    );
    const maxOrder = totalRow.rowCount > 0 ? totalRow.rows[0].max_order : activeOrder;
    const isLastStep = activeOrder >= maxOrder;

    if (newStatus === 'rejected') {
      // 当前激活步 rejected + 其余未完结步骤（pending/waiting）一并 rejected（终止流程）。
      await client.query(
        `UPDATE dtest2.approval_steps SET status='rejected', operator_id=$2, comment=$3, handled_at=now()
         WHERE approval_id=$1 AND step_order=$4`,
        [req.params.id, operatorId, comment, activeOrder]
      );
      await client.query(
        `UPDATE dtest2.approval_steps SET status='rejected', handled_at=now()
         WHERE approval_id=$1 AND status IN ('pending', 'waiting')`,
        [req.params.id]
      );
      await client.query(`UPDATE dtest2.approval_instances SET status='rejected', updated_at=now() WHERE approval_id=$1`, [req.params.id]);
      if (cur.rows[0].biz_type === 'leave') {
        await client.query(
          `UPDATE dtest2.leave_requests SET status='rejected', feedback=$2, updated_at=now() WHERE leave_id=$1`,
          [cur.rows[0].biz_id, comment]
        );
      }
      // 消息中心（roadmap #4）：审批驳回（终态）→ 给申请人发 kind:'approval' 消息。同事务。
      await insertApprovalMessage(client, cur.rows[0], 'rejected', comment);
      await client.query('COMMIT');
      return res.json(ok({ handled: true, status: 'rejected', step: activeOrder, finalized: true }));
    }

    // approve：当前激活步置 approved。
    await client.query(
      `UPDATE dtest2.approval_steps SET status='approved', operator_id=$2, comment=$3, handled_at=now()
       WHERE approval_id=$1 AND step_order=$4`,
      [req.params.id, operatorId, comment, activeOrder]
    );
    if (isLastStep) {
      // 末步通过 → 实例/请假 approved。
      await client.query(`UPDATE dtest2.approval_instances SET status='approved', current_step=$2, updated_at=now() WHERE approval_id=$1`, [req.params.id, activeOrder]);
      if (cur.rows[0].biz_type === 'leave') {
        await client.query(
          `UPDATE dtest2.leave_requests SET status='approved', feedback=$2, updated_at=now() WHERE leave_id=$1`,
          [cur.rows[0].biz_id, comment]
        );
      }
      // 消息中心（roadmap #4）：末步通过（终态）→ 给申请人发 kind:'approval' 消息。同事务。
      await insertApprovalMessage(client, cur.rows[0], 'approved', comment);
      await client.query('COMMIT');
      return res.json(ok({ handled: true, status: 'approved', step: activeOrder, finalized: true }));
    }
    // 非末步通过 → 激活下一步（waiting→pending），实例 current_step 前移，整体仍 pending。
    const nextOrder = activeOrder + 1;
    await client.query(
      `UPDATE dtest2.approval_steps SET status='pending' WHERE approval_id=$1 AND step_order=$2 AND status='waiting'`,
      [req.params.id, nextOrder]
    );
    await client.query(`UPDATE dtest2.approval_instances SET current_step=$2, updated_at=now() WHERE approval_id=$1`, [req.params.id, nextOrder]);
    await client.query('COMMIT');
    res.json(ok({ handled: true, status: 'pending', step: activeOrder, nextStep: nextOrder, finalized: false }));
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
    const id = genId('notice');
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
      urgency: urgency,
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

// ---- 操作日志（?type= 按操作类型、?operator= 按账号过滤）----
router.get('/api/admin/audit-logs', permissionRequired('audit.view:view'), async (req, res) => {
  const type = req.query.type ? String(req.query.type) : null;
  const operator = req.query.operator ? String(req.query.operator) : null;
  try {
    const r = await pool.query(
      `SELECT log_id, COALESCE(operator_name, '') AS operator_name, COALESCE(operator_id, '') AS operator_id,
              action, action_type, target, result, COALESCE(ip, '') AS ip, created_at
       FROM dtest2.audit_logs
       WHERE ($1::text IS NULL OR action_type = $1)
         AND ($2::text IS NULL OR operator_id = $2)
       ORDER BY created_at DESC LIMIT 200`,
      [type, operator]
    );
    res.json(ok(r.rows.map(mapAuditLog)));
  } catch (e) {
    serverError(res, '查询操作日志失败', e);
  }
});

// ---- 操作日志账号清单（按账号分组：账号 / 姓名 / 日志条数 / 最近操作时间）----
router.get('/api/admin/audit-operators', permissionRequired('audit.view:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT operator_id, MAX(COALESCE(operator_name, '')) AS operator_name,
              COUNT(*)::int AS log_count, MAX(created_at) AS last_at
       FROM dtest2.audit_logs
       WHERE COALESCE(operator_id, '') <> ''
       GROUP BY operator_id
       ORDER BY MAX(created_at) DESC`
    );
    res.json(ok(r.rows.map((row) => ({
      operatorId: row.operator_id,
      operatorName: row.operator_name || '',
      logCount: row.log_count,
      lastAt: row.last_at
    }))));
  } catch (e) {
    serverError(res, '查询日志账号失败', e);
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
    const id = genId('qt');
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

// ---- 意见反馈：列表（可按状态/类型过滤）----
const FEEDBACK_STATES = ['submitted', 'processing', 'closed'];
const FEEDBACK_CATEGORIES_ADMIN = ['bug', 'suggestion', 'service', 'other'];
router.get('/api/admin/feedback', permissionRequired('feedback.handle:view'), async (req, res) => {
  const state = req.query.state ? String(req.query.state) : null;
  const category = req.query.category ? String(req.query.category) : null;
  try {
    const r = await pool.query(
      `SELECT f.feedback_id, f.student_id, f.category, f.title, f.content,
              COALESCE(f.contact, '') AS contact, f.state, f.submitted_at,
              f.reply, f.replied_by, f.replied_at,
              COALESCE(s.name, '') AS student_name,
              COALESCE(a.name, '') AS replied_by_name
       FROM dtest2.feedback_items f
       LEFT JOIN dtest2.student_profiles s ON s.student_id = f.student_id
       LEFT JOIN dtest2.admin_profiles a ON a.admin_id = f.replied_by
       WHERE ($1::text IS NULL OR f.state = $1)
         AND ($2::text IS NULL OR f.category = $2)
       ORDER BY f.submitted_at DESC LIMIT 500`,
      [state, category]
    );
    res.json(ok(r.rows.map(mapFeedback)));
  } catch (e) {
    serverError(res, '查询意见反馈失败', e);
  }
});

// ---- 意见反馈：详情 ----
router.get('/api/admin/feedback/:id', permissionRequired('feedback.handle:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT f.feedback_id, f.student_id, f.category, f.title, f.content,
              COALESCE(f.contact, '') AS contact, f.state, f.submitted_at,
              f.reply, f.replied_by, f.replied_at,
              COALESCE(s.name, '') AS student_name,
              COALESCE(a.name, '') AS replied_by_name
       FROM dtest2.feedback_items f
       LEFT JOIN dtest2.student_profiles s ON s.student_id = f.student_id
       LEFT JOIN dtest2.admin_profiles a ON a.admin_id = f.replied_by
       WHERE f.feedback_id = $1`,
      [req.params.id]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('反馈记录不存在'));
    }
    res.json(ok(mapFeedback(r.rows[0])));
  } catch (e) {
    serverError(res, '查询反馈详情失败', e);
  }
});

// ---- 意见反馈：处理（修改状态 + 回复，可二选一或同时）----
router.patch('/api/admin/feedback/:id', permissionRequired('feedback.handle:update'), async (req, res) => {
  const b = req.body || {};
  const nextState = b.state ? String(b.state).trim() : '';
  const reply = typeof b.reply === 'string' ? b.reply.trim() : '';
  if (nextState && FEEDBACK_STATES.indexOf(nextState) < 0) {
    return res.status(400).json(fail('反馈状态不合法'));
  }
  if (!nextState && !reply) {
    return res.status(400).json(fail('请填写回复或更新状态'));
  }
  const adminId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
  try {
    const cur = await pool.query(`SELECT state FROM dtest2.feedback_items WHERE feedback_id=$1`, [req.params.id]);
    if (cur.rowCount === 0) {
      return res.status(404).json(fail('反馈记录不存在'));
    }
    const updates = [];
    const params = [req.params.id];
    let i = 2;
    if (nextState) { updates.push(`state=$${i++}`); params.push(nextState); }
    if (reply) {
      updates.push(`reply=$${i++}`); params.push(reply);
      updates.push(`replied_by=$${i++}`); params.push(adminId);
      updates.push(`replied_at=now()`);
    }
    updates.push(`updated_at=now()`);
    const r = await pool.query(
      `UPDATE dtest2.feedback_items SET ${updates.join(', ')} WHERE feedback_id=$1
       RETURNING feedback_id, student_id, category, title, content,
                 COALESCE(contact, '') AS contact, state, submitted_at,
                 reply, replied_by, replied_at`,
      params
    );
    res.json(ok(mapFeedback(r.rows[0])));
  } catch (e) {
    serverError(res, '处理意见反馈失败', e);
  }
});

// ---- 学籍注册字段更新（roadmap #3）：管理端按学号写学籍档案字段 ----
// 可更新字段：political_status/ethnicity/native_place/enrollment_date/program_length/education_level/enrollment_status。
// 学生身份从 URL param 取（管理端操作指定学生，与 /api/profile/record 的 JWT 自取分离）。
// 所有字段 nullable text（enrollment_date 接受 ISO 日期串或空串清空），参数化查询杜绝注入。
const STUDENT_RECORD_FIELDS = [
  ['political_status', 'politicalStatus'],
  ['ethnicity', 'ethnicity'],
  ['native_place', 'nativePlace'],
  ['enrollment_date', 'enrollmentDate'],
  ['program_length', 'programLength'],
  ['education_level', 'educationLevel'],
  ['enrollment_status', 'enrollmentStatus']
];

router.put('/api/admin/students/:id/record', permissionRequired('students.manage:update'), async (req, res) => {
  const studentId = String(req.params.id || '').trim();
  if (!studentId) {
    return res.status(400).json(fail('缺少学号'));
  }
  const b = req.body || {};
  const sets = [];
  const params = [];
  for (const [col, key] of STUDENT_RECORD_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(b, key)) {
      continue;
    }
    const raw = b[key];
    // 接受 null（清空）或非空字符串；其他类型拒绝
    if (raw !== null && typeof raw !== 'string') {
      return res.status(400).json(fail(`${key} 必须为字符串或 null`));
    }
    const value = raw === null ? null : raw.trim() === '' ? null : raw.trim();
    // enrollment_date 简单格式校验（YYYY-MM-DD 或空/null）
    if (col === 'enrollment_date' && value !== null && !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return res.status(400).json(fail('enrollment_date 格式须为 YYYY-MM-DD'));
    }
    params.push(value);
    sets.push(`${col} = $${params.length}`);
  }
  if (sets.length === 0) {
    return res.status(400).json(fail('没有可更新的学籍字段'));
  }
  try {
    params.push(studentId);
    const r = await pool.query(
      `UPDATE dtest2.student_profiles SET ${sets.join(', ')}, updated_at = now() WHERE student_id = $${params.length}`,
      params
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('学生不存在'));
    }
    res.json(ok({ updated: true, studentId }));
  } catch (e) {
    serverError(res, '更新学籍字段失败', e);
  }
});

module.exports = router;
