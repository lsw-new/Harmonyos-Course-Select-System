// 选课域路由：课程列表 / 当前选课轮次 / 我的已选 / 选课（事务+行锁）/ 退课。
// 选课写操作的学分上限、时间冲突、容量校验以后端为单一事实来源。从 index.js 平移，行为不变。
const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { mapCourse, COURSE_COLUMNS, SELECTED_COUNT_JOIN, coursesConflict } = require('../mappers');

const router = express.Router();

// ---- 课程列表（可选 ?status=open）----
router.get('/api/courses', authRequired, async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  try {
    const r = await pool.query(
      `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0) AS selected_count
       FROM dtest2.courses c
       ${SELECTED_COUNT_JOIN}
       WHERE ($1::text IS NULL OR c.status = $1)
       ORDER BY c.created_at DESC`,
      [status]
    );
    res.json(ok(r.rows.map(mapCourse)));
  } catch (e) {
    serverError(res, '查询课程失败', e);
  }
});

// 选课开放判定（单一事实来源）：轮次 status='running' 且当前时刻落在起止时间窗口内。
// 管理员暂停/结束轮次、或到达 end_time，三者任一即全局关闭选课（选课与退课同口径）。
const ACTIVE_ROUND_WHERE = `status='running' AND now() >= start_time AND now() <= end_time`;

// ---- 当前进行中的选课轮次 ----
router.get('/api/selection-rounds/active', authRequired, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT round_id, name, status, start_time, end_time, credit_limit
       FROM dtest2.selection_rounds WHERE ${ACTIVE_ROUND_WHERE}
       ORDER BY start_time DESC LIMIT 1`
    );
    if (r.rowCount === 0) {
      return res.json(ok(null));
    }
    const row = r.rows[0];
    res.json(ok({
      id: row.round_id,
      name: row.name,
      status: row.status,
      startTime: row.start_time,
      endTime: row.end_time,
      creditLimit: Number(row.credit_limit)
    }));
  } catch (e) {
    serverError(res, '查询轮次失败', e);
  }
});

// ---- 我的已选课程 ----
router.get('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  if (!studentId) {
    return res.status(400).json(fail('缺少 studentId'));
  }
  try {
    const r = await pool.query(
      `SELECT ${COURSE_COLUMNS}, COALESCE(sc.cnt, 0) AS selected_count
       FROM dtest2.selections s
       JOIN dtest2.courses c ON c.course_id = s.course_id
       ${SELECTED_COUNT_JOIN}
       WHERE s.student_id=$1 AND s.status='selected'
       ORDER BY s.created_at DESC`,
      [studentId]
    );
    res.json(ok(r.rows.map(mapCourse)));
  } catch (e) {
    serverError(res, '查询选课失败', e);
  }
});

// ---- 选课（事务：轮次 / 容量 / 重复 校验）----
router.post('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const courseId = ((req.body && req.body.courseId) || '').trim();
  if (!studentId || !courseId) {
    return res.status(400).json(fail('缺少 studentId 或 courseId'));
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const round = await client.query(
      `SELECT round_id, credit_limit FROM dtest2.selection_rounds WHERE ${ACTIVE_ROUND_WHERE} ORDER BY start_time DESC LIMIT 1`
    );
    if (round.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('当前不在选课时间，暂不能选课'));
    }
    const roundId = round.rows[0].round_id;
    const creditLimit = Number(round.rows[0].credit_limit);
    // FOR UPDATE 锁定课程行：序列化同一课程的并发选课，使下方 COUNT 容量校验与 INSERT 原子化，杜绝超容量。
    const course = await client.query(
      `SELECT capacity, status, credit, weekday, period_start, period_end, weeks_text
         FROM dtest2.courses WHERE course_id=$1 FOR UPDATE`, [courseId]
    );
    if (course.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json(fail('课程不存在'));
    }
    if (course.rows[0].status !== 'open') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('课程未开放选课'));
    }
    const dup = await client.query(
      `SELECT status FROM dtest2.selections WHERE student_id=$1 AND course_id=$2 AND round_id=$3`,
      [studentId, courseId, roundId]
    );
    if (dup.rowCount > 0 && dup.rows[0].status === 'selected') {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('已选该课程'));
    }
    const cnt = await client.query(
      `SELECT COUNT(*)::int AS n FROM dtest2.selections WHERE course_id=$1 AND status='selected'`, [courseId]
    );
    if (cnt.rows[0].n >= course.rows[0].capacity) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('课程容量已满'));
    }
    // 学分上限 + 时间冲突：后端为单一事实来源，基于当前轮次已选课程做权威校验（前端提示仅作辅助）。
    const targetCourse = course.rows[0];
    const selected = await client.query(
      `SELECT c.name, c.credit, c.weekday, c.period_start, c.period_end, c.weeks_text
         FROM dtest2.selections s
         JOIN dtest2.courses c ON c.course_id = s.course_id
        WHERE s.student_id=$1 AND s.round_id=$2 AND s.status='selected'`,
      [studentId, roundId]
    );
    let selectedCredits = 0;
    for (const row of selected.rows) {
      selectedCredits += Number(row.credit);
    }
    if (selectedCredits + Number(targetCourse.credit) > creditLimit) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail(`超过学分上限（${creditLimit} 学分）`));
    }
    for (const row of selected.rows) {
      if (coursesConflict(targetCourse, row)) {
        await client.query('ROLLBACK');
        return res.status(409).json(fail(`与「${row.name}」时间冲突`));
      }
    }
    // 限选规则：每名学生限选一门选修课程（选修课统一安排在周四晚，多门同台二选一）
    if (selected.rows.length >= 1) {
      await client.query('ROLLBACK');
      return res.status(409).json(fail('每人限选一门选修课程，请先退选已选课程'));
    }
    const selId = `sel-${studentId}-${courseId}-${roundId}`;
    await client.query(
      `INSERT INTO dtest2.selections (selection_id, student_id, course_id, round_id, status, created_at, dropped_at)
       VALUES ($1,$2,$3,$4,'selected',now(),NULL)
       ON CONFLICT (student_id, course_id, round_id)
       DO UPDATE SET status='selected', dropped_at=NULL`,
      [selId, studentId, courseId, roundId]
    );
    await client.query('COMMIT');
    res.json(ok({ selected: true }));
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    serverError(res, '选课失败', e);
  } finally {
    client.release();
  }
});

// ---- 退课（软删除 status=dropped；与选课同口径：选课关闭后退课同样关闭）----
router.delete('/api/selections', authRequired, async (req, res) => {
  const studentId = currentStudentId(req);
  const courseId = ((req.body && req.body.courseId) || '').trim();
  if (!studentId || !courseId) {
    return res.status(400).json(fail('缺少 studentId 或 courseId'));
  }
  try {
    const round = await pool.query(
      `SELECT round_id FROM dtest2.selection_rounds WHERE ${ACTIVE_ROUND_WHERE} LIMIT 1`
    );
    if (round.rowCount === 0) {
      return res.status(409).json(fail('当前不在选课时间，暂不能退课'));
    }
    const r = await pool.query(
      `UPDATE dtest2.selections SET status='dropped', dropped_at=now()
       WHERE student_id=$1 AND course_id=$2 AND status='selected'`,
      [studentId, courseId]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('该课程未被选中'));
    }
    res.json(ok({ dropped: true }));
  } catch (e) {
    serverError(res, '退课失败', e);
  }
});

module.exports = router;
