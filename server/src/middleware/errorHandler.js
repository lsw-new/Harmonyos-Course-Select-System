'use strict';
// 统一 500 处理：完整错误（含堆栈）记入服务端日志（pm2 可查），客户端只收通用文案，
// 不把 e.message 回给客户端，避免泄露 DB 约束名 / 连接串 / 内部实现等敏感细节。

const { fail } = require('../envelope');

function serverError(res, label, e, code) {
  console.error(`[dtest2-api] ${label}:`, (e && e.stack) ? e.stack : e);
  return res.status(500).json(fail(`${label}，请稍后重试`, code));
}

// pg 约束类错误的「安全文案」映射：只按错误码回固定中文，绝不把 e.message 原文
// （含表名/约束名/列名等 schema 细节）回给客户端，防止数据库结构被探测。
const PG_SAFE_MESSAGES = {
  '23505': '数据已存在（唯一约束冲突）',
  '23503': '关联数据不存在或正被引用（外键约束）',
  '23502': '缺少必填字段（非空约束）',
  '23514': '数据不符合约束条件',
  '22001': '字段内容超出长度限制',
  '22003': '数值超出允许范围',
  '22007': '日期/时间格式不正确',
  '22P02': '数据格式不正确',
};

// 用于「按行 CRUD / 课程写入」等用户可直接纠正的场景：客户端收到分类后的安全文案，
// 完整错误仍记入服务端日志便于排查。非约束类错误（无 e.code）交回 serverError 走 500。
function pgClientError(res, label, e) {
  if (e && e.code && PG_SAFE_MESSAGES[e.code]) {
    console.error(`[dtest2-api] ${label} (pg ${e.code}):`, e.message);
    return res.status(400).json(fail(`${label}：${PG_SAFE_MESSAGES[e.code]}`));
  }
  if (e && e.code) {
    console.error(`[dtest2-api] ${label} (pg ${e.code}):`, e.message);
    return res.status(400).json(fail(`${label}，请检查输入数据`));
  }
  return serverError(res, label, e);
}

module.exports = { serverError, pgClientError };
