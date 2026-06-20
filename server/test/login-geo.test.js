// 登录历史「地点/时长」（roadmap #5）：
//  - geo 辅助模块 resolveGeo：回环返回 ''；已知公网 IP 返回非空「省·市」串（直接对打包 xdb 单测）。
//  - POST /api/auth/logout（authRequired）：200 且经审计中间件落一条 logout 行（断言 INSERT 命中）。
//  - GET /api/profile/login-history：location 映射自 geo 列；durationMinutes 由 login+logout 配对算出。
//  - 无 token → 401。
jest.mock('../src/db', () => require('./helpers/dbMock'));

const request = require('supertest');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');
const { resolveGeo } = require('../src/geo');
const app = require('../src/index');

const STU = '2023001';
const auth = `Bearer ${signToken({ sub: STU, role: 'student' })}`;

// 审计写入在响应 finish 后异步执行，且 geo 解析为 async，等一个短 tick 再断言。
const tick = () => new Promise((resolve) => setTimeout(resolve, 50));

beforeEach(() => __mock.reset());

describe('geo.resolveGeo（离线 ip2region）', () => {
  test('回环/私网 IP → 空串', async () => {
    expect(await resolveGeo('127.0.0.1')).toBe('');
    expect(await resolveGeo('::1')).toBe('');
    expect(await resolveGeo('192.168.1.10')).toBe('');
    expect(await resolveGeo('10.0.0.1')).toBe('');
    expect(await resolveGeo('')).toBe('');
    expect(await resolveGeo('not-an-ip')).toBe('');
  });

  test('已知公网 IP → 非空「省·市」串（来自打包 xdb）', async () => {
    // 114.114.114.114（南京公共 DNS）与 1.2.4.8（中国互联网络信息中心）均为已知中国大陆公网 IP。
    const a = await resolveGeo('114.114.114.114');
    const b = await resolveGeo('1.2.4.8');
    const got = a || b;
    expect(typeof got).toBe('string');
    expect(got.length).toBeGreaterThan(0);
    // 不应残留 ip2region 的 '0' 占位与竖线分隔符
    expect(got).not.toContain('|');
    expect(got).not.toContain('0|');
  });
});

describe('POST /api/auth/logout', () => {
  test('200 且写入一条 logout 审计行', async () => {
    const res = await request(app).post('/api/auth/logout').set('Authorization', auth);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    await tick();
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.audit_logs') >= 0);
    expect(ins).toBeDefined();
    expect(ins.params).toContain('退出登录'); // action 文案
    expect(ins.params).toContain('logout');   // action_type
    expect(ins.params).toContain(STU);         // operator_id 取自 JWT
  });

  test('无 token → 401', async () => {
    const res = await request(app).post('/api/auth/logout');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});

describe('GET /api/profile/login-history（地点/时长）', () => {
  test('location 映射自 geo；durationMinutes 由 login+logout 配对算出', async () => {
    // 升序：login(10:00) → logout(10:45) → login(12:00, 无后续 logout)
    __mock.setRoutes([
      {
        match: /FROM dtest2\.audit_logs/,
        result: [
          { log_id: 'l1', action: '登录', action_type: 'login', result: 'success', ip: '1.2.3.4', geo: '江西省·景德镇市', created_at: '2026-06-19T10:00:00Z' },
          { log_id: 'o1', action: '退出登录', action_type: 'logout', result: 'success', ip: '1.2.3.4', geo: '江西省·景德镇市', created_at: '2026-06-19T10:45:00Z' },
          { log_id: 'l2', action: '登录', action_type: 'login', result: 'success', ip: '5.6.7.8', geo: '', created_at: '2026-06-19T12:00:00Z' }
        ]
      }
    ]);

    const res = await request(app).get('/api/profile/login-history').set('Authorization', auth);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const data = res.body.data;
    // 仅 login 行进入结果，倒序：最近一条 l2 在前
    expect(data).toHaveLength(2);
    expect(data[0].id).toBe('l2');
    expect(data[0].location).toBe('');
    expect(data[0].durationMinutes).toBeNull(); // 无后续 logout

    expect(data[1].id).toBe('l1');
    expect(data[1].location).toBe('江西省·景德镇市'); // 映射自 geo
    expect(data[1].durationMinutes).toBe(45);        // 10:45 - 10:00 = 45 分钟
    // 查询取 login+logout 两类用于配对
    expect(__mock.executed("action_type IN ('login', 'logout')")).toBe(true);
  });

  test('无 token → 401', async () => {
    const res = await request(app).get('/api/profile/login-history');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});
