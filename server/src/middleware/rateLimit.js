'use strict';
// P2-01：极简内存级限流（单进程 fork 模式足够，无需新依赖）。固定窗口、按 IP 计数。
// 阈值在本模块加载时按 env 固化（与原 index.js 行为一致）——测试须在 require('../src/index') 之前设好 env。

const { fail } = require('../envelope');

function createRateLimiter(windowMs, max) {
  const hits = new Map();
  const timer = setInterval(() => {
    const now = Date.now();
    for (const [key, rec] of hits) {
      if (now >= rec.resetAt) hits.delete(key);
    }
  }, windowMs);
  if (timer.unref) timer.unref();
  return (req, res, next) => {
    const ip = req.ip || (req.socket && req.socket.remoteAddress) || 'unknown';
    const now = Date.now();
    let rec = hits.get(ip);
    if (!rec || now >= rec.resetAt) {
      rec = { count: 0, resetAt: now + windowMs };
      hits.set(ip, rec);
    }
    rec.count += 1;
    if (rec.count > max) {
      res.set('Retry-After', String(Math.ceil((rec.resetAt - now) / 1000)));
      return res.status(429).json(fail('请求过于频繁，请稍后再试', 'rate_limited'));
    }
    next();
  };
}

const RL_WINDOW_MS = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const RL_GLOBAL_MAX = parseInt(process.env.RATE_LIMIT_MAX || '300', 10);
const RL_AUTH_MAX = parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10', 10);
const globalLimiter = createRateLimiter(RL_WINDOW_MS, RL_GLOBAL_MAX);
const authLimiter = createRateLimiter(RL_WINDOW_MS, RL_AUTH_MAX);

module.exports = { createRateLimiter, globalLimiter, authLimiter };
