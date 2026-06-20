-- 邮箱双因素认证（2FA / roadmap #12，仅邮箱，无短信）：
-- 给账号表加一个布尔开关列，默认关闭（向后兼容：存量账号 2FA 不开启，登录行为不变）。
-- 迁移 runner 在单个事务内逐文件执行——本文件保持「单语句 + 幂等」（IF NOT EXISTS）。
ALTER TABLE dtest2.accounts ADD COLUMN IF NOT EXISTS two_factor_enabled boolean NOT NULL DEFAULT false;
