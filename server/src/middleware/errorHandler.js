'use strict';
// 统一 500 处理：完整错误（含堆栈）记入服务端日志（pm2 可查），客户端只收通用文案，
// 不把 e.message 回给客户端，避免泄露 DB 约束名 / 连接串 / 内部实现等敏感细节。

const { fail } = require('../envelope');

function serverError(res, label, e, code) {
  console.error(`[dtest2-api] ${label}:`, (e && e.stack) ? e.stack : e);
  return res.status(500).json(fail(`${label}，请稍后重试`, code));
}

module.exports = { serverError };
