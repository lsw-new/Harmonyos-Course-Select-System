// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { ok, fail } = require('./envelope');
const { verifyPassword } = require('./hash');
const { signToken, authRequired, adminRequired } = require('./auth');

const app = express();
app.use(cors());
app.use(express.json());

const WEEKDAY_CN = ['', '一', '二', '三', '四', '五', '六', '日'];

function deriveTimeText(row) {
  if (row.weekday && row.period_start && row.period_end) {
    const cn = WEEKDAY_CN[row.weekday] || String(row.weekday);
    return `周${cn} ${row.period_start}-${row.period_end} 节`;
  }
  return row.weeks_text || '';
}

function mapCourse(row) {
  return {
    id: row.course_id,
    code: row.code,
    name: row.name,
    teacher: row.teacher,
    category: row.category,
    credit: Number(row.credit),
    timeText: deriveTimeText(row),
    capacity: row.capacity,
    selectedCount: Number(row.selected_count || 0),
    status: row.status
  };
}

const COURSE_COLUMNS =
  `c.course_id, c.code, c.name, c.teacher, c.category, c.credit, c.capacity, c.status,
   c.weekday, c.period_start, c.period_end, c.weeks_text`;
const SELECTED_COUNT_JOIN =
  `LEFT JOIN (SELECT course_id, COUNT(*) cnt FROM dtest2.selections WHERE status='selected' GROUP BY course_id) sc
     ON sc.course_id = c.course_id`;

// ---- 健康检查 ----
app.get('/health', async (req, res) => {
  try {
    const r = await pool.query('SELECT now() AS now');
    res.json(ok({ db: 'ok', now: r.rows[0].now }));
  } catch (e) {
    res.status(500).json(fail('数据库连接失败：' + e.message));
  }
});

// ---- 登录 ----
app.post('/api/auth/login', async (req, res) => {
  const account = ((req.body && req.body.account) || '').trim();
  const password = (req.body && req.body.password) || '';
  if (!account || !password) {
    return res.status(400).json(fail('账号或密码不能为空'));
  }
  try {
    const r = await pool.query(
      'SELECT account_id, role, password_hash, salt, status FROM dtest2.accounts WHERE account_id=$1',
      [account]
    );
    if (r.rowCount === 0) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    const a = r.rows[0];
    if (a.status !== 'active') {
      return res.status(403).json(fail('账号状态异常：' + a.status));
    }
    if (!verifyPassword(password, a.salt, a.password_hash)) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    const token = signToken({ sub: a.account_id, role: a.role });
    res.json(ok({ token, accountId: a.account_id, role: a.role }));
  } catch (e) {
    res.status(500).json(fail('登录失败：' + e.message));
  }
});

// ---- 课程列表（可选 ?status=open）----
app.get('/api/courses', authRequired, async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0) AS selected_count
       FROM dtest2.courses c
       ${SELECTED_COUNT_JOIN}
       WHERE ($1::text IS NULL OR c.status = $1)
       ORDER BY c.created_at DESC`,
      [status]
    );
    res.json(ok(r.rows.map(mapCourse)));
  } catch (e) {
    res.status(500).json(fail('查询课程失败：' + e.message));
  }
});

// ---- 当前进行中的选课轮次 ----
app.get('/api/selection-rounds/active', authRequired, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT round_id, name, status, start_time, end_time, credit_limit
       FROM dtest2.selection_rounds WHERE status='running'
       ORDER BY start_time DESC LIMIT 1`
    );
    if (r.rowCount === 0) {
      return res.json(ok(null));
    }
    const row = r.rows[0];
    res.json(ok({
      id: row.round_id,
      name: row.name,
      status: row.status,
      startTime: row.start_time,
      endTime: row.end_time,
      creditLimit: Number(row.credit_limit)
    }));
  } catch (e) {
    res.status(500).json(fail('查询轮次失败：' + e.message));
  }
});

