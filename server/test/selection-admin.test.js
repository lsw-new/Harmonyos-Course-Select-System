// 选课轮次管理：状态机流转（启动/暂停/结束=关闭选课）与起止时间编辑的权限、校验、流转分支覆盖。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

// 当前轮次状态 + 更新回显 两步查询的 mock 路由
function roundRoutes(currentStatus, nextStatus) {
  return [
    PERM_GRANT,
    { match: /SELECT status FROM dtest2\.selection_rounds WHERE round_id/, result: [{ status: currentStatus }] },
    {
      match: /UPDATE dtest2\.selection_rounds/,
      result: [{ round_id: 'r1', name: '2025-2026-2 选课', status: nextStatus, start_time: '2026-06-01 09:00', end_time: '2026-06-30 22:00' }]
    }
  ];
}

function putStatus(auth, status) {
  return request(app).put('/api/admin/selection/rounds/r1/status').set('Authorization', auth).send({ status });
}

function putTime(body) {
  return request(app).put('/api/admin/selection/rounds/r1/time').set('Authorization', adm).send(body);
}

beforeEach(() => __mock.reset());

describe('PUT /api/admin/selection/rounds/:id/status', () => {
  test('学生 → 403', async () => {
    const res = await putStatus(stu, 'ended');
    expect(res.status).toBe(403);
  });

  test('status 非法值 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await putStatus(adm, 'closed');
    expect(res.status).toBe(400);
  });

  test('轮次不存在 → 404', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /SELECT status FROM dtest2\.selection_rounds WHERE round_id/, result: [] }
    ]);
    const res = await putStatus(adm, 'ended');
    expect(res.status).toBe(404);
  });

  test('非法流转：已结束的轮次不能再启动 → 409', async () => {
    __mock.setRoutes(roundRoutes('ended', 'running'));
    const res = await putStatus(adm, 'running');
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('启动');
    expect(__mock.executed('UPDATE dtest2.selection_rounds')).toBe(false);
  });

  test('关闭选课：running → ended 落库并回显', async () => {
    __mock.setRoutes(roundRoutes('running', 'ended'));
    const res = await putStatus(adm, 'ended');
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('ended');
    expect(__mock.executed('UPDATE dtest2.selection_rounds')).toBe(true);
  });

  test('恢复选课：paused → running', async () => {
    __mock.setRoutes(roundRoutes('paused', 'running'));
    const res = await putStatus(adm, 'running');
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('running');
  });

  test('并发竞态：条件更新未命中（状态已被他人改掉）→ 409', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /SELECT status FROM dtest2\.selection_rounds WHERE round_id/, result: [{ status: 'running' }] },
      { match: /UPDATE dtest2\.selection_rounds/, result: [] }
    ]);
    const res = await putStatus(adm, 'paused');
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('刷新');
  });
});

describe('PUT /api/admin/selection/rounds/:id/time', () => {
  test('时间格式错误 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await putTime({ startTime: '2026/06/01 09:00', endTime: '2026-06-30 22:00' });
    expect(res.status).toBe(400);
  });

  test('开始不早于结束 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await putTime({ startTime: '2026-06-30 22:00', endTime: '2026-06-01 09:00' });
    expect(res.status).toBe(400);
  });

  test('格式合法但日历不存在的日期（2026-02-30）→ 400 不触库', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await putTime({ startTime: '2026-02-30 10:00', endTime: '2026-07-02 17:37' });
    expect(res.status).toBe(400);
    expect(__mock.executed('UPDATE dtest2.selection_rounds')).toBe(false);
  });

  test('不存在的时刻（25:00）→ 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await putTime({ startTime: '2026-06-01 25:00', endTime: '2026-07-02 17:37' });
    expect(res.status).toBe(400);
  });

  test('已结束轮次 → 409', async () => {
    __mock.setRoutes(roundRoutes('ended', 'ended'));
    const res = await putTime({ startTime: '2026-06-01 09:00', endTime: '2026-06-30 22:00' });
    expect(res.status).toBe(409);
  });

  test('正常修改 → 200 回显新时间', async () => {
    __mock.setRoutes(roundRoutes('running', 'running'));
    const res = await putTime({ startTime: '2026-06-01 09:00', endTime: '2026-06-30 22:00' });
    expect(res.status).toBe(200);
    expect(res.body.data.startTime).toBe('2026-06-01 09:00');
    expect(__mock.executed('UPDATE dtest2.selection_rounds')).toBe(true);
  });
});
