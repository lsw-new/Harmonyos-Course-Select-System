'use strict';
// 有状态并发 mock：忠实复刻 Postgres 行级锁（SELECT ... FOR UPDATE）对临界区的序列化，
// 用于「N 人同抢有限名额」压力测试，验证最终落库数 ≤ capacity / slotsTotal。
//
// 与无状态的 dbMock 的关键差异：
//   1. 维护「活的」已选/已报计数：INSERT 递增，COUNT 读当前值。
//   2. serialize=true（默认）：course/project 行锁从 FOR UPDATE 一直持有到 COMMIT/ROLLBACK，
//      临界区严格互斥——这正是 FOR UPDATE 的语义，使 COUNT 容量校验与 INSERT 原子化。
//   3. serialize=false：去掉锁，且每个事务的 COUNT 只读到事务开始时的快照(0)，
//      复刻「漏配 FOR UPDATE」的竞态——所有人都读到未满 → 全部插入 → 超容量。
//      作为非退化对照：证明上面的安全断言不是因为 mock 永不超容量而恒真。

// 简单的 promise 链互斥锁：acquire() 解析为本次持有者的 release 函数。
function makeMutex() {
  let tail = Promise.resolve();
  return function acquire() {
    let release;
    const gate = new Promise((res) => { release = res; });
    const waitOn = tail;
    tail = tail.then(() => gate);
    return waitOn.then(() => release);
  };
}

const COURSE_DEFAULT = {
  capacity: 1, status: 'open', credit: 1, weekday: 1, period_start: 1, period_end: 2, weeks_text: '1-16'
};

const sim = {};
let acquireCourse = makeMutex();
let acquireProject = makeMutex();

function reset(overrides) {
  const o = overrides || {};
  sim.serialize = o.serialize !== undefined ? o.serialize : true;
  sim.course = Object.assign({}, COURSE_DEFAULT, o.course || {});
  sim.creditLimit = o.creditLimit !== undefined ? o.creditLimit : 99;
  sim.selectedCount = 0;
  sim.selectedStudents = new Set();
  sim.slotsTotal = o.slotsTotal !== undefined ? o.slotsTotal : 1;
  sim.signedCount = 0;
  sim.signedStudents = new Set();
  sim.courseRelease = null;
  sim.projectRelease = null;
  sim.log = [];
  acquireCourse = makeMutex();
  acquireProject = makeMutex();
}
reset();

function rows(arr) {
  return { rows: arr, rowCount: arr.length };
}

// COMMIT / ROLLBACK 时释放本事务持有的行锁，放行下一个临界区。
function releaseLocks() {
  if (sim.courseRelease) { const r = sim.courseRelease; sim.courseRelease = null; r(); }
  if (sim.projectRelease) { const r = sim.projectRelease; sim.projectRelease = null; r(); }
}

async function runQuery(sql, params) {
  const text = String(sql);
  sim.log.push(text);
  const head = text.trim();
  if (/^BEGIN\b/i.test(head)) { return rows([]); }
  if (/^(COMMIT|ROLLBACK)\b/i.test(head)) { releaseLocks(); return rows([]); }

  // ---- 选课事务 ----
  if (/FROM dtest2\.selection_rounds/.test(text)) {
    return rows([{ round_id: 'r1', credit_limit: sim.creditLimit }]);
  }
  if (/FROM dtest2\.courses WHERE course_id=\$1 FOR UPDATE/.test(text)) {
    if (sim.serialize) {
      // 持有课程行锁直到 COMMIT/ROLLBACK：序列化下方 COUNT→INSERT 临界区。
      sim.courseRelease = await acquireCourse();
    }
    return rows([Object.assign({}, sim.course)]);
  }
  if (/SELECT status FROM dtest2\.selections WHERE student_id/.test(text)) {
    return rows(sim.selectedStudents.has(params[0]) ? [{ status: 'selected' }] : []);
  }
  if (/COUNT\(\*\)::int AS n FROM dtest2\.selections/.test(text)) {
    // 序列化下读到的是已提交的活计数；非序列化下读到事务开始快照(0)。
    return rows([{ n: sim.serialize ? sim.selectedCount : 0 }]);
  }
  if (/FROM dtest2\.selections s/.test(text)) {
    return rows([]); // 每个学生本轮只选这一门 → 无其它已选 → 学分/时间冲突校验恒通过
  }
  if (/INSERT INTO dtest2\.selections/.test(text)) {
    const sid = params[1];
    if (!sim.selectedStudents.has(sid)) { sim.selectedStudents.add(sid); sim.selectedCount += 1; }
    return rows([]);
  }

  // ---- 实践报名事务 ----
  if (/FROM dtest2\.practice_projects WHERE project_id=\$1 FOR UPDATE/.test(text)) {
    if (sim.serialize) {
      sim.projectRelease = await acquireProject();
    }
    return rows([{ slots_total: sim.slotsTotal }]);
  }
  if (/SELECT status FROM dtest2\.practice_signups WHERE project_id/.test(text)) {
    return rows(sim.signedStudents.has(params[1]) ? [{ status: 'signedUp' }] : []);
  }
  if (/COUNT\(\*\)::int AS n FROM dtest2\.practice_signups/.test(text)) {
    return rows([{ n: sim.serialize ? sim.signedCount : 0 }]);
  }
  if (/INSERT INTO dtest2\.practice_signups/.test(text)) {
    const sid = params[1];
    if (!sim.signedStudents.has(sid)) { sim.signedStudents.add(sid); sim.signedCount += 1; }
    return rows([]);
  }
  if (/FROM dtest2\.practice_projects p/.test(text)) {
    // 报名成功后 pool.query 回查项目行：返回最小可 map 的有效行，避免 mapPractice 取 undefined。
    return rows([{
      project_id: 'p1', title: '社区服务', org: '校团委', category: '志愿', credits: 1,
      period: '2026 春', location: '', mentor: '', slots_total: sim.slotsTotal,
      slots_taken: sim.signedCount, description: '', requirements_json: [], signed_up: true
    }]);
  }

  return rows([]);
}

const client = { query: (s, p) => runQuery(s, p), release: () => undefined };
const pool = { query: (s, p) => runQuery(s, p), connect: async () => client };

module.exports = {
  pool,
  __sim: {
    reset,
    state: sim,
    executed: (fragment) => sim.log.some((s) => s.indexOf(fragment) >= 0)
  }
};
