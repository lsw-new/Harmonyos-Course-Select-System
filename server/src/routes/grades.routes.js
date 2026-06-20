// 成绩域路由：当前学生已发布成绩（可选 ?term 过滤）+ 成绩单 PDF 导出。从 index.js 平移，行为不变。
const path = require('path');
const PDFDocument = require('pdfkit');
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');

const router = express.Router();

// 内嵌 CJK 字体（OFL，Noto Sans SC Regular）：pdfkit 内置字体无法渲染中文，必须注册 TTF/OTF。
const CJK_FONT_PATH = path.join(__dirname, '..', '..', 'assets', 'fonts', 'NotoSansSC-Regular.otf');

// ---- 成绩（当前学生已发布成绩）----
router.get('/api/grades', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  try {
    const r = await pool.query(
      `SELECT g.grade_id, g.term, g.score, COALESCE(g.grade_point, 0) AS grade_point, COALESCE(g.rank, 0) AS rank, g.published_at,
              COALESCE(c.code, '') AS code, COALESCE(c.teaching_class_no, '') AS teaching_class_no,
              COALESCE(c.name, '') AS name, COALESCE(c.category, '') AS category, COALESCE(c.credit, 0) AS credit
       FROM dtest2.grades g
       LEFT JOIN dtest2.courses c ON c.course_id = g.course_id
       WHERE g.student_id = $1 AND g.published_at IS NOT NULL AND ($2::text IS NULL OR g.term = $2)
       ORDER BY g.published_at DESC`,
      [studentId, term]
    );
    const data = r.rows.map((row) => {
      return {
        id: row.grade_id,
        term: row.term,
        courseCode: row.code,
        teachingClassNo: row.teaching_class_no,
        courseName: row.name,
        courseCategory: row.category,
        credit: Number(row.credit),
        score: Number(row.score),
        gradePoint: Number(row.grade_point),
        rank: Number(row.rank),
        publishedAt: row.published_at
      };
    });
    res.json(ok(data));
  } catch (e) {
    serverError(res, '查询成绩失败', e);
  }
});

// ---- 成绩单导出（PDF）：当前学生已发布成绩 + GPA/已修学分/门数汇总 ----
// 复用 GET /api/grades 的已发布成绩查询与 GET /api/profile/record 的聚合 SQL，不另造指标。
router.get('/api/grades/transcript', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    // 1) 学籍基础信息 + 实时聚合（与 /api/profile/record 同源 SQL）
    const recordRes = await pool.query(
      `SELECT sp.student_id, sp.name, sp.college, sp.major, sp.class_name,
              agg.gpa, agg.earned_credits, agg.passed_count
       FROM dtest2.student_profiles sp
       LEFT JOIN (
         SELECT g.student_id,
                AVG(g.grade_point) AS gpa,
                SUM(COALESCE(c.credit, 0)) AS earned_credits,
                COUNT(*) AS passed_count
         FROM dtest2.grades g
         LEFT JOIN dtest2.courses c ON c.course_id = g.course_id
         WHERE g.student_id = $1 AND g.published_at IS NOT NULL
         GROUP BY g.student_id
       ) agg ON agg.student_id = sp.student_id
       WHERE sp.student_id = $1`,
      [studentId]
    );
    if (recordRes.rowCount === 0) {
      return res.status(404).json(fail('学生资料不存在'));
    }
    const p = recordRes.rows[0];

    // 2) 已发布成绩明细（与 /api/grades 同源 SQL）
    const gradesRes = await pool.query(
      `SELECT g.term, g.score, COALESCE(g.grade_point, 0) AS grade_point,
              COALESCE(c.code, '') AS code, COALESCE(c.name, '') AS name, COALESCE(c.credit, 0) AS credit
       FROM dtest2.grades g
       LEFT JOIN dtest2.courses c ON c.course_id = g.course_id
       WHERE g.student_id = $1 AND g.published_at IS NOT NULL
       ORDER BY g.published_at DESC`,
      [studentId]
    );
    const rows = gradesRes.rows;

    const gpa = (p.gpa === null || p.gpa === undefined) ? null : Number(Number(p.gpa).toFixed(2));
    const earnedCredits = (p.earned_credits === null || p.earned_credits === undefined) ? 0 : Number(p.earned_credits);
    const passedCount = (p.passed_count === null || p.passed_count === undefined) ? 0 : Number(p.passed_count);

    // 3) 生成 PDF 并流式返回
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="transcript-${studentId}.pdf"`);

    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    doc.registerFont('cjk', CJK_FONT_PATH);
    doc.font('cjk');
    doc.on('error', () => { /* 流错误交由 Express/响应层处理 */ });
    doc.pipe(res);

    // 抬头
    doc.fontSize(20).text('成绩单', { align: 'center' });
    doc.moveDown(0.8);
    doc.fontSize(11);
    doc.text(`姓名：${p.name || ''}        学号：${p.student_id || ''}`);
    if (p.college || p.major || p.class_name) {
      doc.text(`学院：${p.college || ''}    专业：${p.major || ''}    班级：${p.class_name || ''}`);
    }
    doc.moveDown(0.8);

    // 表头
    const left = doc.page.margins.left;
    const usableWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
    const cols = [
      { key: 'name', label: '课程', w: usableWidth * 0.40 },
      { key: 'credit', label: '学分', w: usableWidth * 0.13 },
      { key: 'score', label: '成绩', w: usableWidth * 0.13 },
      { key: 'gp', label: '绩点', w: usableWidth * 0.13 },
      { key: 'term', label: '学期', w: usableWidth * 0.21 }
    ];
    function drawRow(values, y) {
      let x = left;
      for (let i = 0; i < cols.length; i++) {
        doc.text(String(values[i]), x + 2, y, { width: cols[i].w - 4, ellipsis: true });
        x += cols[i].w;
      }
    }
    doc.fontSize(11);
    let y = doc.y;
    drawRow(cols.map((c) => c.label), y);
    y = doc.y + 2;
    doc.moveTo(left, y).lineTo(left + usableWidth, y).stroke();
    y += 4;

    doc.fontSize(10);
    for (const r of rows) {
      if (y > doc.page.height - doc.page.margins.bottom - 60) {
        doc.addPage();
        y = doc.page.margins.top;
      }
      drawRow(
        [r.name || '', Number(r.credit), Number(r.score), Number(r.grade_point), r.term || ''],
        y
      );
      y = doc.y + 3;
    }
    if (rows.length === 0) {
      doc.text('（暂无已发布成绩）', left, y);
      y = doc.y;
    }

    // 汇总
    doc.moveDown(1);
    doc.moveTo(left, doc.y).lineTo(left + usableWidth, doc.y).stroke();
    doc.moveDown(0.5);
    doc.fontSize(11).text(
      `GPA：${gpa === null ? '--' : gpa}        已修学分：${earnedCredits}        已修门数：${passedCount}`
    );

    doc.end();
  } catch (e) {
    serverError(res, '导出成绩单失败', e);
  }
});

module.exports = router;
