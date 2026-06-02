// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { ok, fail } = require('./envelope');
const { verifyPassword } = require('./hash');
const { signToken, authRequired } = require('./auth');

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

const PORT = parseInt(process.env.PORT || '8090', 10);
app.listen(PORT, () => console.log(`[dtest2-api] listening on :${PORT}`));
