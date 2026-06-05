// 并发压力测试：N 人同抢有限名额，验证行锁（SELECT ... FOR UPDATE）使最终落库数 ≤ 容量。
// 区别于 selections.test.js 仅断言「SQL 里有 FOR UPDATE」——这里用有状态 mock
// （helpers/concurrencyDbMock）忠实复刻行锁对临界区的序列化，跑真正的 Promise.all 并发，
// 断言「恰好 capacity 人成功、落库数不超容量」，把「锁存在」升级为「真实压力下不超卖」。
jest.mock('../src/db', () => require('./helpers/concurrencyDbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __sim } = require('./helpers/concurrencyDbMock');
const { signToken } = require('../src/auth');

// 生成 n 个学号互不相同的学生 token（避免 dup 校验把同一人当重复选课）。
function studentTokens(n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push(signToken({ sub: `stu-${i}`, role: 'student' }));
  }
  return out;
}

function countStatus(results, code) {
  return results.filter((r) => r.status === code).length;
}

function selectAll(tokens, courseId) {
  return Promise.all(tokens.map((t) =>
    request(app).post('/api/selections').set('Authorization', `Bearer ${t}`).send({ courseId })
  ));
}

function signupAll(tokens, projectId) {
  return Promise.all(tokens.map((t) =>
    request(app).post(`/api/practice/${projectId}/signup`).set('Authorization', `Bearer ${t}`).send({})
  ));
}

const CONTENDERS = 20;

describe('并发选课：FOR UPDATE 防超容量', () => {
  test('20 人同抢 1 个名额 → 仅 1 人成功，落库数=1 不超容量', async () => {
    __sim.reset({ course: { capacity: 1 } });
    const results = await selectAll(studentTokens(CONTENDERS), 'c1');

    expect(countStatus(results, 200)).toBe(1);
    expect(countStatus(results, 409)).toBe(CONTENDERS - 1);
    expect(__sim.state.selectedCount).toBe(1);
    expect(__sim.state.selectedCount).toBeLessThanOrEqual(1);
    // 每个并发请求都对课程行执行了 FOR UPDATE 行锁
    expect(__sim.executed('FOR UPDATE')).toBe(true);
    // 落败者全部拿到「容量已满」
    const losers = results.filter((r) => r.status === 409);
    expect(losers.every((r) => /已满/.test(r.body.error))).toBe(true);
  });

  test('20 人同抢 5 个名额 → 恰好 5 人成功，落库数=5 不超容量', async () => {
    __sim.reset({ course: { capacity: 5 } });
    const results = await selectAll(studentTokens(CONTENDERS), 'c1');

    expect(countStatus(results, 200)).toBe(5);
    expect(countStatus(results, 409)).toBe(CONTENDERS - 5);
    expect(__sim.state.selectedCount).toBe(5);
    expect(__sim.state.selectedCount).toBeLessThanOrEqual(5);
  });

  test('非退化对照：去掉 FOR UPDATE 序列化 → 同样 20 并发会超容量（证明锁是关键，断言非恒真）', async () => {
    __sim.reset({ course: { capacity: 1 }, serialize: false });
    const results = await selectAll(studentTokens(CONTENDERS), 'c1');

    // 无锁 + 各事务读到陈旧快照 → 全部通过容量校验 → 落库数远超容量上限
    expect(__sim.state.selectedCount).toBeGreaterThan(1);
    expect(countStatus(results, 200)).toBe(CONTENDERS);
  });
});

describe('并发实践报名：FOR UPDATE 防超名额', () => {
  test('20 人同抢 1 个名额 → 仅 1 人成功，已报数=1 不超名额', async () => {
    __sim.reset({ slotsTotal: 1 });
    const results = await signupAll(studentTokens(CONTENDERS), 'p1');

    expect(countStatus(results, 200)).toBe(1);
    expect(countStatus(results, 409)).toBe(CONTENDERS - 1);
    expect(__sim.state.signedCount).toBe(1);
    expect(__sim.state.signedCount).toBeLessThanOrEqual(1);
    expect(__sim.executed('FOR UPDATE')).toBe(true);
    const losers = results.filter((r) => r.status === 409);
    expect(losers.every((r) => /名额已满/.test(r.body.error))).toBe(true);
  });

  test('20 人同抢 3 个名额 → 恰好 3 人成功，已报数=3 不超名额', async () => {
    __sim.reset({ slotsTotal: 3 });
    const results = await signupAll(studentTokens(CONTENDERS), 'p1');

    expect(countStatus(results, 200)).toBe(3);
    expect(countStatus(results, 409)).toBe(CONTENDERS - 3);
    expect(__sim.state.signedCount).toBe(3);
    expect(__sim.state.signedCount).toBeLessThanOrEqual(3);
  });
});
