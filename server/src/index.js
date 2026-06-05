// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { ok, fail } = require('./envelope');
const { verifyPassword, hashBcrypt, isBcryptHash } = require('./hash');
const { signToken, authRequired, adminRequired } = require('./auth');
const { sendVerificationCode } = require('./email');
const codeStore = require('./codeStore');
const {
  deriveTimeText, parseCourseWeeks, coursesConflict, mapCourse, COURSE_COLUMNS, SELECTED_COUNT_JOIN,
  mapNotice, mapLeave, mapFeedback, mapEval, mapPractice, PRACTICE_SELECT,
  leaveTypeLabel, mapStudent, mapGradeTask, mapApproval, mapAuditLog, mapTemplate
} = require('./mappers');
const { globalLimiter, authLimiter } = require('./middleware/rateLimit');
const { serverError } = require('./middleware/errorHandler');
const { fetchStudentProfile, fetchAdminProfile } = require('./repositories/profile.repo');

const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

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

// P0-01 越权防护：当前学生身份一律取自 JWT（登录账号即学号，token.sub=account_id=student_id），
// 不再信任客户端 query/body 传入的 studentId，杜绝 IDOR 水平越权。
function currentStudentId(req) {
  return (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
}

// ---- 健康检查 ----
app.get('/health', async (req, res) => {
  try {
    const r = await pool.query('SELECT now() AS now');
    res.json(ok({ db: 'ok', now: r.rows[0].now }));
  } catch (e) {
    serverError(res, '数据库连接失败', e);
  }
});

// ---- 登录 ----
app.post('/api/auth/login', authLimiter, async (req, res) => {
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
    const passOk = await verifyPassword(password, a.salt, a.password_hash);
    if (!passOk) {
      return res.status(401).json(fail('账号或密码错误'));
    }
    // P2-01 收尾：旧 SHA-256 账号登录成功后惰性升级为 bcrypt（失败不影响本次登录）
    if (!isBcryptHash(a.password_hash)) {
      try {
        const upgraded = await hashBcrypt(password);
        await pool.query('UPDATE dtest2.accounts SET password_hash=$2, salt=$3, updated_at=now() WHERE account_id=$1', [a.account_id, upgraded, '']);
      } catch (e) { /* 迁移失败忽略，下次登录再试 */ }
    }
    const token = signToken({ sub: a.account_id, role: a.role });
    // P1-03：随登录下发真实 profile（取不到则置 null，前端回退本地兜底）
    let profile = null;
    if (a.role === 'student') {
      profile = await fetchStudentProfile(a.account_id);
    } else if (a.role === 'admin') {
      profile = await fetchAdminProfile(a.account_id);
    }
    res.json(ok({ token, accountId: a.account_id, role: a.role, profile }));
  } catch (e) {
    serverError(res, '登录失败', e);
  }
});

// ---- 发送邮箱验证码（公开，无需登录）----
app.post('/api/auth/email-code', authLimiter, async (req, res) => {
  const email = ((req.body && req.body.email) || '').trim();
  if (!EMAIL_RE.test(email)) {
    return res.status(400).json(fail('邮箱格式不正确'));
  }
  const gate = codeStore.canIssue(email);
  if (!gate.ok) {
    const wait = Math.ceil(gate.waitMs / 1000);
    return res.status(429).json(fail(`请求过于频繁，请 ${wait} 秒后再试`));
  }
  const code = codeStore.issue(email);
  try {
    await sendVerificationCode(email, code);
    res.json(ok({ sent: true, ttl: 300 }));
  } catch (e) {
    serverError(res, '邮件发送失败', e);
  }
});

// ---- 校验邮箱验证码（公开，无需登录；成功即消费）----
app.post('/api/auth/verify-email-code', authLimiter, (req, res) => {
  const email = ((req.body && req.body.email) || '').trim();
  const code = ((req.body && req.body.code) || '').trim();
  if (!EMAIL_RE.test(email) || !code) {
    return res.status(400).json(fail('邮箱或验证码不能为空'));
  }
  const result = codeStore.verify(email, code);
  if (!result.ok) {
    return res.status(400).json(fail(result.reason));
  }
  res.json(ok({ valid: true }));
});

