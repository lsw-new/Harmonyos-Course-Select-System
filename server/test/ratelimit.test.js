// 限流（P2-01）：登录端点的 authLimiter 超过阈值返回 429。
// 关键：必须在 require('../src/index') 之前下调阈值（限流器在模块加载时按 env 固化）。
process.env.AUTH_RATE_LIMIT_MAX = '3';
process.env.RATE_LIMIT_MAX = '1000000'; // 全局限流调高，避免干扰

jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');

describe('登录限流 authLimiter', () => {
  test('同一 IP 超过阈值后返回 429 + Retry-After', async () => {
    const statuses = [];
    for (let i = 0; i < 4; i++) {
      // 发空账号请求：限流中间件在业务校验之前执行，故计数照常累加（前 3 次落到 400，第 4 次被限流）
      const res = await request(app).post('/api/auth/login').send({ account: '', password: '' });
      statuses.push(res.status);
    }
    expect(statuses[0]).not.toBe(429);
    expect(statuses[3]).toBe(429);
    // 命中限流时应带 Retry-After 头
    const limited = await request(app).post('/api/auth/login').send({ account: '', password: '' });
    expect(limited.status).toBe(429);
    expect(limited.headers['retry-after']).toBeDefined();
  });
});
