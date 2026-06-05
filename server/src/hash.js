// 密码哈希：新口令用 bcrypt（P2-01 收尾，缓解离线撞库）；旧 SHA-256 账号登录时惰性迁移。
// 旧方案 SHA-256(salt + ":" + SHA-256(password)) 保留用于校验存量账号与 App 端本地兜底。
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const BCRYPT_ROUNDS = 10;

function sha256Hex(text) {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

function genSalt() {
  return crypto.randomBytes(16).toString('hex');
}

// 旧方案哈希（保留：校验存量账号 + seed.js + App 端本地兜底同方案）
function hashPassword(password, salt) {
  return sha256Hex(salt + ':' + sha256Hex(password));
}

function verifyLegacy(password, salt, hash) {
  const computed = hashPassword(password, salt);
  const expected = hash || '';
  if (computed.length !== expected.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(expected));
}

// 新口令一律 bcrypt（自带盐，存 password_hash，salt 列置空）
async function hashBcrypt(password) {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

function isBcryptHash(hash) {
  return typeof hash === 'string' && hash.indexOf('$2') === 0;
}

// 双轨校验：bcrypt 哈希走 bcrypt.compare，否则回退旧 SHA-256 方案
async function verifyPassword(password, salt, hash) {
  if (isBcryptHash(hash)) {
    return bcrypt.compare(password, hash);
  }
  return verifyLegacy(password, salt, hash);
}

module.exports = { sha256Hex, genSalt, hashPassword, hashBcrypt, isBcryptHash, verifyPassword, verifyLegacy };
