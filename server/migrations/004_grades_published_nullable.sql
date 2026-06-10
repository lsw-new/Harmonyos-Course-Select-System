-- 成绩发布两段式：管理端打分先落 grades 行（published_at=NULL，学生不可见），
-- 审核通过时统一置 published_at=now() 发布。故 published_at 需允许 NULL。
ALTER TABLE dtest2.grades ALTER COLUMN published_at DROP NOT NULL;
