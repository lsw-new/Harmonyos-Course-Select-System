// JWT 签发与校验中间件
const jwt = require('jsonwebtoken');
const { fail } = require('./envelope');

// P2-01：强制要求足够强度的 JWT_SECRET，拒绝以默认/弱密钥启动（fail-fast）。
const SECRET = process.env.JWT_SECRET;
if (!SECRET || SECRET.length < 16) {
  console.error('[FATAL] 未配置 JWT_SECRET 或长度不足（至少 16 字符），服务拒绝启动。请在 .env 设置随机长串。');
  process.exit(1);
}

function signToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: '7d' });
}

function authRequired(req, res, next) {
  const header = req.headers['authorization'] || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json(fail('未授权', 'unauthorized'));
  }
  try {
    req.auth = jwt.verify(match[1], SECRET);
    next();
  } catch (e) {
    return res.status(401).json(fail('登录态已失效，请重新登录', 'unauthorized'));
  }
}

// 管理端中间件：先校验登录态，再要求 role=admin
function adminRequired(req, res, next) {
  authRequired(req, res, () => {
    if (!req.auth || req.auth.role !== 'admin') {
      return res.status(403).json(fail('需要管理员权限', 'forbidden'));
    }
    next();
  });
}

module.exports = { signToken, authRequired, adminRequired };