// ---- 注册（公开）：校验邮箱验证码 + 建账号 + 建学生资料（重复学号拒绝）----
// P1-01：注册真正落库（accounts + student_profiles）。注册仅收集 学号/姓名/邮箱，
// student_profiles 其余 NOT NULL 字段先占位「待完善」，由学生登录后在「编辑资料」补全。
app.post('/api/auth/register', authLimiter, async (req, res) => {
  const b = req.body || {};
  const studentId = ((b.studentId) || '').trim();
  const name = ((b.name) || '').trim();
  const email = ((b.email) || '').trim();
  const code = ((b.emailCode) || '').trim();
  const password = (b.password) || '';
  if (!studentId || !name || !EMAIL_RE.test(email) || !code || !password) {
    return res.status(400).json(fail('注册信息不完整'));
  }
  if (password.length < 6) {
    return res.status(400).json(fail('密码至少 6 位'));
  }
  const v = codeStore.verify(email, code);
  if (!v.ok) {
    return res.status(400).json(fail(v.reason));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exists = await client.query('SELECT 1 FROM dtest2.accounts WHERE account_id=$1', [studentId]);
    if (exists.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('该学号已注册'));
    }
    const passwordHash = await hashBcrypt(password);
    await client.query(
      `INSERT INTO dtest2.accounts (account_id, role, password_hash, salt, status) VALUES ($1,'student',$2,$3,'active')`,
      [studentId, passwordHash, '']
    );
    await client.query(
      `INSERT INTO dtest2.student_profiles (student_id, name, college, major, class_name, grade, email)
       VALUES ($1,$2,'待完善','待完善','待完善','待完善',$3)
       ON CONFLICT (student_id) DO UPDATE SET name=EXCLUDED.name, email=EXCLUDED.email`,
      [studentId, name, email]
    );
    await client.query('COMMIT');
    res.json(ok({ registered: true, accountId: studentId }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '注册失败', e);
  } finally {
    client.release();
  }
});

// ---- 找回密码（公开）：账号须存在且邮箱与绑定邮箱一致，仅重置不建号 ----
// P1-02：堵掉「找回密码可建任意账号」——账号不存在直接 404，邮箱不匹配 403。
app.post('/api/auth/reset-password', authLimiter, async (req, res) => {
  const b = req.body || {};
  const account = ((b.account) || '').trim();
  const email = ((b.contact) || b.email || '').trim();
  const code = ((b.verifyCode) || b.code || '').trim();
  const newPassword = (b.newPassword) || '';
  if (!account || !EMAIL_RE.test(email) || !code || !newPassword) {
    return res.status(400).json(fail('找回密码信息不完整'));
  }
  if (newPassword.length < 6) {
    return res.status(400).json(fail('密码至少 6 位'));
  }
  try {
    const acc = await pool.query('SELECT account_id, role FROM dtest2.accounts WHERE account_id=$1', [account]);
    if (acc.rowCount === 0) {
      return res.status(404).json(fail('账号不存在'));
    }
    if (acc.rows[0].role !== 'student') {
      return res.status(403).json(fail('该账号不支持邮箱找回密码'));
    }
    const prof = await pool.query('SELECT email FROM dtest2.student_profiles WHERE student_id=$1', [account]);
    const boundEmail = (prof.rowCount > 0 ? (prof.rows[0].email || '') : '').trim().toLowerCase();
    if (!boundEmail || boundEmail !== email.toLowerCase()) {
      return res.status(403).json(fail('邮箱与账号不匹配'));
    }
    // 账号/邮箱校验通过后再消费验证码，避免无谓消费
    const v = codeStore.verify(email, code);
    if (!v.ok) {
      return res.status(400).json(fail(v.reason));
    }
    const passwordHash = await hashBcrypt(newPassword);
    await pool.query(
      'UPDATE dtest2.accounts SET password_hash=$2, salt=$3, updated_at=now() WHERE account_id=$1',
      [account, passwordHash, '']
    );
    res.json(ok({ reset: true }));
  } catch (e) {
    serverError(res, '重置密码失败', e);
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
    serverError(res, '查询课程失败', e);
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
    serverError(res, '查询轮次失败', e);
  }
});

// ---- 我的已选课程 ----
app.get('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '查询选课失败', e);
  }
});

