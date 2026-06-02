// 密码哈希：SHA-256(salt + ":" + SHA-256(password))，与 App 端 AccountStore 方案一致。
// 演示用途；生产建议改 bcrypt/scrypt/argon2。
const crypto = require('crypto');

function sha256Hex(text) {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

function genSalt() {
  return crypto.randomBytes(16).toString('hex');
}

function hashPassword(password, salt) {
  return sha256Hex(salt + ':' + sha256Hex(password));
}

function verifyPassword(password, salt, hash) {
  const computed = hashPassword(password, salt);
  const expected = hash || '';
  if (computed.length !== expected.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(expected));
}

module.exports = { sha256Hex, genSalt, hashPassword, verifyPassword };