// ---- 我的已选课程 ----
app.get('/api/selections', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0) AS selected_count
       FROM dtest2.selections s
       JOIN dtest2.courses c ON c.course_id = s.course_id
       ${SELECTED_COUNT_JOIN}
       WHERE s.student_id=$1 AND s.status='selected'
       ORDER BY s.created_at DESC`,
      [studentId]
    );
    res.json(ok(r.rows.map(mapCourse)));
  } catch (e) {
    res.status(500).json(fail('查询选课失败：' + e.message));
  }
});

// ---- 选课（事务：轮次 / 容量 / 重复 校验）----
app.post('/api/selections', authRequired, async (req, res) => {
  const studentId = ((req.body && req.body.studentId) || '').trim();
  const courseId = ((req.body && req.body.courseId) || '').trim();
  if (!studentId || !courseId) {
    return res.status(400).json(fail('缺少 studentId 或 courseId'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const round = await client.query(
      `SELECT round_id FROM dtest2.selection_rounds WHERE status='running' ORDER BY start_time DESC LIMIT 1`
    );
    if (round.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前不在选课时间，暂不能选课'));
    }
    const roundId = round.rows[0].round_id;
    const course = await client.query(
      `SELECT capacity, status FROM dtest2.courses WHERE course_id=$1`, [courseId]
    );
    if (course.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('课程不存在'));
    }
    if (course.rows[0].status !== 'open') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('课程未开放选课'));
    }
    const dup = await client.query(
      `SELECT status FROM dtest2.selections WHERE student_id=$1 AND course_id=$2 AND round_id=$3`,
      [studentId, courseId, roundId]
    );
    if (dup.rowCount > 0 && dup.rows[0].status === 'selected') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('已选该课程'));
    }
    const cnt = await client.query(
      `SELECT COUNT(*)::int AS n FROM dtest2.selections WHERE course_id=$1 AND status='selected'`, [courseId]
    );
    if (cnt.rows[0].n >= course.rows[0].capacity) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('课程容量已满'));
    }
    const selId = `sel-${studentId}-${courseId}-${roundId}`;
    await client.query(
      `INSERT INTO dtest2.selections (selection_id, student_id, course_id, round_id, status, created_at, dropped_at)
       VALUES ($1,$2,$3,$4,'selected',now(),NULL)
       ON CONFLICT (student_id, course_id, round_id)
       DO UPDATE SET status='selected', dropped_at=NULL`,
      [selId, studentId, courseId, roundId]
    );
    await client.query('COMMIT');
    res.json(ok({ selected: true }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    res.status(500).json(fail('选课失败：' + e.message));
  } finally {
    client.release();
  }
});

// ---- 退课（软删除 status=dropped）----
app.delete('/api/selections', authRequired, async (req, res) => {
  const studentId = ((req.body && req.body.studentId) || '').trim();
  const courseId = ((req.body && req.body.courseId) || '').trim();
  if (!studentId || !courseId) {
    return res.status(400).json(fail('缺少 studentId 或 courseId'));
  }
  try {
    const r = await pool.query(
      `UPDATE dtest2.selections SET status='dropped', dropped_at=now()
       WHERE student_id=$1 AND course_id=$2 AND status='selected'`,
      [studentId, courseId]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('该课程未被选中'));
    }
    res.json(ok({ dropped: true }));
  } catch (e) {
    res.status(500).json(fail('退课失败：' + e.message));
  }
});

// ================= 成绩 / 通知 / 请假 扩展域 =================

function mapNotice(row) {
  return {
    id: row.notice_id,
    title: row.title,
    publisher: row.publisher,
    publishedAt: row.published_at,
    summary: row.summary || '',
    content: row.content,
    isRead: row.is_read === true,
    category: row.category,
    attachments: []
  };
}

function mapLeave(row) {
  return {
    id: row.leave_id,
    type: row.type,
    startDate: row.start_date,
    endDate: row.end_date,
    reason: row.reason,
    attachments: [],
    state: row.status,
    submittedAt: row.submitted_at,
    feedback: row.feedback || ''
  };
}

// ---- 成绩（当前学生已发布成绩）----
app.get('/api/grades', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  try {
    const r = await pool.query(
      `SELECT g.grade_id, g.term, g.score, COALESCE(g.grade_point, 0) AS grade_point, COALESCE(g.rank, 0) AS rank, g.published_at,
              COALESCE(c.code, '') AS code, COALESCE(c.teaching_class_no, '') AS teaching_class_no,
              COALESCE(c.name, '') AS name, COALESCE(c.category, '') AS category, COALESCE(c.credit, 0) AS credit
       FROM dtest2.grades g
       LEFT JOIN dtest2.courses c ON c.course_id = g.course_id
       WHERE g.student_id = $1 AND ($2::text IS NULL OR g.term = $2)
       ORDER BY g.published_at DESC`,
      [studentId, term]
    );
    const data = r.rows.map((row) => {
      return {
        id: row.grade_id,
        term: row.term,
        courseCode: row.code,
        teachingClassNo: row.teaching_class_no,
        courseName: row.name,
        courseCategory: row.category,
        credit: Number(row.credit),
        score: Number(row.score),
        gradePoint: Number(row.grade_point),
        rank: Number(row.rank),
        publishedAt: row.published_at
      };
    });
    res.json(ok(data));
  } catch (e) {
    res.status(500).json(fail('查询成绩失败：' + e.message));
  }
});

// ---- 通知列表 ----
app.get('/api/notices', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  const category = req.query.category ? String(req.query.category) : null;
  try {
    const r = await pool.query(
      `SELECT n.notice_id, n.title, n.publisher, n.summary, n.content, n.category, n.published_at,
              CASE WHEN nr.notice_id IS NULL THEN false ELSE true END AS is_read
       FROM dtest2.notices n
       LEFT JOIN dtest2.notice_reads nr ON nr.notice_id = n.notice_id AND nr.student_id = $1
       WHERE ($2::text IS NULL OR n.category = $2)
       ORDER BY n.published_at DESC`,
      [studentId, category]
    );
    res.json(ok(r.rows.map(mapNotice)));
  } catch (e) {
    res.status(500).json(fail('查询通知失败：' + e.message));
  }
});

// ---- 通知详情 ----
app.get('/api/notices/:id', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  try {
    const r = await pool.query(
      `SELECT n.notice_id, n.title, n.publisher, n.summary, n.content, n.category, n.published_at,
              CASE WHEN nr.notice_id IS NULL THEN false ELSE true END AS is_read
       FROM dtest2.notices n
       LEFT JOIN dtest2.notice_reads nr ON nr.notice_id = n.notice_id AND nr.student_id = $1
       WHERE n.notice_id = $2 LIMIT 1`,
      [studentId, req.params.id]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('通知不存在'));
    }
    res.json(ok(mapNotice(r.rows[0])));
  } catch (e) {
    res.status(500).json(fail('查询通知失败：' + e.message));
  }
});

// ---- 通知标记已读 ----
app.post('/api/notices/:id/read', authRequired, async (req, res) => {
  const studentId = ((req.body && req.body.studentId) || '').trim();
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    await pool.query(
      `INSERT INTO dtest2.notice_reads (notice_id, student_id, read_at) VALUES ($1, $2, now())
       ON CONFLICT (notice_id, student_id) DO NOTHING`,
      [req.params.id, studentId]
    );
    res.json(ok({ read: true }));
  } catch (e) {
    res.status(500).json(fail('标记已读失败：' + e.message));
  }
});

// ---- 我的请假 ----
app.get('/api/leave', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
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
    res.status(500).json(fail('查询请假失败：' + e.message));
  }
});

// ---- 提交请假（事务内同步创建审批实例，leave -> approval 闭环）----
const LEAVE_TYPES = ['sick', 'personal', 'public', 'other'];
app.post('/api/leave', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = ((b.studentId) || '').trim();
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
    res.status(500).json(fail('提交请假失败：' + e.message));
  } finally {
    client.release();
  }
});

// ================= 反馈 / 评教 / 实践 扩展域 =================

function mapFeedback(row) {
  return {
    id: row.feedback_id,
    category: row.category,
    title: row.title,
    content: row.content,
    contact: row.contact || '',
    screenshots: [],
    submittedAt: row.submitted_at,
    state: row.state
  };
}

function mapEval(row) {
  return {
    id: row.task_id,
    term: row.term,
    courseCode: row.code || '',
    courseName: row.name || '',
    courseCategory: row.category || '',
    teacherName: row.teacher_name || '',
    questionnaireName: row.questionnaire_name || '教学质量评价问卷',
    status: row.status,
    openTime: row.open_time || '',
    closeTime: row.close_time || ''
  };
}

function mapPractice(row) {
  return {
    id: row.project_id,
    title: row.title,
    org: row.org,
    category: row.category,
    credits: Number(row.credits),
    period: row.period,
    location: row.location || '',
    mentor: row.mentor || '',
    slotsTotal: row.slots_total,
    slotsTaken: Number(row.slots_taken || 0),
    signedUp: row.signed_up === true,
    description: row.description || '',
    requirements: Array.isArray(row.requirements_json) ? row.requirements_json : []
  };
}

const PRACTICE_SELECT =
  `SELECT p.project_id, p.title, p.org, p.category, p.credits, p.period, p.location, p.mentor,
          p.slots_total, p.description, p.requirements_json,
          COALESCE(st.cnt, 0) AS slots_taken,
          CASE WHEN ms.project_id IS NULL THEN false ELSE true END AS signed_up
   FROM dtest2.practice_projects p
   LEFT JOIN (SELECT project_id, COUNT(*) cnt FROM dtest2.practice_signups WHERE status='signedUp' GROUP BY project_id) st
     ON st.project_id = p.project_id
   LEFT JOIN dtest2.practice_signups ms ON ms.project_id = p.project_id AND ms.student_id = $1 AND ms.status='signedUp'`;

// ---- 反馈 ----
app.get('/api/feedback', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
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
    res.status(500).json(fail('查询反馈失败：' + e.message));
  }
});

const FEEDBACK_CATEGORIES = ['bug', 'suggestion', 'service', 'other'];
app.post('/api/feedback', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = ((b.studentId) || '').trim();
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
    res.status(500).json(fail('提交反馈失败：' + e.message));
  }
});

// ---- 评教任务 ----
app.get('/api/evaluations', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
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
    res.status(500).json(fail('查询评教失败：' + e.message));
  }
});

// ---- 评教提交 ----
app.post('/api/evaluations/:taskId/submit', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = ((b.studentId) || '').trim();
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
    res.status(500).json(fail('提交评教失败：' + e.message));
  } finally {
    client.release();
  }
});

// ---- 实践项目列表 ----
app.get('/api/practice', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  const category = req.query.category ? String(req.query.category) : null;
  try {
    const r = await pool.query(
      `${PRACTICE_SELECT} WHERE ($2::text IS NULL OR p.category = $2) ORDER BY p.created_at DESC`,
      [studentId, category]
    );
    res.json(ok(r.rows.map(mapPractice)));
  } catch (e) {
    res.status(500).json(fail('查询实践失败：' + e.message));
  }
});

// ---- 实践项目详情 ----
app.get('/api/practice/:id', authRequired, async (req, res) => {
  const studentId = req.query.studentId ? String(req.query.studentId) : '';
  try {
    const r = await pool.query(`${PRACTICE_SELECT} WHERE p.project_id = $2 LIMIT 1`, [studentId, req.params.id]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('实践项目不存在'));
    }
    res.json(ok(mapPractice(r.rows[0])));
  } catch (e) {
    res.status(500).json(fail('查询实践详情失败：' + e.message));
  }
});

// ---- 实践报名 ----
app.post('/api/practice/:id/signup', authRequired, async (req, res) => {
  const studentId = ((req.body && req.body.studentId) || '').trim();
  const projectId = req.params.id;
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const proj = await client.query(`SELECT slots_total FROM dtest2.practice_projects WHERE project_id=$1`, [projectId]);
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
    res.status(500).json(fail('报名失败：' + e.message));
  } finally {
    client.release();
  }
});

// ---- 实践取消报名 ----
app.delete('/api/practice/:id/signup', authRequired, async (req, res) => {
  const studentId = ((req.body && req.body.studentId) || '').trim();
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
    res.status(500).json(fail('取消报名失败：' + e.message));
  }
});

// ================= 管理端域（需 role=admin）=================

function leaveTypeLabel(type) {
  if (type === 'sick') return '病假';
  if (type === 'personal') return '事假';
  if (type === 'public') return '公假';
  return '其他';
}

function mapStudent(row) {
  return {
    studentId: row.student_id,
    name: row.name,
    college: row.college,
    major: row.major,
    className: row.class_name,
    status: 'active',
    educationLevel: 'undergraduate'
  };
}

function mapGradeTask(row) {
  const item = {
    id: row.task_id,
    courseName: row.course_name || '',
    teachingClassName: row.teaching_class_name,
    teacherName: row.teacher_name,
    inputProgress: row.input_progress,
    status: row.status,
    updatedAt: row.updated_at
  };
  if (row.reject_reason) {
    item.rejectReason = row.reject_reason;
  }
  return item;
}

function mapApproval(row) {
  return {
    id: row.approval_id,
    type: row.biz_type === 'leave' ? '请假' : row.biz_type,
    applicantName: row.applicant_name,
    applicantId: row.applicant_id,
    title: row.title,
    reason: row.reason || '',
    status: row.status,
    isUrgent: row.is_urgent === true,
    submittedAt: row.submitted_at
  };
}

// ---- 学生管理（列表）----
app.get('/api/admin/students', adminRequired, async (req, res) => {
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
    res.status(500).json(fail('查询学生失败：' + e.message));
  }
});

// ---- 成绩审核（列表）----
app.get('/api/admin/grades', adminRequired, async (req, res) => {
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
    res.status(500).json(fail('查询成绩审核失败：' + e.message));
  }
});

// ---- 成绩录入 ----
app.post('/api/admin/grades/:id/input', adminRequired, async (req, res) => {
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
    res.status(500).json(fail('录入成绩失败：' + e.message));
  }
});

// ---- 成绩审核通过 ----
app.post('/api/admin/grades/:id/approve', adminRequired, async (req, res) => {
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
    res.status(500).json(fail('审核成绩失败：' + e.message));
  }
});

// ---- 成绩驳回 ----
app.post('/api/admin/grades/:id/reject', adminRequired, async (req, res) => {
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
    res.status(500).json(fail('驳回成绩失败：' + e.message));
  }
});

// ---- 审批（列表）----
app.get('/api/admin/approvals', adminRequired, async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT approval_id, biz_type, applicant_name, applicant_id, title, COALESCE(reason, '') AS reason, status, is_urgent, submitted_at
       FROM dtest2.approval_instances WHERE ($1::text IS NULL OR status = $1) ORDER BY submitted_at DESC`,
      [status]
    );
    res.json(ok(r.rows.map(mapApproval)));
  } catch (e) {
    res.status(500).json(fail('查询审批失败：' + e.message));
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
    res.status(500).json(fail('审批处理失败：' + e.message));
  } finally {
    client.release();
  }
}

// ---- 审批通过 ----
app.post('/api/admin/approvals/:id/approve', adminRequired, async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写审批意见'));
  }
  await handleApproval(req, res, 'approved', comment);
});

// ---- 审批驳回 ----
app.post('/api/admin/approvals/:id/reject', adminRequired, async (req, res) => {
  const comment = ((req.body || {}).comment || '').trim();
  if (!comment) {
    return res.status(400).json(fail('请填写驳回意见'));
  }
  await handleApproval(req, res, 'rejected', comment);
});

const PORT = parseInt(process.env.PORT || '8090', 10);
app.listen(PORT, () => console.log(`[dtest2-api] listening on :${PORT}`));
