// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { ok, fail } = require('./envelope');
const {
  deriveTimeText, parseCourseWeeks, coursesConflict, mapCourse, COURSE_COLUMNS, SELECTED_COUNT_JOIN,
  mapNotice, mapLeave, mapFeedback, mapEval, mapPractice, PRACTICE_SELECT,
  leaveTypeLabel, mapStudent, mapGradeTask, mapApproval, mapAuditLog, mapTemplate
} = require('./mappers');
const { authRequired } = require('./auth');
const { globalLimiter } = require('./middleware/rateLimit');
const { serverError } = require('./middleware/errorHandler');
const { currentStudentId } = require('./identity');
const { permissionRequired } = require('./middleware/permission');

const app = express();

// HTTPS：仅信任本地回环反代（nginx）转发的 X-Forwarded-For，使限流/req.ip 取到真实客户端 IP；
// 外部直连 :8090 的对端非回环，不会被信任，无法伪造 IP 绕过限流。
app.set('trust proxy', 'loopback');

// P2-01：CORS 收紧。原生 App 不受浏览器 CORS 约束；默认关闭跨域，
// 仅当 .env 配置 CORS_ORIGINS（逗号分隔）时放行可信域名。
const CORS_ORIGINS = (process.env.CORS_ORIGINS || '')
  .split(',').map((s) => s.trim()).filter((s) => s.length > 0);
app.use(cors({ origin: CORS_ORIGINS.length > 0 ? CORS_ORIGINS : false, credentials: true }));

app.use(globalLimiter);
app.use(express.json());

// ---- 健康检查 ----
app.get('/health', async (req, res) => {
  try {
    const r = await pool.query('SELECT now() AS now');
    res.json(ok({ db: 'ok', now: r.rows[0].now }));
  } catch (e) {
    serverError(res, '数据库连接失败', e);
  }
});

// ---- 认证域（登录 / 邮箱验证码 / 注册 / 找回密码）已抽到 ./routes/auth.routes ----
app.use(require('./routes/auth.routes'));

// ---- 选课域（课程列表 / 选课轮次 / 我的已选 / 选课 / 退课）已抽到 ./routes/selection.routes ----
app.use(require('./routes/selection.routes'));

// ---- 成绩域（当前学生已发布成绩）已抽到 ./routes/grades.routes ----
app.use(require('./routes/grades.routes'));

// ---- 通知域（列表 / 详情 / 标记已读）已抽到 ./routes/notices.routes ----
app.use(require('./routes/notices.routes'));

// ---- 请假域（我的请假 / 提交请假含 approval 闭环）已抽到 ./routes/leave.routes ----
app.use(require('./routes/leave.routes'));

// ---- 反馈域（我的反馈 / 提交反馈）已抽到 ./routes/feedback.routes ----
app.use(require('./routes/feedback.routes'));

// ---- 评教任务 ----
app.get('/api/evaluations', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  try {
    const r = await pool.query(
      `SELECT et.task_id, et.term, et.teacher_name, et.status, et.open_time, et.close_time,
              COALESCE(c.code, '') AS code, COALESCE(c.name, '') AS name, COALESCE(c.category, '') AS category,
              COALESCE(tpl.name, '') AS questionnaire_name
       FROM dtest2.evaluation_tasks et
       LEFT JOIN dtest2.courses c ON c.course_id = et.course_id
       LEFT JOIN dtest2.evaluation_templates tpl ON tpl.template_id = et.template_id
       WHERE et.student_id = $1 AND ($2::text IS NULL OR et.term = $2)
       ORDER BY et.open_time DESC NULLS LAST`,
      [studentId, term]
    );
    res.json(ok(r.rows.map(mapEval)));
  } catch (e) {
    serverError(res, '查询评教失败', e);
  }
});

// ---- 评教提交 ----
app.post('/api/evaluations/:taskId/submit', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = currentStudentId(req);
  const answers = b.answers;
  const taskId = req.params.taskId;
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  if (!Array.isArray(answers) || answers.length === 0) {
    return res.status(400).json(fail('答案为空'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const task = await client.query(
      `SELECT status FROM dtest2.evaluation_tasks WHERE task_id=$1 AND student_id=$2`, [taskId, studentId]
    );
    if (task.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('评教任务不存在'));
    }
    if (task.rows[0].status !== 'open') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前任务不在开放期'));
    }
    const subId = `evsub-${studentId}-${taskId}`;
    await client.query(
      `INSERT INTO dtest2.evaluation_submissions (submission_id, task_id, student_id, answers_json, submitted_at)
       VALUES ($1, $2, $3, $4::jsonb, now())
       ON CONFLICT (task_id, student_id) DO UPDATE SET answers_json=EXCLUDED.answers_json, submitted_at=now()`,
      [subId, taskId, studentId, JSON.stringify(answers)]
    );
    await client.query(
      `UPDATE dtest2.evaluation_tasks SET status='submitted', submitted_at=now() WHERE task_id=$1`, [taskId]
    );
    await client.query('COMMIT');
    res.json(ok({ submitted: true }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '提交评教失败', e);
  } finally {
    client.release();
  }
});

// ---- 实践项目列表 ----
app.get('/api/practice', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const category = req.query.category ? String(req.query.category) : null;
  try {
    const r = await pool.query(
      `${PRACTICE_SELECT} WHERE ($2::text IS NULL OR p.category = $2) ORDER BY p.created_at DESC`,
      [studentId, category]
    );
    res.json(ok(r.rows.map(mapPractice)));
  } catch (e) {
    serverError(res, '查询实践失败', e);
  }
});

