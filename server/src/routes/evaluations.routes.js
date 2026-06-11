// 评教域路由：评教任务列表 / 评教提交（事务：校验开放期 + 落答卷 + 任务置 submitted）。
// 从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');
const { currentStudentId } = require('../identity');
const { mapEval } = require('../mappers');

const router = express.Router();

// 评教期全局开关（system_settings key），无记录时默认开放
const EVAL_PERIOD_KEY = 'eval.period.open';

async function isEvalPeriodOpen() {
  const r = await pool.query(
    `SELECT value_json FROM dtest2.system_settings WHERE key = $1`,
    [EVAL_PERIOD_KEY]
  );
  if (r.rowCount === 0) {
    return true;
  }
  return r.rows[0].value_json === true;
}

// ---- 评教期开关：读（学生/管理员登录即可，学生端入口与提交按钮据此放行）----
router.get('/api/eval-period', authRequired, async (req, res) => {
  try {
    const open = await isEvalPeriodOpen();
    res.json(ok({ open }));
  } catch (e) {
    serverError(res, '查询评教开关失败', e);
  }
});

// ---- 评教期开关：写（仅评教管理权限；管理员打开后学生才能评价）----
router.put('/api/admin/eval-period', permissionRequired('evaluations.manage:update'), async (req, res) => {
  const open = (req.body || {}).open;
  if (typeof open !== 'boolean') {
    return res.status(400).json(fail('open 需为布尔值'));
  }
  try {
    await pool.query(
      `INSERT INTO dtest2.system_settings (key, value_json, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (key) DO UPDATE SET value_json = EXCLUDED.value_json, updated_at = now()`,
      [EVAL_PERIOD_KEY, JSON.stringify(open)]
    );
    res.json(ok({ open }));
  } catch (e) {
    serverError(res, '更新评教开关失败', e);
  }
});

const CURRENT_TERM = '2025-2026-2';

// 评教任务与学生当前课程实时同步（幂等）：当前课程 = 本班课表课程（JOIN courses 守外键）
// ∪ 当前已选课程；缺失任务补齐，不再修读且未提交的 open 任务清理（已提交答卷保留作记录）。
// 目的：管理员打开评教期后，学生「有什么课就评什么课」，不依赖注册时刻的快照。
async function syncTasksWithCourses(studentId) {
  const cls = await pool.query(
    `SELECT COALESCE(
       (SELECT class_name FROM dtest2.class_students WHERE student_id=$1),
       (SELECT class_name FROM dtest2.student_profiles WHERE student_id=$1)
     ) AS class_name`,
    [studentId]
  );
  const className = (cls.rows[0] && cls.rows[0].class_name) || '';
  if (className === '' || className === '待完善') {
    return; // 无法定位班级时不做同步，避免误删
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO dtest2.evaluation_tasks
         (task_id, template_id, student_id, course_id, term, teacher_name, status, open_time, close_time)
       SELECT 'eval-' || cur.course_id || '-' || $1, 'qt-default', $1, cur.course_id, cur.term, cur.teacher, 'open',
              now() - interval '1 day', timestamptz '2026-07-15 23:59:59+08'
       FROM (
         SELECT DISTINCT csi.course_id, csi.term, csi.teacher
           FROM dtest2.class_schedule_items csi
           JOIN dtest2.courses c ON c.course_id = csi.course_id
          WHERE csi.class_name = $2
         UNION
         SELECT s.course_id, $3, COALESCE(ct.teacher_name, c2.teacher, '')
           FROM dtest2.selections s
           JOIN dtest2.courses c2 ON c2.course_id = s.course_id
           LEFT JOIN dtest2.course_teachers ct ON ct.course_id = s.course_id
          WHERE s.student_id = $1 AND s.status = 'selected'
       ) cur
       WHERE EXISTS (SELECT 1 FROM dtest2.evaluation_templates WHERE template_id = 'qt-default')
       ON CONFLICT (task_id) DO NOTHING`,
      [studentId, className, CURRENT_TERM]
    );
    await client.query(
      `DELETE FROM dtest2.evaluation_tasks et
       WHERE et.student_id = $1 AND et.status = 'open'
         AND NOT EXISTS (SELECT 1 FROM dtest2.evaluation_submissions es WHERE es.task_id = et.task_id)
         AND et.course_id NOT IN (
           SELECT csi.course_id FROM dtest2.class_schedule_items csi WHERE csi.class_name = $2
           UNION
           SELECT s.course_id FROM dtest2.selections s WHERE s.student_id = $1 AND s.status = 'selected'
         )`,
      [studentId, className]
    );
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
  }
}

// ---- 评教任务 ----
router.get('/api/evaluations', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  // 评教开放期内先与当前课程同步（学生本人请求才触发）；同步失败不阻断列表查询
  if (req.auth && req.auth.role === 'student') {
    try {
      if (await isEvalPeriodOpen()) {
        await syncTasksWithCourses(studentId);
      }
    } catch (e) {
      console.error('[dtest2-api] 评教任务同步失败:', e.stack);
    }
  }
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
  // 服务端权威校验：评教期未开放一律拒绝提交（不依赖客户端判断）
  try {
    if (!(await isEvalPeriodOpen())) {
      return res.status(409).json(fail('管理员未开放评教，暂不能提交'));
    }
  } catch (e) {
    return serverError(res, '提交评教失败', e);
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
