'use strict';
// 教师端域（roadmap #6 teacher portal）。
// 教师身份 = JWT（role='teacher'，sub=teacherId）；课程归属通过 teacher_profiles.name
// 与 grade_tasks.teacher_name / courses.teacher / evaluation_tasks.teacher_name 关联。
// 一切「我的课程/学生/打分」均以「教师姓名匹配」做服务端鉴权，杜绝越权访问他人课程（防 IDOR）。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');

const router = express.Router();

// 教师专用守卫：authRequired 之后再校验 role。
function teacherOnly(req, res, next) {
  if (!req.auth || req.auth.role !== 'teacher') {
    return res.status(403).json(fail('需要教师权限'));
  }
  next();
}

// 绩点换算（与管理端打分口径一致：<60 计 0，否则 (score-50)/10 截顶 4.0）。
function gradePointOf(score) {
  if (score < 60) {
    return 0;
  }
  return Math.min(4.0, Math.round(((score - 50) / 10) * 10) / 10);
}

// 由 teacherId 解析教师姓名（课程匹配键）。无 profile 返回空串。
async function resolveTeacherName(teacherId) {
  const r = await pool.query(
    `SELECT name FROM dtest2.teacher_profiles WHERE teacher_id=$1`,
    [teacherId]
  );
  return r.rowCount > 0 ? r.rows[0].name : '';
}

const num = (v) => (v === null || v === undefined ? null : Number(v));

// ---- 教师工作台概览 ----
router.get('/api/teacher/dashboard', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok({ courseCount: 0, studentCount: 0, pendingGradeCount: 0, evalAvg: null, evalSubmitted: 0 }));
    }
    const r = await pool.query(
      `SELECT
         (SELECT count(*)::int FROM dtest2.grade_tasks WHERE teacher_name=$1) AS course_count,
         (SELECT count(DISTINCT cs.student_id)::int
            FROM dtest2.grade_tasks gt
            JOIN dtest2.class_students cs ON cs.class_name = gt.teaching_class_name
            WHERE gt.teacher_name=$1) AS student_count,
         (SELECT count(*)::int FROM dtest2.grade_tasks WHERE teacher_name=$1 AND status='inputting') AS pending_grade_count,
         (SELECT count(*)::int FROM dtest2.evaluation_tasks WHERE teacher_name=$1 AND status='submitted') AS eval_submitted`,
      [name]
    );
    const row = r.rows[0] || {};
    res.json(ok({
      courseCount: Number(row.course_count || 0),
      studentCount: Number(row.student_count || 0),
      pendingGradeCount: Number(row.pending_grade_count || 0),
      // 评教平均分需评教作答表聚合，MVP 暂以 null 呈现（已提交份数另见评教页）
      evalAvg: null,
      evalSubmitted: Number(row.eval_submitted || 0)
    }));
  } catch (e) {
    serverError(res, '获取教师工作台失败', e);
  }
});

// ---- 我的课程（来自 grade_tasks：每个教学班任务即一门可打分课程） ----
router.get('/api/teacher/courses', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok([]));
    }
    const r = await pool.query(
      `SELECT gt.task_id, gt.course_id, gt.term, gt.teaching_class_name, gt.status AS grade_status, gt.input_progress,
              COALESCE(c.code,'') AS code, COALESCE(c.name,'') AS name,
              COALESCE(c.category,'') AS category, COALESCE(c.credit,0) AS credit,
              (SELECT count(*)::int FROM dtest2.class_students cs WHERE cs.class_name = gt.teaching_class_name) AS student_count
       FROM dtest2.grade_tasks gt
       LEFT JOIN dtest2.courses c ON c.course_id = gt.course_id
       WHERE gt.teacher_name = $1
       ORDER BY gt.term DESC, c.name`,
      [name]
    );
    const data = r.rows.map((row) => ({
      courseId: row.course_id,
      taskId: row.task_id,
      code: row.code,
      name: row.name,
      category: row.category,
      credit: Number(row.credit || 0),
      teachingClassName: row.teaching_class_name,
      term: row.term,
      studentCount: Number(row.student_count || 0),
      gradeStatus: row.grade_status,
      inputProgress: Number(row.input_progress || 0)
    }));
    res.json(ok(data));
  } catch (e) {
    serverError(res, '获取我的课程失败', e);
  }
});

// 由 (courseId, 教师姓名) 取该教师在此课程的成绩任务（最近学期），用于鉴权 + 取教学班/学期。
async function ownedTask(courseId, teacherName) {
  const r = await pool.query(
    `SELECT task_id, course_id, term, teaching_class_name, status
     FROM dtest2.grade_tasks
     WHERE course_id=$1 AND teacher_name=$2
     ORDER BY term DESC LIMIT 1`,
    [courseId, teacherName]
  );
  return r.rowCount > 0 ? r.rows[0] : null;
}

