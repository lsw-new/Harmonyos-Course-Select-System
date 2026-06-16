-- 意见反馈管理端处理闭环：
-- 1) feedback_items 加 reply / replied_by / replied_at 列，承载管理员回复 + 处理人 + 时间；
-- 2) 注册 feedback.handle 权限（view/update），并默认授予全部既有角色（与 approvals.handle 等模块对齐）。
-- 全部语句幂等，可多次执行。
ALTER TABLE dtest2.feedback_items ADD COLUMN IF NOT EXISTS reply text;
ALTER TABLE dtest2.feedback_items ADD COLUMN IF NOT EXISTS replied_by text;
ALTER TABLE dtest2.feedback_items ADD COLUMN IF NOT EXISTS replied_at timestamp with time zone;

INSERT INTO dtest2.permissions (code, action, module, name) VALUES
  ('feedback.handle', 'view',   '反馈与服务', '查看意见反馈'),
  ('feedback.handle', 'update', '反馈与服务', '处理意见反馈')
ON CONFLICT (code, action) DO NOTHING;

INSERT INTO dtest2.role_permissions (role_id, code, action)
SELECT r.role_id, p.code, p.action
  FROM dtest2.roles r
  CROSS JOIN (VALUES ('feedback.handle','view'), ('feedback.handle','update')) AS p(code, action)
ON CONFLICT (role_id, code, action) DO NOTHING;
