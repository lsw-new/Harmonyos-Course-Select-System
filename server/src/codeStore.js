const crypto = require('crypto');

// 邮箱验证码存储（进程内存）。验证码短时有效，单实例 pm2 用内存足够；
// 进程重启即清空属可接受（验证码本就一次性、短期）。
const CODE_TTL_MS = 5 * 60 * 1000;       // 验证码有效期 5 分钟
const RESEND_INTERVAL_MS = 60 * 1000;    // 同一邮箱两次发码最小间隔 60 秒
const MAX_ATTEMPTS = 5;                   // 单个验证码最多校验 5 次

// email -> { code, expiresAt, sentAt, attempts }
const store = new Map();

function normalize(email) {
  return String(email || '').trim().toLowerCase();
}

// 节流检查：返回 { ok } 或 { ok:false, waitMs }
function canIssue(email) {
  const rec = store.get(normalize(email));
  if (rec) {
    const elapsed = Date.now() - rec.sentAt;
    if (elapsed < RESEND_INTERVAL_MS) {
      return { ok: false, waitMs: RESEND_INTERVAL_MS - elapsed };
    }
  }
  return { ok: true };
}

// 生成并存储 6 位验证码，返回明文（仅用于发邮件，不回传给客户端）。
function issue(email) {
  const code = String(crypto.randomInt(100000, 1000000));
  store.set(normalize(email), {
    code,
    expiresAt: Date.now() + CODE_TTL_MS,
    sentAt: Date.now(),
    attempts: 0
  });
  return code;
}

// 列出当前未过期验证码的元信息（供管理端监控）。
// 安全约束：不返回验证码明文——否则管理端可借码接管任意邮箱的注册/找回流程。
function list() {
  const now = Date.now();
  const out = [];
  for (const [email, rec] of store) {
    if (now > rec.expiresAt) { continue; }
    out.push({
      email,
      sentAt: rec.sentAt,
      expiresAt: rec.expiresAt,
      remainingMs: rec.expiresAt - now,
      attempts: rec.attempts,
      maxAttempts: MAX_ATTEMPTS
    });
  }
  out.sort((a, b) => b.sentAt - a.sentAt);
  return out;
}

// 校验验证码；成功即消费（一次性）。返回 { ok } 或 { ok:false, reason }
function verify(email, code) {
  const key = normalize(email);
  const rec = store.get(key);
  if (!rec) {
    return { ok: false, reason: '验证码不存在，请重新获取' };
  }
  if (Date.now() > rec.expiresAt) {
    store.delete(key);
    return { ok: false, reason: '验证码已过期，请重新获取' };
  }
  if (rec.attempts >= MAX_ATTEMPTS) {
    store.delete(key);
    return { ok: false, reason: '尝试次数过多，请重新获取验证码' };
  }
  rec.attempts += 1;
  if (String(code).trim() !== rec.code) {
    return { ok: false, reason: '验证码错误' };
  }
  store.delete(key);
  return { ok: true };
}

// 定期清理过期项，避免内存堆积；unref 不阻止进程退出。
const sweeper = setInterval(() => {
  const now = Date.now();
  for (const [key, rec] of store) {
    if (now > rec.expiresAt) {
      store.delete(key);
    }
  }
}, 60 * 1000);
if (typeof sweeper.unref === 'function') {
  sweeper.unref();
}

module.exports = { canIssue, issue, verify, list };
