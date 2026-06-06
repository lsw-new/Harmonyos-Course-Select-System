// 实践域路由：实践项目列表 / 详情 / 报名（事务+行锁防超名额）/ 取消报名。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapPractice, PRACTICE_SELECT } = require('../mappers');

const router = express.Router();

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

module.exports = router;
