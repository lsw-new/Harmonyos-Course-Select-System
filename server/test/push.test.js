// 推送通知域（roadmap #8）：设备 token 注册/注销 + sweeper + dispatch 无配置跳过。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const other = `Bearer ${signToken({ sub: '2023307099999', role: 'student' })}`;

beforeEach(() => __mock.reset());

// ---- POST /api/push/tokens ----

describe('POST /api/push/tokens', () => {
  test('未授权 → 401', async () => {
    const res = await request(app).post('/api/push/tokens').send({ token: 'tok1', platform: 'android' });
    expect(res.status).toBe(401);
  });

  test('缺 token → 400', async () => {
    const res = await request(app)
      .post('/api/push/tokens')
      .set('Authorization', stu)
      .send({ platform: 'android' });
    expect(res.status).toBe(400);
  });

  test('正常注册 → 200 + registered:true，UPSERT 按 JWT 学号收口', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.device_tokens/, result: [] }
    ]);
    const res = await request(app)
      .post('/api/push/tokens')
      .set('Authorization', stu)
      .send({ token: 'hms-device-token-abc', platform: 'android' });
    expect(res.status).toBe(200);
    expect(res.body.data.registered).toBe(true);

    // 防 IDOR：INSERT 使用 JWT 学号，不信任 body 中的 studentId
    const q = __mock.getLog().find((e) => e.sql.includes('INSERT INTO dtest2.device_tokens'));
    expect(q).toBeDefined();
    expect(q.params).toContain('2023307020941');    // JWT 学号
    expect(q.params).toContain('hms-device-token-abc');
    expect(q.params).toContain('android');
  });

  test('不同学生注册同 token 各自收口（IDOR 隔离）', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.device_tokens/, result: [] }
    ]);
    const res1 = await request(app)
      .post('/api/push/tokens')
      .set('Authorization', stu)
      .send({ token: 'shared-tok', platform: 'ios' });
    const res2 = await request(app)
      .post('/api/push/tokens')
      .set('Authorization', other)
      .send({ token: 'shared-tok', platform: 'ios' });
    expect(res1.status).toBe(200);
    expect(res2.status).toBe(200);

    const inserts = __mock.getLog().filter((e) => e.sql.includes('INSERT INTO dtest2.device_tokens'));
    expect(inserts).toHaveLength(2);
    // 两次插入的 student_id 各不相同
    expect(inserts[0].params[1]).toBe('2023307020941');
    expect(inserts[1].params[1]).toBe('2023307099999');
  });
});

// ---- DELETE /api/push/tokens ----

describe('DELETE /api/push/tokens', () => {
  test('未授权 → 401', async () => {
    const res = await request(app).delete('/api/push/tokens').send({ token: 'tok1' });
    expect(res.status).toBe(401);
  });

  test('缺 token → 400', async () => {
    const res = await request(app)
      .delete('/api/push/tokens')
      .set('Authorization', stu)
      .send({});
    expect(res.status).toBe(400);
  });

  test('正常注销 → 200 + removed 条数，仅删当前学生的 token', async () => {
    __mock.setRoutes([
      { match: /DELETE FROM dtest2\.device_tokens/, result: [{}] }
    ]);
    const res = await request(app)
      .delete('/api/push/tokens')
      .set('Authorization', stu)
      .send({ token: 'hms-device-token-abc' });
    expect(res.status).toBe(200);
    expect(res.body.data.removed).toBe(1);

    const q = __mock.getLog().find((e) => e.sql.includes('DELETE FROM dtest2.device_tokens'));
    expect(q).toBeDefined();
    // 防 IDOR：DELETE 同时按 student_id（JWT）和 token 过滤
    expect(q.params[0]).toBe('2023307020941');
    expect(q.params[1]).toBe('hms-device-token-abc');
  });

  test('token 不存在 → 200 + removed:0（幂等）', async () => {
    __mock.setRoutes([
      { match: /DELETE FROM dtest2\.device_tokens/, result: [] }
    ]);
    const res = await request(app)
      .delete('/api/push/tokens')
      .set('Authorization', stu)
      .send({ token: 'nonexistent' });
    expect(res.status).toBe(200);
    expect(res.body.data.removed).toBe(0);
  });
});