// ---- 实践项目详情 ----
app.get('/api/practice/:id', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  try {
    const r = await pool.query(`${PRACTICE_SELECT} WHERE p.project_id = $2 LIMIT 1`, [studentId, req.params.id]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('实践项目不存在'));
    }
    res.json(ok(mapPractice(r.rows[0])));
  } catch (e) {
    serverError(res, '查询实践详情失败', e);
  }
});

// ---- 实践报名 ----
app.post('/api/practice/:id/signup', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const projectId = req.params.id;
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // FOR UPDATE 锁定项目行：序列化同一项目的并发报名，使下方 COUNT 名额校验与 INSERT 原子化，杜绝超名额。
    const proj = await client.query(`SELECT slots_total FROM dtest2.practice_projects WHERE project_id=$1 FOR UPDATE`, [projectId]);
    if (proj.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('实践项目不存在'));
    }
    const existing = await client.query(
      `SELECT status FROM dtest2.practice_signups WHERE project_id=$1 AND student_id=$2`, [projectId, studentId]
    );
    if (existing.rowCount > 0 && existing.rows[0].status === 'signedUp') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('您已报名该项目'));
    }
    const cnt = await client.query(
      `SELECT COUNT(*)::int AS n FROM dtest2.practice_signups WHERE project_id=$1 AND status='signedUp'`, [projectId]
    );
    if (cnt.rows[0].n >= proj.rows[0].slots_total) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('该项目名额已满'));
    }
    await client.query(
      `INSERT INTO dtest2.practice_signups (project_id, student_id, status, signed_at, cancelled_at)
       VALUES ($1, $2, 'signedUp', now(), NULL)
       ON CONFLICT (project_id, student_id) DO UPDATE SET status='signedUp', signed_at=now(), cancelled_at=NULL`,
      [projectId, studentId]
    );
    await client.query('COMMIT');
    const updated = await pool.query(`${PRACTICE_SELECT} WHERE p.project_id = $2 LIMIT 1`, [studentId, projectId]);
    res.json(ok(mapPractice(updated.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '报名失败', e);
  } finally {
    client.release();
  }
});

// ---- 实践取消报名 ----
app.delete('/api/practice/:id/signup', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const projectId = req.params.id;
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const upd = await pool.query(
      `UPDATE dtest2.practice_signups SET status='cancelled', cancelled_at=now()
       WHERE project_id=$1 AND student_id=$2 AND status='signedUp'`,
      [projectId, studentId]
    );
    if (upd.rowCount === 0) {
      return res.status(404).json(fail('您尚未报名该项目'));
    }
    const updated = await pool.query(`${PRACTICE_SELECT} WHERE p.project_id = $2 LIMIT 1`, [studentId, projectId]);
    res.json(ok(mapPractice(updated.rows[0])));
  } catch (e) {
    serverError(res, '取消报名失败', e);
  }
});

// ================= 管理端域（需 role=admin + 细粒度权限）=================
// permissionRequired 细粒度鉴权中间件工厂已抽到 ./middleware/permission

// ---- 学生管理（列表）----
app.get('/api/admin/students', permissionRequired('students.manage:view'), async (req, res) => {
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
app.get('/api/admin/grades', permissionRequired('grades.approve:view', 'grades.input:view'), async (req, res) => {
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
app.post('/api/admin/grades/:id/input', permissionRequired('grades.input:update', 'grades.input:create'), async (req, res) => {
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
app.post('/api/admin/grades/:id/approve', permissionRequired('grades.approve:approve'), async (req, res) => {
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
app.post('/api/admin/grades/:id/reject', permissionRequired('grades.approve:approve'), async (req, res) => {
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
app.get('/api/admin/approvals', permissionRequired('approvals.handle:view'), async (req, res) => {
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
app.post('/api/admin/approvals/:id/approve', permissionRequired('approvals.handle:approve'), async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写审批意见'));
  }
  await handleApproval(req, res, 'approved', comment);
});

// ---- 审批驳回 ----
app.post('/api/admin/approvals/:id/reject', permissionRequired('approvals.handle:approve'), async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写驳回意见'));
  }
  await handleApproval(req, res, 'rejected', comment);
});

// ---- 通知发布 ----
const NOTICE_URGENCIES = ['normal', 'important', 'urgent'];
const NOTICE_RECEIVER_TYPES = ['all', 'students', 'teachers', 'custom'];
app.post('/api/admin/notices', permissionRequired('notices.publish:publish', 'notices.publish:create'), async (req, res) => {
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
app.get('/api/admin/roles', permissionRequired('roles.manage:view'), async (req, res) => {
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
app.get('/api/admin/audit-logs', permissionRequired('audit.view:view'), async (req, res) => {
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
app.get('/api/admin/eval/templates', permissionRequired('evaluations.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT template_id, name, description, question_count, status FROM dtest2.evaluation_templates ORDER BY created_at DESC`
    );
    res.json(ok(r.rows.map(mapTemplate)));
  } catch (e) {
    serverError(res, '查询问卷模板失败', e);
  }
});

app.post('/api/admin/eval/templates', permissionRequired('evaluations.manage:create'), async (req, res) => {
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

app.put('/api/admin/eval/templates/:id', permissionRequired('evaluations.manage:update'), async (req, res) => {
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

app.delete('/api/admin/eval/templates/:id', permissionRequired('evaluations.manage:delete'), async (req, res) => {
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

const PORT = parseInt(process.env.PORT || '8090', 10);
// 仅当作为主模块（node src/index.js / pm2）运行时才监听端口；
// 被测试 require 时不监听，便于 supertest 直接挂载 app。
if (require.main === module) {
  app.listen(PORT, () => console.log(`[dtest2-api] listening on :${PORT}`));
}

// 导出供测试：app 用于 supertest，纯函数用于规则单测。
module.exports = app;
module.exports.parseCourseWeeks = parseCourseWeeks;
module.exports.coursesConflict = coursesConflict;
