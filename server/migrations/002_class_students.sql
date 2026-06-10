-- 班级学生名册（注册白名单）：学号不在名册中的请求一律拒绝注册。
-- 数据来源：班级学生信息.xlsx（scripts/class-students.json），由 scripts/import-class-students.js 导入。
CREATE TABLE IF NOT EXISTS dtest2.class_students (
    student_id text PRIMARY KEY,
    name text NOT NULL,
    class_name text NOT NULL,
    gender text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
