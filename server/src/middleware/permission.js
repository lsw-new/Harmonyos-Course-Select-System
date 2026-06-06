// P0-02 细粒度鉴权中间件工厂：在 adminRequired（登录态 + role=admin）基础上，再校验
// 当前管理员所属角色是否拥有指定权限码。权限只从数据库读取
// （admin_profiles.role_id → role_permissions），不写入 token，避免前端伪造。
// keys 为 'code:action' 列表，命中任意一个即放行（fail-closed）。
const { pool } = require('../db');
const { adminRequired } = require('../auth');
const { fail } = require('../envelope');
const { serverError } = require('./errorHandler');

function permissionRequired(...keys) {
  return (req, res, next) => {
    adminRequired(req, res, async () => {
      const adminId = (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
      try {
        const r = await pool.query(
          `SELECT 1 FROM dtest2.admin_profiles ap
             JOIN dtest2.role_permissions rp ON rp.role_id = ap.role_id
            WHERE ap.admin_id = $1
              AND (rp.code || ':' || rp.action) = ANY($2::text[])
            LIMIT 1`,
          [adminId, keys]
        );
        if (r.rowCount === 0) {
          return res.status(403).json(fail('权限不足，需要相应管理权限', 'forbidden'));
        }
        next();
      } catch (e) {
        return serverError(res, '权限校验失败', e, 'server_error');
      }
    });
  };
}

module.exports = { permissionRequired };
