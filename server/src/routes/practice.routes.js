// 实践域路由：实践项目列表 / 详情 / 报名（事务+行锁防超名额）/ 取消报名。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { permissionRequired } = require('../middleware/permission');
const { serverError, pgClientError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { genId } = require('../ids');
const { mapPractice, PRACTICE_SELECT } = require('../mappers');

const router = express.Router();

// 实践提交行 → camelCase 信封对象。student_name/project_title 仅在管理端 JOIN 时出现。
function mapSubmission(row) {
  return {
    submissionId: row.submission_id,
    projectId: row.project_id,
    studentId: row.student_id,
    studentName: row.student_name === undefined ? undefined : (row.student_name || ''),
    projectTitle: row.project_title === undefined ? undefined : (row.project_title || ''),
    content: row.content || '',
    attachments: Array.isArray(row.attachments) ? row.attachments : [],
    status: row.status,
    score: row.score === null || row.score === undefined ? null : Number(row.score),
    feedback: row.feedback || '',
    scoredBy: row.scored_by || '',
    scoredAt: row.scored_at || null,
    submittedAt: row.submitted_at,
    updatedAt: row.updated_at
  };
}

const SUBMISSION_STATUSES = ['scored', 'passed', 'rejected'];

// ---- 实践项目列表 ----
router.get('/api/practice', authRequired, async (req, res) => {
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
router.get('/api/practice/:id', authRequired, async (req, res) => {
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
router.post('/api/practice/:id/signup', authRequired, async (req, res) => {
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
    // COMMIT 后用同一 client（仍持有至 finally release）读回，避免事务块内混用 pool 另取连接
    const updated = await client.query(`${PRACTICE_SELECT} WHERE p.project_id = $2 LIMIT 1`, [studentId, projectId]);
    res.json(ok(mapPractice(updated.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '报名失败', e);
  } finally {
    client.release();
  }
});

// ---- 实践取消报名 ----
router.delete('/api/practice/:id/signup', authRequired, async (req, res) => {
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

// ---- 学生提交实践成果/报告 ----
// 必须已报名（practice_signups.status='signedUp'）该项目，否则 403（防越权给未报名项目提交）。
// 单个项目+学生仅保留一条提交：重复提交按 upsert 覆盖 content/attachments 并将状态重置为 submitted。
router.post('/api/practice/:id/submit', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const projectId = req.params.id;
  const body = req.body || {};
  const content = typeof body.content === 'string' ? body.content.trim() : '';
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  if (!content) {
    return res.status(400).json(fail('提交内容不能为空'));
  }
  if (content.length > 5000) {
    return res.status(400).json(fail('提交内容不能超过 5000 字'));
  }
  try {
    // 校验已报名：仅 signedUp 视为有效报名（cancelled 不可提交）。
    const su = await pool.query(
      `SELECT 1 FROM dtest2.practice_signups
       WHERE project_id = $1 AND student_id = $2 AND status = 'signedUp' LIMIT 1`,
      [projectId, studentId]
    );
    if (su.rowCount === 0) {
      return res.status(403).json(fail('您尚未报名该实践项目，无法提交'));
    }
    // upsert：已有提交（同项目+学生）则覆盖内容/附件并重置为 submitted、清空打分。
    const existing = await pool.query(
      `SELECT submission_id FROM dtest2.practice_submissions
       WHERE project_id = $1 AND student_id = $2 LIMIT 1`,
      [projectId, studentId]
    );
    let r;
    if (existing.rowCount > 0) {
      r = await pool.query(
        `UPDATE dtest2.practice_submissions
         SET content = $2, attachments = $3::jsonb, status = 'submitted',
             score = NULL, feedback = NULL, scored_by = NULL, scored_at = NULL,
             submitted_at = now(), updated_at = now()
         WHERE submission_id = $1
         RETURNING submission_id, project_id, student_id, content, attachments, status,
                   score, feedback, scored_by, scored_at, submitted_at, updated_at`,
        [existing.rows[0].submission_id, content, JSON.stringify(attachments)]
      );
    } else {
      const submissionId = genId('ps');
      r = await pool.query(
        `INSERT INTO dtest2.practice_submissions
          (submission_id, project_id, student_id, content, attachments, status, submitted_at, updated_at)
         VALUES ($1, $2, $3, $4, $5::jsonb, 'submitted', now(), now())
         RETURNING submission_id, project_id, student_id, content, attachments, status,
                   score, feedback, scored_by, scored_at, submitted_at, updated_at`,
        [submissionId, projectId, studentId, content, JSON.stringify(attachments)]
      );
    }
    res.json(ok(mapSubmission(r.rows[0])));
  } catch (e) {
    pgClientError(res, '提交实践成果失败', e);
  }
});

// ---- 学生查看本人对某项目的提交（无则返回 null，供 App 展示状态）----
router.get('/api/practice/:id/submission', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const projectId = req.params.id;
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT submission_id, project_id, student_id, content, attachments, status,
              score, feedback, scored_by, scored_at, submitted_at, updated_at
       FROM dtest2.practice_submissions
       WHERE project_id = $1 AND student_id = $2 LIMIT 1`,
      [projectId, studentId]
    );
    res.json(ok(r.rowCount === 0 ? null : mapSubmission(r.rows[0])));
  } catch (e) {
    serverError(res, '查询实践提交失败', e);
  }
});

// ---- 管理端：实践提交列表（可选 ?status= / ?projectId= 过滤）----
// 权限：实践项目即 courses（category='practice'）的一类，复用课程管理权限 courses.manage。
router.get('/api/admin/practice-submissions', permissionRequired('courses.manage:view', 'courses.manage:update'), async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  const projectId = req.query.projectId ? String(req.query.projectId) : null;
  try {
    const r = await pool.query(
      `SELECT ps.submission_id, ps.project_id, ps.student_id, ps.content, ps.attachments,
              ps.status, ps.score, ps.feedback, ps.scored_by, ps.scored_at,
              ps.submitted_at, ps.updated_at,
              COALESCE(sp.name, '') AS student_name,
              COALESCE(pp.title, '') AS project_title
       FROM dtest2.practice_submissions ps
       LEFT JOIN dtest2.student_profiles sp ON sp.student_id = ps.student_id
       LEFT JOIN dtest2.practice_projects pp ON pp.project_id = ps.project_id
       WHERE ($1::text IS NULL OR ps.status = $1)
         AND ($2::text IS NULL OR ps.project_id = $2)
       ORDER BY ps.submitted_at DESC LIMIT 100`,
      [status, projectId]
    );
    res.json(ok(r.rows.map(mapSubmission)));
  } catch (e) {
    serverError(res, '查询实践提交失败', e);
  }
});

// ---- 管理端：打分/认定（事务内行锁，status ∈ scored/passed/rejected）----
router.post('/api/admin/practice-submissions/:id/score', permissionRequired('courses.manage:update'), async (req, res) => {
  const submissionId = ((req.params.id) || '').trim();
  const b = req.body || {};
  const status = ((b.status) || '').trim();
  const feedback = typeof b.feedback === 'string' ? b.feedback.trim() : '';
  if (SUBMISSION_STATUSES.indexOf(status) < 0) {
    return res.status(400).json(fail('打分状态不合法'));
  }
  let score = null;
  if (b.score !== undefined && b.score !== null && b.score !== '') {
    const n = Number(b.score);
    if (!Number.isFinite(n) || n < 0 || n > 100) {
      return res.status(400).json(fail('分数应为 0-100 之间的数值'));
    }
    score = n;
  }
  const adminId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(
      `SELECT submission_id FROM dtest2.practice_submissions WHERE submission_id = $1 FOR UPDATE`,
      [submissionId]
    );
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('提交记录不存在'));
    }
    const r = await client.query(
      `UPDATE dtest2.practice_submissions
       SET status = $2, score = $3, feedback = $4, scored_by = $5, scored_at = now(), updated_at = now()
       WHERE submission_id = $1
       RETURNING submission_id, project_id, student_id, content, attachments, status,
                 score, feedback, scored_by, scored_at, submitted_at, updated_at`,
      [submissionId, status, score, feedback, adminId]
    );
    await client.query('COMMIT');
    res.json(ok(mapSubmission(r.rows[0])));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    pgClientError(res, '实践打分失败', e);
  } finally {
    client.release();
  }
});

module.exports = router;
