-- 014_audit_geo：为审计日志登录事件补「地点」列（roadmap #5 登录历史地点/时长）。
-- 幂等：ADD COLUMN IF NOT EXISTS + schema_migrations 去重插入，可重复执行，单事务安全。
-- geo 存登录时由后端离线解析（ip2region）得到的「省·市」串；私网/解析失败留 NULL/空串。

ALTER TABLE dtest2.audit_logs ADD COLUMN IF NOT EXISTS geo text;

-- 记录本迁移已应用（与既有 schema_migrations 约定一致；幂等）
INSERT INTO dtest2.schema_migrations (version, name)
SELECT 14, 'audit_geo'
WHERE NOT EXISTS (SELECT 1 FROM dtest2.schema_migrations WHERE version = 14);
