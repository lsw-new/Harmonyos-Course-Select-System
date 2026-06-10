-- 班级课表 + 课程-教师绑定。
-- 数据来源：23计算机科学与技术U9 真实课表（scripts/class-schedule.json），
-- 由 scripts/import-class-schedule.js 导入；学生按 class_students.class_name 匹配本班课表。
CREATE TABLE IF NOT EXISTS dtest2.class_schedule_items (
    item_id text PRIMARY KEY,
    class_name text NOT NULL,
    term text NOT NULL,
    type text NOT NULL DEFAULT 'normal',
    course_id text NOT NULL,
    course_name text NOT NULL,
    teacher text NOT NULL,
    weekday integer NOT NULL,
    period_start integer NOT NULL,
    period_end integer NOT NULL,
    start_time text NOT NULL,
    end_time text NOT NULL,
    classroom text NOT NULL DEFAULT '',
    campus text,
    weeks jsonb NOT NULL DEFAULT '[]'::jsonb,
    week_text text NOT NULL DEFAULT '',
    course_type text NOT NULL DEFAULT '',
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT class_schedule_items_type_check CHECK ((type = ANY (ARRAY['normal'::text, 'practice'::text]))),
    CONSTRAINT class_schedule_items_weekday_check CHECK ((weekday >= 1 AND weekday <= 7)),
    CONSTRAINT class_schedule_items_period_check CHECK ((period_start >= 1 AND period_end >= period_start))
);

CREATE INDEX IF NOT EXISTS idx_class_schedule_items_class ON dtest2.class_schedule_items (class_name);

-- 课程-教师绑定（由课表派生：每门课对应授课教师）
CREATE TABLE IF NOT EXISTS dtest2.course_teachers (
    course_id text PRIMARY KEY,
    course_name text NOT NULL,
    teacher text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