// ---- 某课程的学生名单 + 当前成绩 ----
router.get('/api/teacher/courses/:courseId/students', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    const task = name ? await ownedTask(req.params.courseId, name) : null;
    if (!task) {
      return res.status(403).json(fail('无权访问该课程或课程不存在'));
    }
    const r = await pool.query(
      `SELECT cs.student_id, COALESCE(sp.name,'') AS name, COALESCE(sp.class_name,'') AS class_name,
              g.score, g.grade_point,
              CASE WHEN g.grade_id IS NULL THEN 'none' ELSE 'scored' END AS status
       FROM dtest2.class_students cs
       JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
       LEFT JOIN dtest2.grades g ON g.student_id = cs.student_id AND g.course_id = $1 AND g.term = $2
       WHERE cs.class_name = $3
       ORDER BY cs.student_id`,
      [task.course_id, task.term, task.teaching_class_name]
    );
    const students = r.rows.map((row) => ({
      studentId: row.student_id,
      name: row.name,
      className: row.class_name,
      score: num(row.score),
      gradePoint: num(row.grade_point),
      status: row.status
    }));
    res.json(ok({ courseId: task.course_id, term: task.term, teachingClassName: task.teaching_class_name, students }));
  } catch (e) {
    serverError(res, '获取课程学生失败', e);
  }
});

// ---- 教师录入成绩（录入阶段，不自动发布；管理端仍审核/发布） ----
router.post('/api/teacher/courses/:courseId/grades', authRequired, teacherOnly, async (req, res) => {
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
  const name = await resolveTeacherName(req.auth.sub);
  if (!name) {
    return res.status(403).json(fail('无权录入成绩'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 鉴权 + 锁定该教师此课程的成绩任务
    const taskRes = await client.query(
      `SELECT task_id, course_id, term, teaching_class_name, status
       FROM dtest2.grade_tasks
       WHERE course_id=$1 AND teacher_name=$2
       ORDER BY term DESC LIMIT 1
       FOR UPDATE`,
      [req.params.courseId, name]
    );
    if (taskRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json(fail('无权为该课程录入成绩'));
    }
    const t = taskRes.rows[0];
    if (t.status === 'published') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('成绩已发布，不可再录入'));
    }
    // 名单校验：仅允许给本教学班已注册学生录入（与管理端打分同口径）
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
    // 批量 UPSERT（与管理端一致），录入即 published_at=NULL（未发布）
    await client.query(
      `INSERT INTO dtest2.grades (grade_id, task_id, student_id, course_id, term, score, grade_point, rank, published_at)
       SELECT 'g-' || $1 || '-' || x.sid, $1, x.sid, $2, $3, x.score, x.gp, 0, NULL
       FROM unnest($4::text[], $5::numeric[], $6::numeric[]) AS x(sid, score, gp)
       ON CONFLICT (student_id, course_id, term) DO UPDATE
         SET score=EXCLUDED.score, grade_point=EXCLUDED.grade_point, task_id=EXCLUDED.task_id, published_at=NULL`,
      [t.task_id, t.course_id, t.term, sids, scoreVals, gradePoints]
    );
    // 重算排名
    await client.query(
      `UPDATE dtest2.grades g SET rank = r.rnk
       FROM (SELECT grade_id, RANK() OVER (ORDER BY score DESC) AS rnk
             FROM dtest2.grades WHERE course_id=$1 AND term=$2) r
       WHERE g.grade_id = r.grade_id`,
      [t.course_id, t.term]
    );
    // 进度 = 已打分/本班注册数；满 100 转待审核
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
      [t.task_id, progress, nextStatus]
    );
    await client.query('COMMIT');
    res.json(ok({ updated: sids.length, inputProgress: progress, status: nextStatus }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '录入成绩失败', e);
  } finally {
    client.release();
  }
});

// ---- 我的评教（按课程聚合任务数/已提交数） ----
router.get('/api/teacher/evaluations', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok([]));
    }
    const r = await pool.query(
      `SELECT et.course_id, COALESCE(c.name,'') AS course_name, et.term,
              count(*)::int AS task_count,
              count(*) FILTER (WHERE et.status='submitted')::int AS submitted_count
       FROM dtest2.evaluation_tasks et
       LEFT JOIN dtest2.courses c ON c.course_id = et.course_id
       WHERE et.teacher_name = $1
       GROUP BY et.course_id, c.name, et.term
       ORDER BY et.term DESC, c.name`,
      [name]
    );
    const data = r.rows.map((row) => ({
      courseId: row.course_id,
      courseName: row.course_name,
      term: row.term,
      taskCount: Number(row.task_count || 0),
      submittedCount: Number(row.submitted_count || 0),
      // 评教均分需作答表聚合，MVP 留 null
      avgScore: null
    }));
    res.json(ok(data));
  } catch (e) {
    serverError(res, '获取评教结果失败', e);
  }
});

module.exports = router;
