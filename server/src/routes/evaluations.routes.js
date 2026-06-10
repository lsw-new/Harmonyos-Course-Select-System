// 评教域路由：评教任务列表 / 评教提交（事务：校验开放期 + 落答卷 + 任务置 submitted）。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapEval } = require('../mappers');

const router = express.Router();

// ---- 评教任务 ----
router.get('/api/evaluations', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  try {
    // 课程信息优先取选课目录，目录没有的班级课表课程回退 course_teachers / class_schedule_items
    const r = await pool.query(
      `SELECT et.task_id, et.term, et.teacher_name, et.status, et.open_time, et.close_time,
              COALESCE(c.code, et.course_id, '') AS code,
              COALESCE(c.name, ct.course_name, '') AS name,
              COALESCE(c.category, csi.course_type, '') AS category,
              COALESCE(tpl.name, '') AS questionnaire_name
       FROM dtest2.evaluation_tasks et
       LEFT JOIN dtest2.courses c ON c.course_id = et.course_id
       LEFT JOIN dtest2.course_teachers ct ON ct.course_id = et.course_id
       LEFT JOIN LATERAL (
         SELECT course_type FROM dtest2.class_schedule_items
         WHERE course_id = et.course_id LIMIT 1
       ) csi ON true
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
router.post('/api/evaluations/:taskId/submit', authRequired, async (req, res) => {
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

module.exports = router;
