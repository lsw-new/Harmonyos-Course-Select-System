// 考试安排域路由（FEATURE_COMPLETION_PLAN 阶段 3）：
// 学生按「本班课表课程 ∪ 已选课程」查本人考试 / 管理端对考试 CRUD（courses.manage 细粒度权限）。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { serverError, pgClientError } = require('../middleware/errorHandler');
const { authRequired } = require('../auth');
const { permissionRequired } = require('../middleware/permission');
const { currentStudentId } = require('../identity');
const { genId } = require('../ids');

const router = express.Router();

// 管理端/学生统一的考试行 → camelCase（JOIN courses 取课程名/编码）。
function mapExam(row) {
  return {
    examId: row.exam_id,
    courseId: row.course_id,
    courseName: row.course_name || '',
    courseCode: row.course_code || '',
    term: row.term,
    examDate: row.exam_date,
    startTime: row.start_time,
    endTime: row.end_time,
    location: row.location,
    seatNo: row.seat_no,
    examType: row.exam_type
  };
}

// 时间字段宽松校验：允许留空，给值时须为 HH:MM（24 小时制）。
function isLooseTime(v) {
  if (v === undefined || v === null || v === '') {
    return true;
  }
  return /^([01]?\d|2[0-3]):[0-5]\d$/.test(String(v).trim());
}

// 写入校验：course_id 非空、term 非空、起止时间格式宽松校验。
function validatePayload(b) {
  const courseId = String((b && b.courseId) || '').trim();
  const term = String((b && b.term) || '').trim();
  if (!courseId) {
    return { error: 'courseId 不能为空' };
  }
  if (!term) {
    return { error: 'term 不能为空' };
  }
  if (!isLooseTime(b && b.startTime) || !isLooseTime(b && b.endTime)) {
    return { error: '考试时间格式不合法（应为 HH:MM）' };
  }
  return {
    courseId,
    term,
    examDate: (b && b.examDate) ? String(b.examDate).trim() : null,
    startTime: (b && b.startTime) ? String(b.startTime).trim() : null,
    endTime: (b && b.endTime) ? String(b.endTime).trim() : null,
    location: (b && b.location) ? String(b.location).trim() : null,
    seatNo: (b && b.seatNo) ? String(b.seatNo).trim() : null,
    examType: (b && b.examType) ? String(b.examType).trim() : 'final'
  };
}

async function fetchExam(examId) {
  const r = await pool.query(
    `SELECT e.exam_id, e.course_id, e.term, e.exam_date, e.start_time, e.end_time,
            e.location, e.seat_no, e.exam_type,
            c.name AS course_name, c.code AS course_code
       FROM dtest2.exams e
       LEFT JOIN dtest2.courses c ON c.course_id = e.course_id
      WHERE e.exam_id = $1`,
    [examId]
  );
  return r.rowCount > 0 ? mapExam(r.rows[0]) : null;
}

// ---- 学生：查本人考试（本班课表课程 ∪ 已选课程）----
router.get('/api/exams', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  const term = req.query.term ? String(req.query.term) : null;
  try {
    // 班级定位与 schedule.routes.js 同款 COALESCE 子查询（名册优先，回退学生资料）。
    const r = await pool.query(
      `SELECT e.exam_id, e.course_id, e.term, e.exam_date, e.start_time, e.end_time,
              e.location, e.seat_no, e.exam_type,
              c.name AS course_name, c.code AS course_code
         FROM dtest2.exams e
         LEFT JOIN dtest2.courses c ON c.course_id = e.course_id
        WHERE ($2::text IS NULL OR e.term = $2)
          AND e.course_id IN (
            SELECT csi.course_id
              FROM dtest2.class_schedule_items csi
             WHERE csi.class_name = COALESCE(
               (SELECT class_name FROM dtest2.class_students WHERE student_id = $1),
               (SELECT class_name FROM dtest2.student_profiles WHERE student_id = $1)
             )
            UNION
            SELECT s.course_id
              FROM dtest2.selections s
             WHERE s.student_id = $1 AND s.status = 'selected'
          )
        ORDER BY e.exam_date, e.start_time`,
      [studentId, term]
    );
    res.json(ok(r.rows.map(mapExam)));
  } catch (e) {
    serverError(res, '查询考试安排失败', e);
  }
});

// ---- 管理端：全部考试列表 ----
router.get('/api/admin/exams', permissionRequired('courses.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT e.exam_id, e.course_id, e.term, e.exam_date, e.start_time, e.end_time,
              e.location, e.seat_no, e.exam_type,
              c.name AS course_name, c.code AS course_code
         FROM dtest2.exams e
         LEFT JOIN dtest2.courses c ON c.course_id = e.course_id
        ORDER BY e.exam_date DESC NULLS LAST, e.exam_id`
    );
    res.json(ok(r.rows.map(mapExam)));
  } catch (e) {
    serverError(res, '查询考试安排失败', e);
  }
});

// ---- 管理端：新增考试 ----
router.post('/api/admin/exams', permissionRequired('courses.manage:create'), async (req, res) => {
  const v = validatePayload(req.body);
  if (v.error) {
    return res.status(400).json(fail(v.error));
  }
  try {
    const course = await pool.query(
      `SELECT 1 FROM dtest2.courses WHERE course_id = $1`,
      [v.courseId]
    );
    if (course.rowCount === 0) {
      return res.status(400).json(fail('课程不存在'));
    }
    const examId = genId('ex');
    await pool.query(
      `INSERT INTO dtest2.exams
         (exam_id, course_id, term, exam_date, start_time, end_time, location, seat_no, exam_type)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [examId, v.courseId, v.term, v.examDate, v.startTime, v.endTime, v.location, v.seatNo, v.examType]
    );
    res.json(ok(await fetchExam(examId)));
  } catch (e) {
    return pgClientError(res, '新增考试失败', e);
  }
});

// ---- 管理端：编辑考试 ----
router.put('/api/admin/exams/:id', permissionRequired('courses.manage:update'), async (req, res) => {
  const v = validatePayload(req.body);
  if (v.error) {
    return res.status(400).json(fail(v.error));
  }
  try {
    const r = await pool.query(
      `UPDATE dtest2.exams SET
         course_id=$2, term=$3, exam_date=$4, start_time=$5, end_time=$6,
         location=$7, seat_no=$8, exam_type=$9, updated_at=now()
       WHERE exam_id=$1`,
      [req.params.id, v.courseId, v.term, v.examDate, v.startTime, v.endTime, v.location, v.seatNo, v.examType]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('考试不存在'));
    }
    res.json(ok(await fetchExam(req.params.id)));
  } catch (e) {
    return pgClientError(res, '编辑考试失败', e);
  }
});

// ---- 管理端：删除考试 ----
router.delete('/api/admin/exams/:id', permissionRequired('courses.manage:delete'), async (req, res) => {
  try {
    const r = await pool.query(`DELETE FROM dtest2.exams WHERE exam_id=$1`, [req.params.id]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('考试不存在'));
    }
    res.json(ok({ deleted: true }));
  } catch (e) {
    return pgClientError(res, '删除考试失败', e);
  }
});

module.exports = router;
