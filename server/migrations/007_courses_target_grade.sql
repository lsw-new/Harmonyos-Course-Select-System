-- 选课课程「面向年级发布」：courses 加 target_grade 列（如 '2023级'）。
-- NULL/空 = 面向全部年级；学生选课中心列表按本人年级（学号前 4 位派生）过滤，
-- 管理端不过滤可见全部。配套管理端选课课程管理页（按轮次入口）增删改查。
ALTER TABLE dtest2.courses ADD COLUMN IF NOT EXISTS target_grade text;
