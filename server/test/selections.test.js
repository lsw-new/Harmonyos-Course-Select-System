// 选课事务：审查问题3（学分上限/时间冲突）+ 问题4（行锁防并发超容量）的端到端分支覆盖。
// 用 mock 驱动事务中每一步查询，断言 HTTP 码、错误文案、是否提交/回滚、是否执行 FOR UPDATE。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const token = signToken({ sub: '2023307020941', role: 'student' });

// 构造一套覆盖事务全步骤的路由，允许按需覆盖某一步的返回。
function routes(overrides = {}) {
  const d = {
    round: [{ round_id: 'r1', credit_limit: 30 }],
    course: [{ capacity: 50, status: 'open', credit: 3, weekday: 1, period_start: 1, period_end: 2, weeks_text: '1-16' }],
    dup: [],
    count: [{ n: 0 }],
    selected: [],
    insert: []
  };
  const c = Object.assign({}, d, overrides);
  return [
    { match: /FROM dtest2\.selection_rounds/, result: c.round },
    { match: /FROM dtest2\.courses WHERE course_id=\$1 FOR UPDATE/, result: c.course },
    { match: /SELECT status FROM dtest2\.selections WHERE student_id/, result: c.dup },
    { match: /COUNT\(\*\)::int AS n FROM dtest2\.selections/, result: c.count },
    { match: /FROM dtest2\.selections s/, result: c.selected },
    { match: /INSERT INTO dtest2\.selections/, result: c.insert }
  ];
}

function selectCourse() {
  return request(app).post('/api/selections').set('Authorization', `Bearer ${token}`).send({ courseId: 'c1' });
}

beforeEach(() => __mock.reset());

describe('POST /api/selections', () => {
  test('正常选课 → 200 并提交事务', async () => {
    __mock.setRoutes(routes());
    const res = await selectCourse();
    expect(res.status).toBe(200);
    expect(res.body.data.selected).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
    expect(__mock.executed('ROLLBACK')).toBe(false);
  });

  test('问题4：选课对课程行加 FOR UPDATE 行锁', async () => {
    __mock.setRoutes(routes());
    await selectCourse();
    expect(__mock.executed('FOR UPDATE')).toBe(true);
  });

  test('无进行中轮次 → 409 且回滚', async () => {
    __mock.setRoutes(routes({ round: [] }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('选课时间');
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('课程不存在 → 404 且回滚', async () => {
    __mock.setRoutes(routes({ course: [] }));
    const res = await selectCourse();
    expect(res.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('课程未开放 → 409', async () => {
    __mock.setRoutes(routes({ course: [{ capacity: 50, status: 'closed', credit: 3, weekday: 1, period_start: 1, period_end: 2, weeks_text: '1-16' }] }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('未开放');
  });

  test('重复选课 → 409', async () => {
    __mock.setRoutes(routes({ dup: [{ status: 'selected' }] }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('已选');
  });

  test('容量已满 → 409', async () => {
    __mock.setRoutes(routes({ count: [{ n: 50 }] }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('已满');
  });

  test('问题3：超过学分上限 → 409', async () => {
    // 已选 28 学分，目标 3 学分，轮次上限 30 → 31 > 30
    __mock.setRoutes(routes({
      selected: [{ name: '高等数学', credit: 28, weekday: 5, period_start: 1, period_end: 2, weeks_text: '1-16' }]
    }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('学分上限');
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('问题3：与已选课程时间冲突 → 409 且含冲突课程名', async () => {
    // 已选课程与目标课程同为 周一 1-2 节 / 1-16 周 → 冲突
    __mock.setRoutes(routes({
      selected: [{ name: '大学物理', credit: 3, weekday: 1, period_start: 1, period_end: 2, weeks_text: '1-16' }]
    }));
    const res = await selectCourse();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('时间冲突');
    expect(res.body.error).toContain('大学物理');
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });
});
