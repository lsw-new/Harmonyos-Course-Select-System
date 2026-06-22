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
const { insertMessage } = require('../messages');
const { genId } = require('../ids');

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

// ============ 课程通知（三端闭环：教师发 → 学生消息+通知列表 → 管理端可见）============

// 发布课程通知到某课程的教学班。归属校验后写 notices 行（created_by=teacherId 供「我的发布」筛选）
// 并给本班学生各发一条 system 消息（深链通知详情），同事务保证一致。
router.post('/api/teacher/notices', authRequired, teacherOnly, async (req, res) => {
  const b = req.body || {};
  const courseId = String(b.courseId || '').trim();
  const title = String(b.title || '').trim();
  const content = String(b.content || '').trim();
  const urgency = String(b.urgency || 'normal').trim();
  if (!title || !content) {
    return res.status(400).json(fail('标题和正文不能为空'));
  }
  if (title.length > 100 || content.length > 2000) {
    return res.status(400).json(fail('标题或正文过长'));
  }
  const name = await resolveTeacherName(req.auth.sub);
  const task = name ? await ownedTask(courseId, name) : null;
  if (!task) {
    return res.status(403).json(fail('无权为该课程发布通知'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cn = await client.query(`SELECT COALESCE(name,'') AS name FROM dtest2.courses WHERE course_id=$1`, [task.course_id]);
    const courseName = cn.rowCount > 0 ? cn.rows[0].name : '课程';
    const noticeId = genId('notice');
    const summary = content.length > 60 ? content.substring(0, 60) + '...' : content;
    await client.query(
      // created_by 有外键指向 admin_profiles，教师非管理员故置 NULL；本人通知按 publisher(=教师姓名)+category 识别。
      `INSERT INTO dtest2.notices
        (notice_id, title, publisher, category, urgency, summary, content, receiver_type, receiver_scope_json, publish_time, published_at, created_by, created_at)
       VALUES ($1,$2,$3,'课程通知',$4,$5,$6,'custom',$7::jsonb, now(), now(), NULL, now())`,
      [noticeId, title, name, urgency, summary, content, JSON.stringify([task.teaching_class_name])]
    );
    const studs = await client.query(
      `SELECT cs.student_id FROM dtest2.class_students cs
       JOIN dtest2.student_profiles sp ON sp.student_id = cs.student_id
       WHERE cs.class_name = $1`,
      [task.teaching_class_name]
    );
    for (const row of studs.rows) {
      await insertMessage(client, {
        studentId: row.student_id,
        kind: 'system',
        title: `课程通知·${courseName}`,
        body: title,
        route: 'pages/NoticeDetailPage',
        param: noticeId
      });
    }
    await client.query('COMMIT');
    res.json(ok({ noticeId, recipients: studs.rowCount }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '发布课程通知失败', e);
  } finally {
    client.release();
  }
});

// 我发布过的课程通知列表
router.get('/api/teacher/notices', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok([]));
    }
    const r = await pool.query(
      `SELECT notice_id, title, summary, category, urgency, published_at
       FROM dtest2.notices WHERE publisher=$1 AND category='课程通知' ORDER BY published_at DESC LIMIT 100`,
      [name]
    );
    res.json(ok(r.rows.map((row) => ({
      noticeId: row.notice_id,
      title: row.title,
      summary: row.summary || '',
      category: row.category,
      urgency: row.urgency,
      publishedAt: row.published_at
    }))));
  } catch (e) {
    serverError(res, '查询我的通知失败', e);
  }
});

// ============ 成绩申诉处理（三端闭环：学生申诉 → 教师处理 → 学生消息回执 → 管理端可见）============

// 我所授课程收到的成绩申诉（按 grade_tasks.teacher_name 归属）
router.get('/api/teacher/grade-appeals', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok([]));
    }
    const r = await pool.query(
      `SELECT ga.appeal_id, ga.student_id, ga.course_id, ga.term, ga.reason, ga.status, ga.reply, ga.submitted_at,
              COALESCE(sp.name,'') AS student_name, COALESCE(c.name,'') AS course_name
       FROM dtest2.grade_appeals ga
       JOIN dtest2.grade_tasks gt ON gt.task_id = ga.task_id AND gt.teacher_name = $1
       LEFT JOIN dtest2.student_profiles sp ON sp.student_id = ga.student_id
       LEFT JOIN dtest2.courses c ON c.course_id = ga.course_id
       ORDER BY ga.submitted_at DESC LIMIT 100`,
      [name]
    );
    res.json(ok(r.rows.map((row) => ({
      appealId: row.appeal_id,
      studentId: row.student_id,
      studentName: row.student_name,
      courseId: row.course_id || '',
      courseName: row.course_name,
      term: row.term || '',
      reason: row.reason,
      status: row.status,
      reply: row.reply || '',
      submittedAt: row.submitted_at
    }))));
  } catch (e) {
    serverError(res, '查询成绩申诉失败', e);
  }
});

