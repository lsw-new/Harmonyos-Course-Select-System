'use strict';

jest.mock('../src/db', () => require('./helpers/dbMock'));

const { __mock } = require('./helpers/dbMock');

function restoreEnvValue(name, value) {
  if (value === undefined) {
    delete process.env[name];
    return;
  }
  process.env[name] = value;
}

function makeResponse() {
  return {
    statusCode: undefined,
    body: undefined,
    headers: {},
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

describe('core utility branches', () => {
  beforeEach(() => {
    __mock.reset();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('response envelopes default undefined success data to null', () => {
    const { ok, fail } = require('../src/envelope');

    expect(ok()).toEqual({ success: true, data: null, error: null });
    expect(ok({ id: 'x' })).toEqual({ success: true, data: { id: 'x' }, error: null });
    expect(fail('失败', 'bad_request')).toEqual({
      success: false,
      data: null,
      error: '失败',
      code: 'bad_request'
    });
  });

  test('identity reads the student id from JWT auth and falls back to empty string', () => {
    const { currentStudentId } = require('../src/identity');

    expect(currentStudentId({ auth: { sub: 2023307020941 } })).toBe('2023307020941');
    expect(currentStudentId({ auth: {} })).toBe('');
    expect(currentStudentId({})).toBe('');
  });

  test('legacy password verification rejects hashes with mismatched length before timing-safe comparison', () => {
    const { hashPassword, verifyLegacy, isBcryptHash, verifyPassword } = require('../src/hash');
    const salt = 'fixed-salt';
    const hash = hashPassword('secret', salt);

    expect(verifyLegacy('secret', salt, hash)).toBe(true);
    expect(verifyLegacy('secret', salt, 'short')).toBe(false);
    expect(isBcryptHash('$2b$10$abcdefghijklmnopqrstuv123456789012345678901234567890')).toBe(true);
    expect(isBcryptHash(null)).toBe(false);
    return expect(verifyPassword('secret', salt, hash)).resolves.toBe(true);
  });

  test('serverError logs non-stack errors and returns a sanitized 500 envelope', () => {
    const { serverError } = require('../src/middleware/errorHandler');
    const logger = require('../src/logger');
    const res = makeResponse();
    // serverError 现经结构化 logger.error 记录（label + stack 入 meta），替代旧 console.error。
    const errSpy = jest.spyOn(logger, 'error');

    serverError(res, '测试失败', 'plain-error', 'server_error');

    expect(errSpy).toHaveBeenCalledWith('测试失败', { stack: 'plain-error' });
    errSpy.mockRestore();
    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({
      success: false,
      data: null,
      error: '测试失败，请稍后重试',
      code: 'server_error'
    });
  });

  test('permissionRequired returns sanitized server error when permission lookup fails', async () => {
    const { signToken } = require('../src/auth');
    const { permissionRequired } = require('../src/middleware/permission');
    const res = makeResponse();
    const next = jest.fn();

    __mock.setRoutes([{ match: /FROM dtest2\.admin_profiles ap/, result: new Error('db unavailable') }]);

    permissionRequired('students.manage:view')(
      { headers: { authorization: `Bearer ${signToken({ sub: 'A1', role: 'admin' })}` } },
      res,
      next
    );
    await Promise.resolve();

    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({
      success: false,
      data: null,
      error: '权限校验失败，请稍后重试',
      code: 'server_error'
    });
  });

  test('rate limiters use default env values and tolerate timers without unref', () => {
    const originalEnv = {
      RATE_LIMIT_WINDOW_MS: process.env.RATE_LIMIT_WINDOW_MS,
      RATE_LIMIT_MAX: process.env.RATE_LIMIT_MAX,
      AUTH_RATE_LIMIT_MAX: process.env.AUTH_RATE_LIMIT_MAX
    };

    try {
      delete process.env.RATE_LIMIT_WINDOW_MS;
      delete process.env.RATE_LIMIT_MAX;
      delete process.env.AUTH_RATE_LIMIT_MAX;
      jest.spyOn(global, 'setInterval').mockImplementation(() => ({}));

      const { authLimiter } = require('../src/middleware/rateLimit');
      const req = { ip: 'default-env-ip' };

      for (let i = 0; i < 10; i += 1) {
        authLimiter(req, makeResponse(), jest.fn());
      }
      const limitedRes = makeResponse();
      authLimiter(req, limitedRes, jest.fn());

      expect(limitedRes.statusCode).toBe(429);
    } finally {
      restoreEnvValue('RATE_LIMIT_WINDOW_MS', originalEnv.RATE_LIMIT_WINDOW_MS);
      restoreEnvValue('RATE_LIMIT_MAX', originalEnv.RATE_LIMIT_MAX);
      restoreEnvValue('AUTH_RATE_LIMIT_MAX', originalEnv.AUTH_RATE_LIMIT_MAX);
      jest.resetModules();
    }
  });
});
