'use strict';
// 主键 ID 生成：用 crypto.randomUUID 的随机性替代裸 Date.now()，
// 杜绝并发同毫秒生成相同 ID 导致的主键冲突（500）。形如 'lv-<uuid>'。
const crypto = require('crypto');

function genId(prefix) {
  return `${prefix}-${crypto.randomUUID()}`;
}

module.exports = { genId };