// 处理（受理 accepted / 驳回 rejected）。归属校验 + 状态机 + 受理联动任务 appealed + 消息回执给学生。
const TEACHER_APPEAL_DECISIONS = ['accepted', 'rejected'];
router.post('/api/teacher/grade-appeals/:id/handle', authRequired, teacherOnly, async (req, res) => {
  const b = req.body || {};
  const decision = String(b.decision || '').trim();
  const reply = typeof b.reply === 'string' ? b.reply.trim() : '';
  if (TEACHER_APPEAL_DECISIONS.indexOf(decision) < 0) {
    return res.status(400).json(fail('处理结果不合法'));
  }
  const name = await resolveTeacherName(req.auth.sub);
  if (!name) {
    return res.status(403).json(fail('无权处理'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const cur = await client.query(
      `SELECT ga.status, ga.task_id, ga.student_id, COALESCE(c.name,'') AS course_name
       FROM dtest2.grade_appeals ga
       JOIN dtest2.grade_tasks gt ON gt.task_id = ga.task_id AND gt.teacher_name = $2
       LEFT JOIN dtest2.courses c ON c.course_id = ga.course_id
       WHERE ga.appeal_id = $1 FOR UPDATE OF ga`,
      [req.params.id, name]
    );
    if (cur.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json(fail('无权处理该申诉或申诉不存在'));
    }
    if (cur.rows[0].status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('该申诉已处理'));
    }
    await client.query(
      `UPDATE dtest2.grade_appeals SET status=$2, reply=$3, handled_by=$4, handled_at=now(), updated_at=now() WHERE appeal_id=$1`,
      [req.params.id, decision, reply, req.auth.sub]
    );
    if (decision === 'accepted' && cur.rows[0].task_id) {
      await client.query(
        `UPDATE dtest2.grade_tasks SET status='appealed', updated_at=now() WHERE task_id=$1 AND status='published'`,
        [cur.rows[0].task_id]
      );
    }
    const label = decision === 'accepted' ? '已受理' : '已驳回';
    await insertMessage(client, {
      studentId: cur.rows[0].student_id,
      kind: 'grade',
      title: `成绩复核${label}`,
      body: `《${cur.rows[0].course_name || '课程'}》成绩复核${label}${reply ? '：' + reply : ''}`,
      route: 'pages/GradeAppealPage'
    });
    await client.query('COMMIT');
    res.json(ok({ appealId: req.params.id, status: decision }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '处理成绩申诉失败', e);
  } finally {
    client.release();
  }
});

// ---- 成绩分布（某课程，归属校验）：优/良/中/及格/不及格 + 均分 ----
router.get('/api/teacher/courses/:courseId/grade-distribution', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    const task = name ? await ownedTask(req.params.courseId, name) : null;
    if (!task) {
      return res.status(403).json(fail('无权访问该课程或课程不存在'));
    }
    const r = await pool.query(
      `SELECT
         count(*) FILTER (WHERE score >= 90)::int AS excellent,
         count(*) FILTER (WHERE score >= 80 AND score < 90)::int AS good,
         count(*) FILTER (WHERE score >= 70 AND score < 80)::int AS medium,
         count(*) FILTER (WHERE score >= 60 AND score < 70)::int AS pass,
         count(*) FILTER (WHERE score < 60)::int AS fail,
         count(*)::int AS total,
         COALESCE(round(avg(score), 1), 0) AS avg_score
       FROM dtest2.grades WHERE course_id = $1 AND term = $2`,
      [task.course_id, task.term]
    );
    const row = r.rows[0] || {};
    res.json(ok({
      excellent: Number(row.excellent || 0),
      good: Number(row.good || 0),
      medium: Number(row.medium || 0),
      pass: Number(row.pass || 0),
      fail: Number(row.fail || 0),
      total: Number(row.total || 0),
      avgScore: Number(row.avg_score || 0)
    }));
  } catch (e) {
    serverError(res, '获取成绩分布失败', e);
  }
});

// ---- 我的课表（按教师姓名匹配班级课表项）----
router.get('/api/teacher/schedule', authRequired, teacherOnly, async (req, res) => {
  try {
    const name = await resolveTeacherName(req.auth.sub);
    if (!name) {
      return res.json(ok([]));
    }
    const r = await pool.query(
      `SELECT item_id, course_name, class_name, weekday, period_start, period_end,
              start_time, end_time, classroom, week_text, term
       FROM dtest2.class_schedule_items
       WHERE teacher = $1
       ORDER BY weekday, period_start`,
      [name]
    );
    res.json(ok(r.rows.map((row) => ({
      itemId: row.item_id,
      courseName: row.course_name,
      className: row.class_name,
      weekday: Number(row.weekday),
      periodStart: Number(row.period_start),
      periodEnd: Number(row.period_end),
      startTime: row.start_time,
      endTime: row.end_time,
      classroom: row.classroom || '',
      weekText: row.week_text || '',
      term: row.term
    }))));
  } catch (e) {
    serverError(res, '获取课表失败', e);
  }
});

// ---- 教师本人资料：更新邮箱（college/title 为院系分配，只读不在此改）----
router.put('/api/teacher/profile', authRequired, teacherOnly, async (req, res) => {
  const email = String((req.body || {}).email || '').trim();
  if (email.length > 0 && !/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email)) {
    return res.status(400).json(fail('邮箱格式不正确'));
  }
  try {
    const r = await pool.query(
      'UPDATE dtest2.teacher_profiles SET email=$2 WHERE teacher_id=$1',
      [req.auth.sub, email]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('教师资料不存在'));
    }
    res.json(ok({ updated: true, email }));
  } catch (e) {
    serverError(res, '更新教师资料失败', e);
  }
});

module.exports = router;
