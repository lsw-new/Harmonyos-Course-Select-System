-- 教师管理（管理端）：注册 teachers.manage 细粒度权限（view/create/update/delete），
-- 并默认授予全部既有角色（与 feedback.handle / approvals.handle 等模块同口径）。
-- 幂等（ON CONFLICT DO NOTHING），无内层 BEGIN/COMMIT（migrate.js 单事务包裹）。

INSERT INTO dtest2.permissions (code, action, module, name) VALUES
  ('teachers.manage', 'view',   '教师管理', '查看教师'),
  ('teachers.manage', 'create', '教师管理', '新增教师'),
  ('teachers.manage', 'update', '教师管理', '编辑教师'),
  ('teachers.manage', 'delete', '教师管理', '删除教师')
ON CONFLICT (code, action) DO NOTHING;

INSERT INTO dtest2.role_permissions (role_id, code, action)
SELECT r.role_id, p.code, p.action
  FROM dtest2.roles r
  CROSS JOIN (VALUES
    ('teachers.manage', 'view'),
    ('teachers.manage', 'create'),
    ('teachers.manage', 'update'),
    ('teachers.manage', 'delete')
  ) AS p(code, action)
ON CONFLICT (role_id, code, action) DO NOTHING;
