'use strict';

function makeResponse() {
  return {
    headers: {},
    statusCode: undefined,
    body: undefined,
    set: jest.fn(function setHeader(name, value) {
      this.headers[name] = value;
      return this;
    }),
    status: jest.fn(function setStatus(code) {
      this.statusCode = code;
      return this;
    }),
    json: jest.fn(function sendJson(body) {
      this.body = body;
      return this;
    })
  };
}

describe('createRateLimiter', () => {
  let createRateLimiter;

  beforeEach(() => {
    jest.resetModules();
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-06-09T00:00:00.000Z'));
    ({ createRateLimiter } = require('../src/middleware/rateLimit'));
  });

  afterEach(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
    jest.resetModules();
  });

  test('allows requests until the max is exceeded and returns retry metadata', () => {
    const limiter = createRateLimiter(1000, 1);
    const firstRes = makeResponse();
    const secondRes = makeResponse();
    const firstNext = jest.fn();
    const secondNext = jest.fn();

    limiter({ ip: '127.0.0.1' }, firstRes, firstNext);
    limiter({ ip: '127.0.0.1' }, secondRes, secondNext);

    expect(firstNext).toHaveBeenCalledTimes(1);
    expect(secondNext).not.toHaveBeenCalled();
    expect(secondRes.headers['Retry-After']).toBe('1');
    expect(secondRes.statusCode).toBe(429);
    expect(secondRes.body).toEqual({
      success: false,
      data: null,
      error: '请求过于频繁，请稍后再试',
      code: 'rate_limited'
    });
  });

  test('uses socket remote address and unknown fallback when req.ip is absent', () => {
    const limiter = createRateLimiter(1000, 1);
    const socketLimitedRes = makeResponse();
    const unknownLimitedRes = makeResponse();

    limiter({ socket: { remoteAddress: '10.0.0.8' } }, makeResponse(), jest.fn());
    limiter({ socket: { remoteAddress: '10.0.0.8' } }, socketLimitedRes, jest.fn());
    limiter({}, makeResponse(), jest.fn());
    limiter({}, unknownLimitedRes, jest.fn());

    expect(socketLimitedRes.statusCode).toBe(429);
    expect(unknownLimitedRes.statusCode).toBe(429);
  });

  test('resets counters after the fixed window elapses', () => {
    const limiter = createRateLimiter(1000, 1);
    const firstNext = jest.fn();
    const afterResetNext = jest.fn();

    limiter({ ip: '192.168.1.1' }, makeResponse(), firstNext);
    jest.advanceTimersByTime(1000);
    limiter({ ip: '192.168.1.1' }, makeResponse(), afterResetNext);

    expect(firstNext).toHaveBeenCalledTimes(1);
    expect(afterResetNext).toHaveBeenCalledTimes(1);
  });
});
