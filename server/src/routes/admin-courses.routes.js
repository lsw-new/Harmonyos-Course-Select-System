// 管理端课程管理域路由：课程目录的增删改查（courses.manage 细粒度权限）。
// 列表/写入与学生选课中心同一张 courses 表——远程模式下管理端改课，选课中心实时同源。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { serverError } = require('../middleware/errorHandler');
const { permissionRequired } = require('../middleware/permission');
const { mapCourse, COURSE_COLUMNS, SELECTED_COUNT_JOIN } = require('../mappers');

const router = express.Router();

const CATEGORIES = ['required', 'elective', 'public', 'practice'];
const STATUSES = ['draft', 'open', 'closed', 'archived'];
const WEEKDAY_OF = { '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7 };

// 解析 App 端的 timeText（如「周一 3-4 节」）→ 结构化排课；不匹配的（如「集中实践」）存 weeks_text
function parseTimeText(timeText) {
  const text = String(timeText || '').trim();
  const m = /^周([一二三四五六日天])\s*(\d+)\s*-\s*(\d+)\s*节$/.exec(text);
  if (m) {
    const start = parseInt(m[2], 10);
    const end = parseInt(m[3], 10);
    if (start >= 1 && end >= start && end <= 12) {
      return { weekday: WEEKDAY_OF[m[1]], periodStart: start, periodEnd: end, weeksText: null };
    }
  }
  return { weekday: null, periodStart: null, periodEnd: null, weeksText: text || null };
}

function validatePayload(b) {
  const code = String((b && b.code) || '').trim();
  const name = String((b && b.name) || '').trim();
  const teacher = String((b && b.teacher) || '').trim();
  const category = String((b && b.category) || '').trim();
  const status = String((b && b.status) || 'draft').trim();
  const credit = Number(b && b.credit);
  const capacity = Number(b && b.capacity);
  if (!code || !name || !teacher) {
    return { error: '课程编码/名称/教师不能为空' };
  }
  if (CATEGORIES.indexOf(category) < 0) {
    return { error: '课程类别不合法' };
  }
  if (STATUSES.indexOf(status) < 0) {
    return { error: '课程状态不合法' };
  }
  if (!Number.isFinite(credit) || credit <= 0 || credit > 20) {
    return { error: '学分需为 0-20 之间的数字' };
  }
  if (!Number.isInteger(capacity) || capacity < 0 || capacity > 1000) {
    return { error: '容量需为 0-1000 的整数' };
  }
  // 面向年级：空 = 全部年级；否则须为「20XX级」格式（与学号前 4 位派生的年级同口径）
  const targetGrade = String((b && b.targetGrade) || '').trim();
  if (targetGrade !== '' && !/^20\d{2}级$/.test(targetGrade)) {
    return { error: '面向年级需为「20XX级」格式或留空（全部年级）' };
  }
  return { code, name, teacher, category, status, credit, capacity, targetGrade: targetGrade || null, time: parseTimeText(b.timeText) };
}

async function fetchCourse(courseId) {
  const r = await pool.query(
    `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0)::int AS selected_count
     FROM dtest2.courses c ${SELECTED_COUNT_JOIN} WHERE c.course_id=$1`,
    [courseId]
  );
  return r.rowCount > 0 ? mapCourse(r.rows[0]) : null;
}

// ---- 课程列表（全部状态，供管理端；学生选课中心仍走 /api/courses?status=open）----
router.get('/api/admin/courses', permissionRequired('courses.manage:view'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0)::int AS selected_count
       FROM dtest2.courses c ${SELECTED_COUNT_JOIN}
       ORDER BY c.created_at DESC, c.course_id`
    );
    res.json(ok(r.rows.map(mapCourse)));
  } catch (e) {
    serverError(res, '查询课程失败', e);
  }
});

// ---- 新增课程 ----
router.post('/api/admin/courses', permissionRequired('courses.manage:create'), async (req, res) => {
  const v = validatePayload(req.body);
  if (v.error) {
    return res.status(400).json(fail(v.error));
  }
  try {
    const courseId = `ac-${Date.now()}`;
    await pool.query(
      `INSERT INTO dtest2.courses
         (course_id, code, name, category, credit, teacher, capacity, status,
          weekday, period_start, period_end, weeks_text, target_grade)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [courseId, v.code, v.name, v.category, v.credit, v.teacher, v.capacity, v.status,
        v.time.weekday, v.time.periodStart, v.time.periodEnd, v.time.weeksText, v.targetGrade]
    );
    res.json(ok(await fetchCourse(courseId)));
  } catch (e) {
    if (e && e.code) {
      return res.status(400).json(fail(`新增课程失败：${e.message}`));
    }
    serverError(res, '新增课程失败', e);
  }
});

// ---- 编辑课程 ----
router.put('/api/admin/courses/:id', permissionRequired('courses.manage:update'), async (req, res) => {
  const v = validatePayload(req.body);
  if (v.error) {
    return res.status(400).json(fail(v.error));
  }
  try {
    const r = await pool.query(
      `UPDATE dtest2.courses SET
         code=$2, name=$3, category=$4, credit=$5, teacher=$6, capacity=$7, status=$8,
         weekday=$9, period_start=$10, period_end=$11, weeks_text=$12, target_grade=$13, updated_at=now()
       WHERE course_id=$1`,
      [req.params.id, v.code, v.name, v.category, v.credit, v.teacher, v.capacity, v.status,
        v.time.weekday, v.time.periodStart, v.time.periodEnd, v.time.weeksText, v.targetGrade]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('课程不存在'));
    }
    res.json(ok(await fetchCourse(req.params.id)));
  } catch (e) {
    if (e && e.code) {
      return res.status(400).json(fail(`编辑课程失败：${e.message}`));
    }
    serverError(res, '编辑课程失败', e);
  }
});

// ---- 删除课程（被选课/成绩/评教引用时返回精确约束提示）----
router.delete('/api/admin/courses/:id', permissionRequired('courses.manage:delete'), async (req, res) => {
  try {
    const r = await pool.query(`DELETE FROM dtest2.courses WHERE course_id=$1`, [req.params.id]);
    if (r.rowCount === 0) {
      return res.status(404).json(fail('课程不存在'));
    }
    res.json(ok({ deleted: true }));
  } catch (e) {
    if (e && e.code === '23503') {
      return res.status(409).json(fail('该课程已被选课/成绩/评教记录引用，不能删除（可改为「归档」状态）'));
    }
    if (e && e.code) {
      return res.status(400).json(fail(`删除课程失败：${e.message}`));
    }
    serverError(res, '删除课程失败', e);
  }
});

module.exports = router;
