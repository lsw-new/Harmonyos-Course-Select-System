// 成绩申诉域路由：学生对某次成绩任务提交申诉 / 管理端列表 + 受理/驳回。
// 受理时联动 grade_tasks.status（条件允许则置 'appealed'，允许成绩重新录入）。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { permissionRequired } = require('../middleware/permission');
const { serverError, pgClientError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { genId } = require('../ids');

const router = express.Router();

// 申诉行 → camelCase 信封对象。
function mapAppeal(row) {
  return {
    appealId: row.appeal_id,
    studentId: row.student_id,
    studentName: row.student_name === undefined ? undefined : (row.student_name || ''),
    taskId: row.task_id || '',
    courseId: row.course_id || '',
    term: row.term || '',
    reason: row.reason,
    status: row.status,
    reply: row.reply || '',
    handledBy: row.handled_by || '',
    handledAt: row.handled_at || null,
    submittedAt: row.submitted_at,
    updatedAt: row.updated_at
  };
}

// ---- 学生提交成绩申诉（按成绩行 grade_id，学生端 GET /api/grades 返回的 id 即 grade_id）----
router.post('/api/grades/:gradeId/appeal', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const gradeId = ((req.params.gradeId) || '').trim();
  const reason = (((req.body || {}).reason) || '').trim();
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  if (!reason) {
    return res.status(400).json(fail('申诉理由不能为空'));
  }
  if (reason.length > 500) {
    return res.status(400).json(fail('申诉理由不能超过 500 字'));
  }
  try {
    // 按 grade_id + 学号定位成绩行（防越权 / 给不存在的成绩申诉），并取出 task_id/course/term。
    const g = await pool.query(
      `SELECT g.task_id, g.course_id, g.term
       FROM dtest2.grades g
       WHERE g.grade_id = $1 AND g.student_id = $2
       LIMIT 1`,
      [gradeId, studentId]
    );
    if (g.rowCount === 0) {
      return res.status(404).json(fail('未找到该成绩记录'));
    }
    const taskId = g.rows[0].task_id;
    // 同一 task+student 已有 pending 申诉 → 409（避免重复申诉）。
    const dup = await pool.query(
      `SELECT 1 FROM dtest2.grade_appeals
       WHERE task_id = $1 AND student_id = $2 AND status = 'pending' LIMIT 1`,
      [taskId, studentId]
    );
    if (dup.rowCount > 0) {
      return res.status(409).json(fail('该成绩已有待处理的申诉'));
    }
    const appealId = genId('ga');
    const r = await pool.query(
      `INSERT INTO dtest2.grade_appeals
        (appeal_id, student_id, task_id, course_id, term, reason, status, submitted_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending', now(), now())
       RETURNING appeal_id, student_id, task_id, course_id, term, reason, status, reply,
                 handled_by, handled_at, submitted_at, updated_at`,
      [appealId, studentId, taskId, g.rows[0].course_id, g.rows[0].term, reason]
    );
    res.json(ok(mapAppeal(r.rows[0])));
  } catch (e) {
    pgClientError(res, '提交成绩申诉失败', e);
  }
});

// ---- 管理端：申诉列表（可选 ?status= 过滤）----
router.get('/api/admin/grade-appeals', permissionRequired('grades.approve:approve', 'grades.approve:view'), async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT ga.appeal_id, ga.student_id, ga.task_id, ga.course_id, ga.term, ga.reason,
              ga.status, ga.reply, ga.handled_by, ga.handled_at, ga.submitted_at, ga.updated_at,
              COALESCE(sp.name, '') AS student_name
       FROM dtest2.grade_appeals ga
       LEFT JOIN dtest2.student_profiles sp ON sp.student_id = ga.student_id
       WHERE ($1::text IS NULL OR ga.status = $1)
       ORDER BY ga.submitted_at DESC LIMIT 100`,
      [status]
    );
    res.json(ok(r.rows.map(mapAppeal)));
  } catch (e) {
    serverError(res, '查询成绩申诉失败', e);
  }
});

// ---- 管理端：受理/驳回申诉（事务内行锁，pending→accepted/rejected）----
// 受理（accepted）时，若对应 grade_tasks 处于 published 则置 'appealed'（允许重新录入）；
// 状态机不允许（如已是 appealed/inputting）则跳过，不报错。
const APPEAL_DECISIONS = ['accepted', 'rejected'];
router.post('/api/admin/grade-appeals/:id/handle', permissionRequired('grades.approve:approve', 'grades.approve:view'), async (req, res) => {
  const appealId = ((req.params.id) || '').trim();
  const b = req.body || {};
  const decision = ((b.decision) || '').trim();
  const reply = typeof b.reply === 'string' ? b.reply.trim() : '';
  if (APPEAL_DECISIONS.indexOf(decision) < 0) {
    return res.status(400).json(fail('处理结果不合法'));
  }
  const adminId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(
      `SELECT status, task_id FROM dtest2.grade_appeals WHERE appeal_id = $1 FOR UPDATE`,
      [appealId]
    );
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('申诉记录不存在'));
    }
    if (cur.rows[0].status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('该申诉已处理'));
    }
    const r = await client.query(
      `UPDATE dtest2.grade_appeals
       SET status = $2, reply = $3, handled_by = $4, handled_at = now(), updated_at = now()
       WHERE appeal_id = $1
       RETURNING appeal_id, student_id, task_id, course_id, term, reason, status, reply,
                 handled_by, handled_at, submitted_at, updated_at`,
      [appealId, decision, reply, adminId]
    );
    // 受理后联动成绩任务：仅当任务存在且当前为 published 时置 appealed（允许重新录入）；
    // 其它状态不满足状态机则跳过，不报错。
    if (decision === 'accepted' && cur.rows[0].task_id) {
      await client.query(
        `UPDATE dtest2.grade_tasks SET status = 'appealed', updated_at = now()
         WHERE task_id = $1 AND status = 'published'`,
        [cur.rows[0].task_id]
      );
    }
    await client.query('COMMIT');
    res.json(ok(mapAppeal(r.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '处理成绩申诉失败', e);
  } finally {
    client.release();
  }
});

module.exports = router;
