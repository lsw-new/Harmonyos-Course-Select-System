// 成绩域路由：当前学生已发布成绩（可选 ?term 过滤）。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');

const router = express.Router();

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
       WHERE g.student_id = $1 AND ($2::text IS NULL OR g.term = $2)
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

module.exports = router;
