-- 学籍注册字段扩展（roadmap #3）：政治面貌/民族/籍贯/入学日期/学制/培养层次/学籍状态
-- 全部字段 nullable，不破坏现有数据。idempotent（ADD COLUMN IF NOT EXISTS）。
-- 注意：migrate.js 已为每个迁移文件包裹单事务并登记 schema_migrations，
-- 故本文件不再自带 BEGIN/COMMIT，也无需手写 schema_migrations 插入（与 013/014 约定一致）。
ALTER TABLE dtest2.student_profiles
  ADD COLUMN IF NOT EXISTS political_status  text,      -- 政治面貌（党员/共青团员/群众等）
  ADD COLUMN IF NOT EXISTS ethnicity          text,      -- 民族（汉族/回族等）
  ADD COLUMN IF NOT EXISTS native_place       text,      -- 籍贯（省市）
  ADD COLUMN IF NOT EXISTS enrollment_date    date,      -- 入学日期
  ADD COLUMN IF NOT EXISTS program_length     text,      -- 学制（4年/3年等）
  ADD COLUMN IF NOT EXISTS education_level    text,      -- 培养层次（本科/专科）
  ADD COLUMN IF NOT EXISTS enrollment_status  text;      -- 学籍状态（在读/休学/毕业）
