// 管理端报表导出域（roadmap #13）：把既有管理端统计（成绩/选课/评教）以 Excel(xlsx) 下载。
// 数据全部复用 admin-stats.routes 同款实时聚合 SQL，不新增任何指标。
// 成功响应为二进制 xlsx（非 JSON 信封）；仅错误分支用 ok/fail 信封。
const express = require('express');
const ExcelJS = require('exceljs');
const { pool } = require('../db');
const { fail } = require('../envelope');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');

const router = express.Router();

const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// 每类报表选用与对应统计端点一致的「查看」权限，命中即放行：
//   grades     → grades.approve:view（与 admin.routes 成绩审核列表同款，含 grades.input:view 兜底）
//   selection  → selection.manage:view（与 /api/admin/selection/stats 同款）
//   evaluation → evaluations.manage:view（与 /api/admin/eval/stats 同款）
const REPORT_PERMS = {
  grades: ['grades.approve:view', 'grades.input:view'],
  selection: ['selection.manage:view'],
  evaluation: ['evaluations.manage:view']
};

// 成绩报表：复用仪表盘 stat-card 同款聚合（grade_tasks 各状态计数）——不新增指标。
async function buildGradesWorkbook() {
  const counts = await pool.query(
    `SELECT
       (SELECT count(*) FROM dtest2.grade_tasks WHERE status='pendingAudit') AS grade_pending,
       (SELECT count(*) FROM dtest2.grade_tasks WHERE status='published') AS grade_published,
       (SELECT count(*) FROM dtest2.grade_tasks) AS grade_total`
  );
  const c = counts.rows[0] || {};
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('成绩统计');
  ws.columns = [
    { header: '指标', key: 'metric', width: 24 },
    { header: '数值', key: 'value', width: 16 }
  ];
  ws.addRow({ metric: '成绩任务总数', value: Number(c.grade_total || 0) });
  ws.addRow({ metric: '待审核', value: Number(c.grade_pending || 0) });
  ws.addRow({ metric: '已发布', value: Number(c.grade_published || 0) });
  return wb;
}

// 选课报表：复用 /api/admin/selection/stats 同款轮次聚合 SQL。
async function buildSelectionWorkbook() {
  const rounds = await pool.query(
    `SELECT r.round_id, r.name, r.status,
            to_char(r.start_time AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS start_time,
            to_char(r.end_time AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD HH24:MI') AS end_time,
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
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('选课统计');
  ws.columns = [
    { header: '轮次', key: 'name', width: 22 },
    { header: '状态', key: 'status', width: 12 },
    { header: '开始时间', key: 'start', width: 18 },
    { header: '结束时间', key: 'end', width: 18 },
    { header: '参与人数', key: 'participants', width: 12 },
    { header: '选课数', key: 'selections', width: 12 },
    { header: '人均学分', key: 'avgCredit', width: 12 }
  ];
  for (const r of rounds.rows) {
    ws.addRow({
      name: r.name,
      status: r.status,
      start: r.start_time,
      end: r.end_time,
      participants: Number(r.participants),
      selections: Number(r.selections),
      avgCredit: Number(r.avg_credit)
    });
  }
  return wb;
}

// 评教报表：复用 /api/admin/eval/stats 同款聚合 + 答卷星级解析（不新增指标）。
async function buildEvaluationWorkbook() {
  const agg = await pool.query(
    `SELECT
       (SELECT count(*) FROM dtest2.evaluation_tasks) AS total_tasks,
       (SELECT count(*) FROM dtest2.evaluation_tasks WHERE status='submitted') AS submitted_tasks,
       (SELECT count(DISTINCT student_id) FROM dtest2.evaluation_tasks) AS task_students,
       (SELECT count(DISTINCT student_id) FROM dtest2.evaluation_submissions) AS submitted_students,
       (SELECT MIN(term) FROM dtest2.evaluation_tasks) AS term`
  );
  const a = agg.rows[0] || {};
  const totalTasks = Number(a.total_tasks || 0);
  const submittedTasks = Number(a.submitted_tasks || 0);
  const taskStudents = Number(a.task_students || 0);
  const submittedStudents = Number(a.submitted_students || 0);

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
  const participationRate = taskStudents > 0 ? Math.round((submittedStudents / taskStudents) * 100) : 0;
  const completionRate = totalTasks > 0 ? Math.round((submittedTasks / totalTasks) * 100) : 0;
  const averageScore = scoreCount > 0 ? Math.round((scoreSum / scoreCount) * 10) / 10 : 0;

  const wb = new ExcelJS.Workbook();
  const summary = wb.addWorksheet('评教汇总');
  summary.columns = [
    { header: '指标', key: 'metric', width: 24 },
    { header: '数值', key: 'value', width: 16 }
  ];
  summary.addRow({ metric: '学期', value: a.term || '2025-2026-2' });
  summary.addRow({ metric: '参与率(%)', value: participationRate });
  summary.addRow({ metric: '完成率(%)', value: completionRate });
  summary.addRow({ metric: '平均分', value: averageScore });

  const dist = wb.addWorksheet('星级分布');
  dist.columns = [
    { header: '星级', key: 'star', width: 12 },
    { header: '数量', key: 'count', width: 12 }
  ];
  for (const star of [5, 4, 3, 2, 1]) {
    dist.addRow({ star, count: buckets[star] });
  }
  return wb;
}

const BUILDERS = {
  grades: buildGradesWorkbook,
  selection: buildSelectionWorkbook,
  evaluation: buildEvaluationWorkbook
};

// ASCII 安全文件名：report-<type>-<YYYYMMDD>.xlsx（避免 Content-Disposition 非 ASCII 头）
function safeFilename(type) {
  const d = new Date();
  const stamp = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
  return `report-${type}-${stamp}.xlsx`;
}

// 单端点 + 动态权限：先按 :type 选权限，未知 type 直接 400（不触达 DB）。
router.get('/api/admin/reports/:type/export', (req, res, next) => {
  const type = String(req.params.type || '');
  const perms = REPORT_PERMS[type];
  if (!perms) {
    return res.status(400).json(fail(`不支持的报表类型：${type}`));
  }
  // 先过细粒度鉴权（缺权→403 / 无 token→401），通过后再生成工作簿。
  return permissionRequired(...perms)(req, res, async () => {
    try {
      const wb = await BUILDERS[type]();
      const buffer = await wb.xlsx.writeBuffer();
      res.setHeader('Content-Type', XLSX_MIME);
      res.setHeader('Content-Disposition', `attachment; filename="${safeFilename(type)}"`);
      res.setHeader('Content-Length', buffer.length);
      return res.status(200).end(Buffer.from(buffer));
    } catch (e) {
      return serverError(res, '生成报表失败', e);
    }
  });
});

module.exports = router;