// ---- 选课（事务：轮次 / 容量 / 重复 校验）----
app.post('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const courseId = ((req.body && req.body.courseId) || '').trim();
  if (!studentId || !courseId) {
    return res.status(400).json(fail('缺少 studentId 或 courseId'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const round = await client.query(
      `SELECT round_id, credit_limit FROM dtest2.selection_rounds WHERE status='running' ORDER BY start_time DESC LIMIT 1`
    );
    if (round.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前不在选课时间，暂不能选课'));
    }
    const roundId = round.rows[0].round_id;
    const creditLimit = Number(round.rows[0].credit_limit);
    // FOR UPDATE 锁定课程行：序列化同一课程的并发选课，使下方 COUNT 容量校验与 INSERT 原子化，杜绝超容量。
    const course = await client.query(
      `SELECT capacity, status, credit, weekday, period_start, period_end, weeks_text
         FROM dtest2.courses WHERE course_id=$1 FOR UPDATE`, [courseId]
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
    // 学分上限 + 时间冲突：后端为单一事实来源，基于当前轮次已选课程做权威校验（前端提示仅作辅助）。
    const targetCourse = course.rows[0];
    const selected = await client.query(
      `SELECT c.name, c.credit, c.weekday, c.period_start, c.period_end, c.weeks_text
         FROM dtest2.selections s
         JOIN dtest2.courses c ON c.course_id = s.course_id
        WHERE s.student_id=$1 AND s.round_id=$2 AND s.status='selected'`,
      [studentId, roundId]
    );
    let selectedCredits = 0;
    for (const row of selected.rows) {
      selectedCredits += Number(row.credit);
    }
    if (selectedCredits + Number(targetCourse.credit) > creditLimit) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail(`超过学分上限（${creditLimit} 学分）`));
    }
    for (const row of selected.rows) {
      if (coursesConflict(targetCourse, row)) {
        await client.query('ROLLBACK');
        return res.status(409).json(fail(`与「${row.name}」时间冲突`));
      }
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
    serverError(res, '选课失败', e);
  } finally {
    client.release();
  }
});

// ---- 退课（软删除 status=dropped）----
app.delete('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '退课失败', e);
  }
});

// ---- 成绩（当前学生已发布成绩）----
app.get('/api/grades', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '查询成绩失败', e);
  }
});

// ---- 通知列表 ----
app.get('/api/notices', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '查询通知失败', e);
  }
});

// ---- 通知详情 ----
app.get('/api/notices/:id', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '查询通知失败', e);
  }
});

// ---- 通知标记已读 ----
app.post('/api/notices/:id/read', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '标记已读失败', e);
  }
});

// ---- 我的请假 ----
app.get('/api/leave', authRequired, async (req, res) => {
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
app.post('/api/leave', authRequired, async (req, res) => {
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

// ---- 反馈 ----
app.get('/api/feedback', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
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
    serverError(res, '查询反馈失败', e);
  }
});

const FEEDBACK_CATEGORIES = ['bug', 'suggestion', 'service', 'other'];
app.post('/api/feedback', authRequired, async (req, res) => {
  const b = req.body || {};
  const studentId = currentStudentId(req);
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
    serverError(res, '提交反馈失败', e);
  }
});

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

// P0-02 细粒度鉴权：在 adminRequired（登录态 + role=admin）基础上，再校验当前管理员
// 所属角色是否拥有指定权限码。权限只从数据库读取（admin_profiles.role_id → role_permissions），
// 不写入 token，避免前端伪造。keys 为 'code:action' 列表，命中任意一个即放行（fail-closed）。
function permissionRequired(...keys) {
  return (req, res, next) => {
    adminRequired(req, res, async () => {
      const adminId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
      try {
        const r = await pool.query(
          `SELECT 1 FROM dtest2.admin_profiles ap
             JOIN dtest2.role_permissions rp ON rp.role_id = ap.role_id
            WHERE ap.admin_id = $1
              AND (rp.code || ':' || rp.action) = ANY($2::text[])
            LIMIT 1`,
          [adminId, keys]
        );
        if (r.rowCount === 0) {
          return res.status(403).json(fail('权限不足，需要相应管理权限', 'forbidden'));
        }
        next();
      } catch (e) {
        return serverError(res, '权限校验失败', e, 'server_error');
      }
    });
  };
}

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
