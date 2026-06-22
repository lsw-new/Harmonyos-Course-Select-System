-- 教师头像（roadmap #6 完善·教师端）：teacher_profiles 增加 avatar_url 列。
-- 复用 #9 对象存储：值可为 /api/uploads/<up-uuid>、data URL 或 http(s) 外链。
-- 幂等（ADD COLUMN IF NOT EXISTS），无内层 BEGIN/COMMIT（migrate.js 单事务包裹）。

ALTER TABLE dtest2.teacher_profiles
  ADD COLUMN IF NOT EXISTS avatar_url text NOT NULL DEFAULT '';
