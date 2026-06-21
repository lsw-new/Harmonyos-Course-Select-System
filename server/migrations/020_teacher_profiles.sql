-- 教师账号体系（roadmap #6 teacher portal）：
-- teacher_profiles 存教师姓名/学院/职称/邮箱；
-- 与 course_teachers.teacher / courses.teacher 通过 name 列关联（无需改动现有课程表结构）。
-- 全部 CREATE ... IF NOT EXISTS，幂等可重复执行，无内层 BEGIN/COMMIT。

CREATE TABLE IF NOT EXISTS dtest2.teacher_profiles (
    teacher_id   text PRIMARY KEY,
    name         text NOT NULL,
    college      text NOT NULL DEFAULT '',
    title        text NOT NULL DEFAULT '',
    email        text NOT NULL DEFAULT '',
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- 通过姓名查课程时需要快速定位教师；name 列唯一约束确保不同 teacher_id 不重名。
CREATE UNIQUE INDEX IF NOT EXISTS idx_teacher_profiles_name
  ON dtest2.teacher_profiles (name);

-- accounts.role 原 CHECK 仅允许 student/admin；教师账号需放开 'teacher'。
-- DROP IF EXISTS + ADD 同名约束，幂等（migrate.js 单事务内执行，原子）。
ALTER TABLE dtest2.accounts DROP CONSTRAINT IF EXISTS accounts_role_check;
ALTER TABLE dtest2.accounts ADD CONSTRAINT accounts_role_check
  CHECK (role = ANY (ARRAY['student'::text, 'admin'::text, 'teacher'::text]));
