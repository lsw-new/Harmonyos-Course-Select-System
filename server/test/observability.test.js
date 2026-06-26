// 运维可观测性：结构化日志 + 丰富健康检查。
// 覆盖 logger 三档输出与 formatLine 格式，丰富后的 /api/health 字段，
// 以及请求完成日志中间件随普通请求执行（test 下 logger 静默，不污染输出）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const logger = require('../src/logger');
const pkg = require('../package.json');

beforeEach(() => __mock.reset());

describe('GET /api/health（丰富健康检查）', () => {
  test('DB 可达 → 200 且 data 字段齐全', async () => {
    const now = new Date().toISOString();
    __mock.setRoutes([{ match: /SELECT now\(\)/, result: [{ now }] }]);

    const res = await request(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const d = res.body.data;
    expect(d.db).toBe('ok');
    expect(d.now).toBe(now);
    expect(typeof d.uptime).toBe('number');
    expect(d.uptime).toBeGreaterThanOrEqual(0);
    expect(d.version).toBe(pkg.version);
    expect(d.nodeEnv).toBe('test');
    expect(typeof d.time).toBe('string');
    expect(Number.isNaN(Date.parse(d.time))).toBe(false);
  });

  test('DB 失败 → 仍走 serverError 返回 500', async () => {
    __mock.setRoutes([{ match: /SELECT now\(\)/, result: new Error('db down') }]);
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });

  test('裸 /health 同样返回丰富字段', async () => {
    __mock.setRoutes([{ match: /SELECT now\(\)/, result: [{ now: new Date().toISOString() }] }]);
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.data.version).toBe(pkg.version);
    expect(typeof res.body.data.uptime).toBe('number');
  });
});

describe('logger.formatLine 格式', () => {
  test('单行：[dtest2-api] LEVEL ISO msg JSON', () => {
    const line = logger.formatLine('INFO', 'hello', { a: 1 });
    expect(line).toMatch(/^\[dtest2-api\] INFO \d{4}-\d{2}-\d{2}T[\d:.]+Z hello \{"a":1\}$/);
  });

  test('meta 省略时回退为 {}', () => {
    expect(logger.formatLine('WARN', 'x')).toMatch(/ x \{\}$/);
    expect(logger.formatLine('ERROR', 'y', null)).toMatch(/ y \{\}$/);
  });

  test('循环引用 meta 降级为 {} 而不抛错', () => {
    const cyclic = {};
    cyclic.self = cyclic;
    const line = logger.formatLine('INFO', 'cyc', cyclic);
    expect(line).toMatch(/ cyc \{\}$/);
  });
});

describe('logger.info/warn/error', () => {
  test('调用不抛错并返回拼装后的行（test 下静默不打印）', () => {
    expect(() => logger.info('i', { k: 'v' })).not.toThrow();
    expect(() => logger.warn('w')).not.toThrow();
    expect(() => logger.error('e', { stack: 'boom' })).not.toThrow();

    expect(logger.info('i', { k: 'v' })).toMatch(/\[dtest2-api\] INFO .* i \{"k":"v"\}$/);
    expect(logger.warn('w')).toMatch(/\[dtest2-api\] WARN .* w \{\}$/);
    expect(logger.error('e', { stack: 'boom' })).toMatch(/\[dtest2-api\] ERROR .* e \{"stack":"boom"\}$/);
  });
});

describe('请求完成日志中间件', () => {
  test('普通请求经过中间件不影响响应', async () => {
    __mock.setRoutes([{ match: /SELECT now\(\)/, result: [{ now: new Date().toISOString() }] }]);
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