// ---- dispatchToStudent：无配置时跳过，不发网络请求 ----

describe('dispatchToStudent（未配置 PUSH_DRIVER）', () => {
  test('PUSH_DRIVER 未设置 → status:skipped，不查 device_tokens，不发网络', async () => {
    // 确保环境变量未设置（NODE_ENV=test 下默认如此）
    const oldDriver = process.env.PUSH_DRIVER;
    delete process.env.PUSH_DRIVER;

    const { dispatchToStudent } = require('../src/push');
    const fakeDb = { query: jest.fn() };
    const result = await dispatchToStudent(fakeDb, 'S1', { title: '测试', body: '内容' });

    expect(result.status).toBe('skipped');
    expect(fakeDb.query).not.toHaveBeenCalled(); // 未查 device_tokens

    process.env.PUSH_DRIVER = oldDriver;
  });

  test('PUSH_DRIVER=hms 但无设备 token → status:skipped', async () => {
    process.env.PUSH_DRIVER = 'hms';
    process.env.HMS_PUSH_APP_ID = 'app123';
    process.env.HMS_PUSH_CLIENT_ID = 'cli123';
    process.env.HMS_PUSH_CLIENT_SECRET = 'sec123';

    const { dispatchToStudent } = require('../src/push');
    const fakeDb = { query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }) };
    const result = await dispatchToStudent(fakeDb, 'S_NO_TOKEN', { title: '测试', body: '内容' });

    expect(result.status).toBe('skipped');

    delete process.env.PUSH_DRIVER;
    delete process.env.HMS_PUSH_APP_ID;
    delete process.env.HMS_PUSH_CLIENT_ID;
    delete process.env.HMS_PUSH_CLIENT_SECRET;
  });
});

// ---- sweepAndPush：标记 pushed_at ----

describe('sweepAndPush', () => {
  test('无待推送消息 → 不执行 UPDATE', async () => {
    const { sweepAndPush } = require('../src/push');
    const fakeDb = {
      query: jest.fn()
        .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // SELECT pushed_at IS NULL
    };
    await sweepAndPush(fakeDb);
    // 只有一次 SELECT，没有 UPDATE
    expect(fakeDb.query).toHaveBeenCalledTimes(1);
    expect(fakeDb.query.mock.calls[0][0]).toMatch(/WHERE pushed_at IS NULL/);
  });

  test('有待推送消息（无配置）→ 每条都标记 pushed_at，即使 dispatch=skipped', async () => {
    const oldDriver = process.env.PUSH_DRIVER;
    delete process.env.PUSH_DRIVER;

    const { sweepAndPush } = require('../src/push');
    const rows = [
      { message_id: 'msg-1', student_id: 'S1', title: 'T1', body: 'B1', route: '', param: '' },
      { message_id: 'msg-2', student_id: 'S2', title: 'T2', body: 'B2', route: '', param: '' },
    ];
    const fakeDb = {
      query: jest.fn()
        .mockResolvedValueOnce({ rows, rowCount: rows.length }) // SELECT
        .mockResolvedValue({ rows: [], rowCount: 1 })            // UPDATE × N
    };
    await sweepAndPush(fakeDb);

    // SELECT once + UPDATE once per message
    expect(fakeDb.query).toHaveBeenCalledTimes(1 + rows.length);
    const updates = fakeDb.query.mock.calls.slice(1);
    expect(updates[0][0]).toMatch(/UPDATE dtest2\.messages SET pushed_at = now\(\)/);
    expect(updates[0][1]).toEqual(['msg-1']);
    expect(updates[1][1]).toEqual(['msg-2']);

    process.env.PUSH_DRIVER = oldDriver;
  });

  test('sweepAndPush 不向调用方抛出（DB 异常被吞）', async () => {
    const { sweepAndPush } = require('../src/push');
    const fakeDb = {
      query: jest.fn().mockRejectedValue(new Error('DB down'))
    };
    await expect(sweepAndPush(fakeDb)).resolves.toBeUndefined();
  });
});
