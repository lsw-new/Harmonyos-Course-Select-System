// JWT 签发与校验中间件
const jwt = require('jsonwebtoken');
const { fail } = require('./envelope');

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

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

module.exports = { signToken, authRequired };
