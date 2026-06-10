// 管理端统计域路由：仪表盘聚合 / 选课轮次统计 / 评教统计——全部由数据库实时聚合。
const express = require('express');
const { pool } = require('../db');
const { ok } = require('../envelope');
const { adminRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');
const { mapApproval } = require('../mappers');

const router = express.Router();

const CATEGORY_CN = { required: '必修', elective: '选修', public: '公选', practice: '实践' };

// ---- 仪表盘（登录管理员即可：跨域只读计数，入口页）----
router.get('/api/admin/dashboard', adminRequired, async (req, res) => {
  try {
    const counts = await pool.query(
      `SELECT
         (SELECT count(*) FROM dtest2.student_profiles) AS students,
         (SELECT count(*) FROM dtest2.class_students) AS roster,
         (SELECT count(*) FROM dtest2.courses) AS courses,
         (SELECT count(*) FROM dtest2.approval_instances WHERE status='pending') AS pending_approvals,
         (SELECT count(*) FROM dtest2.grade_tasks WHERE status='pendingAudit') AS grade_pending,
         (SELECT count(*) FROM dtest2.grade_tasks WHERE status='published') AS grade_published,
         (SELECT count(*) FROM dtest2.evaluation_tasks WHERE status='submitted') AS eval_submitted,
         (SELECT count(*) FROM dtest2.notices) AS notices`
    );
    const c = counts.rows[0];
    const statCards = [
      { key: 'students', label: '注册学生', value: Number(c.students), color: '#F2709C' },
      { key: 'roster', label: '名册学生', value: Number(c.roster), color: '#B589FF' },
      { key: 'courses', label: '课程总数', value: Number(c.courses), color: '#D9B675' },
      { key: 'pendingApprovals', label: '待审批', value: Number(c.pending_approvals), color: '#F2709C' },
      { key: 'gradePending', label: '成绩待审核', value: Number(c.grade_pending), color: '#B589FF' },
      { key: 'evalSubmitted', label: '评教已提交', value: Number(c.eval_submitted), color: '#D9B675' }
    ];

    // 近 7 天选课操作趋势（按选课时间聚合，真实数据；无记录的日期补 0）
    const trend = await pool.query(
      `SELECT to_char(d.day, 'MM-DD') AS label, COALESCE(s.cnt, 0)::int AS value
       FROM generate_series(current_date - interval '6 days', current_date, interval '1 day') AS d(day)
       LEFT JOIN (SELECT date_trunc('day', created_at) AS day, count(*) AS cnt
                  FROM dtest2.selections GROUP BY 1) s ON s.day = d.day
       ORDER BY d.day`
    );

    // 课程类型分布（真实 GROUP BY）
    const dist = await pool.query(
      `SELECT category, count(*)::int AS value FROM dtest2.courses GROUP BY category ORDER BY value DESC`
    );
    const courseTypeDistribution = dist.rows.map((row) => {
      return { name: CATEGORY_CN[row.category] || row.category, value: Number(row.value) };
    });

    // 待处理审批（前 5 条）
    const approvals = await pool.query(
      `SELECT approval_id, biz_type, applicant_name, applicant_id, title, COALESCE(reason, '') AS reason, status, is_urgent, submitted_at
       FROM dtest2.approval_instances WHERE status='pending' ORDER BY submitted_at DESC LIMIT 5`
    );

    res.json(ok({
      statCards,
      selectionTrend: trend.rows.map((r) => ({ label: r.label, value: Number(r.value) })),
      courseTypeDistribution,
      pendingApprovals: approvals.rows.map(mapApproval)
    }));
  } catch (e) {
    serverError(res, '查询仪表盘失败', e);
  }
});

// ---- 选课轮次统计（真实聚合：参与人数/选课数/均学分/时间进度）----
router.get('/api/admin/selection/stats', permissionRequired('selection.manage:view'), async (req, res) => {
  try {
    const rounds = await pool.query(
      `SELECT r.round_id, r.name, r.status, r.start_time, r.end_time,
              COALESCE(agg.participants, 0)::int AS participants,
              COALESCE(agg.selections, 0)::int AS selections,
              COALESCE(agg.avg_credit, 0)::numeric(6,2) AS avg_credit
       FROM dtest2.selection_rounds r
       LEFT JOIN (
         SELECT s.round_id,
                count(DISTINCT s.student_id) AS participants,
                count(*) AS selections,
                COALESCE(sum(c.credit) / NULLIF(count(DISTINCT s.student_id), 0), 0) AS avg_credit
         FROM dtest2.selections s
         JOIN dtest2.courses c ON c.course_id = s.course_id
         WHERE s.status = 'selected'
         GROUP BY s.round_id
       ) agg ON agg.round_id = r.round_id
       ORDER BY r.start_time DESC`
    );
    const now = Date.now();
    const data = rounds.rows.map((r) => {
      const start = new Date(r.start_time).getTime();
      const end = new Date(r.end_time).getTime();
      let progress = 0;
      if (Number.isFinite(start) && Number.isFinite(end) && end > start) {
        progress = Math.round(Math.min(100, Math.max(0, ((now - start) / (end - start)) * 100)));
      }
      // 后端轮次状态(notStarted/running/ended)直接透传，App 端同词表
      return {
        id: r.round_id,
        name: r.name,
        status: r.status,
        startTime: r.start_time,
        endTime: r.end_time,
        progressPercent: progress,
        participantCount: Number(r.participants),
        selectionCount: Number(r.selections),
        averageCredit: Number(r.avg_credit),
        conflictCount: 0
      };
    });
    res.json(ok(data));
  } catch (e) {
    serverError(res, '查询选课统计失败', e);
  }
});

// ---- 评教统计（参与率/完成率/平均分/星级分布，由任务与答卷实时聚合）----
router.get('/api/admin/eval/stats', permissionRequired('evaluations.manage:view'), async (req, res) => {
  try {
    const agg = await pool.query(
      `SELECT
         (SELECT count(*) FROM dtest2.evaluation_tasks) AS total_tasks,
         (SELECT count(*) FROM dtest2.evaluation_tasks WHERE status='submitted') AS submitted_tasks,
         (SELECT count(DISTINCT student_id) FROM dtest2.evaluation_tasks) AS task_students,
         (SELECT count(DISTINCT student_id) FROM dtest2.evaluation_submissions) AS submitted_students,
         (SELECT MIN(term) FROM dtest2.evaluation_tasks) AS term`
    );
    const a = agg.rows[0];
    const totalTasks = Number(a.total_tasks);
    const submittedTasks = Number(a.submitted_tasks);
    const taskStudents = Number(a.task_students);
    const submittedStudents = Number(a.submitted_students);

    // 评分分布与平均分：解析答卷 JSON 中的数值评分（rating/single 选项分值），按 1-5 星聚合
    const subs = await pool.query(`SELECT answers_json FROM dtest2.evaluation_submissions LIMIT 1000`);
    const buckets = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let scoreSum = 0;
    let scoreCount = 0;
    for (const row of subs.rows) {
      const answers = Array.isArray(row.answers_json) ? row.answers_json : [];
      for (const ans of answers) {
        const v = Number(ans && (ans.score !== undefined ? ans.score : ans.rating));
        if (Number.isFinite(v) && v >= 1 && v <= 5) {
          buckets[Math.round(v)] += 1;
          scoreSum += v;
          scoreCount += 1;
        }
      }
    }
    res.json(ok({
      term: a.term || '2025-2026-2',
      participationRate: taskStudents > 0 ? Math.round((submittedStudents / taskStudents) * 100) : 0,
      completionRate: totalTasks > 0 ? Math.round((submittedTasks / totalTasks) * 100) : 0,
      averageScore: scoreCount > 0 ? Math.round((scoreSum / scoreCount) * 10) / 10 : 0,
      ratingDistribution: [5, 4, 3, 2, 1].map((star) => ({ star, count: buckets[star] }))
    }));
  } catch (e) {
    serverError(res, '查询评教统计失败', e);
  }
});

module.exports = router;
