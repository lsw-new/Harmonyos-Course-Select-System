'use strict';

describe('codeStore', () => {
  function loadStore() {
    jest.resetModules();
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-06-09T00:00:00.000Z'));
    return require('../src/codeStore');
  }

  afterEach(() => {
    jest.restoreAllMocks();
    jest.clearAllTimers();
    jest.useRealTimers();
    jest.resetModules();
  });

  test('issues a normalized six-digit code using a crypto-backed generator and consumes it after successful verification', () => {
    const crypto = require('crypto');
    jest.spyOn(crypto, 'randomInt').mockReturnValue(123456);
    const mathRandomSpy = jest.spyOn(Math, 'random');
    const codeStore = loadStore();

    const code = codeStore.issue('  USER@Example.COM  ');

    expect(code).toBe('123456');
    expect(crypto.randomInt).toHaveBeenCalledWith(100000, 1000000);
    expect(mathRandomSpy).not.toHaveBeenCalled();
    expect(codeStore.canIssue('user@example.com')).toEqual({ ok: false, waitMs: 60000 });
    expect(codeStore.verify('user@example.com', ' 123456 ')).toEqual({ ok: true });
    expect(codeStore.verify('user@example.com', '123456')).toEqual({
      ok: false,
      reason: '验证码不存在，请重新获取'
    });
  });

  test('allows issuing again after the resend interval elapses', () => {
    const codeStore = loadStore();

    expect(codeStore.canIssue('new@example.com')).toEqual({ ok: true });
    codeStore.issue('new@example.com');
    jest.advanceTimersByTime(59000);

    expect(codeStore.canIssue(' NEW@example.com ')).toEqual({ ok: false, waitMs: 1000 });

    jest.advanceTimersByTime(1000);

    expect(codeStore.canIssue('new@example.com')).toEqual({ ok: true });
  });

  test('tracks wrong-code attempts and deletes the code after the maximum attempts', () => {
    const codeStore = loadStore();
    codeStore.issue('retry@example.com');

    for (let i = 0; i < 5; i += 1) {
      expect(codeStore.verify('retry@example.com', '000000')).toEqual({
        ok: false,
        reason: '验证码错误'
      });
    }

    expect(codeStore.verify('retry@example.com', '000000')).toEqual({
      ok: false,
      reason: '尝试次数过多，请重新获取验证码'
    });
    expect(codeStore.verify('retry@example.com', '000000')).toEqual({
      ok: false,
      reason: '验证码不存在，请重新获取'
    });
  });

  test('rejects expired codes and removes stale records through the sweeper', () => {
    const codeStore = loadStore();
    codeStore.issue('expired@example.com');

    jest.advanceTimersByTime(5 * 60 * 1000 + 1);

    expect(codeStore.verify('expired@example.com', '100000')).toEqual({
      ok: false,
      reason: '验证码已过期，请重新获取'
    });

    codeStore.issue('swept@example.com');
    jest.advanceTimersByTime(6 * 60 * 1000);

    expect(codeStore.verify('swept@example.com', '100000')).toEqual({
      ok: false,
      reason: '验证码不存在，请重新获取'
    });
  });

  test('normalizes empty emails and tolerates sweepers without unref', () => {
    jest.resetModules();
    jest.spyOn(global, 'setInterval').mockImplementation(() => ({}));
    const codeStore = require('../src/codeStore');

    expect(codeStore.canIssue(null)).toEqual({ ok: true });
    expect(codeStore.verify(undefined, '100000')).toEqual({
      ok: false,
      reason: '验证码不存在，请重新获取'
    });
  });
});
