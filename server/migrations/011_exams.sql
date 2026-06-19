-- 考试安排（FEATURE_COMPLETION_PLAN 阶段 3）。
-- 学生按「本班课表课程 ∪ 已选课程」查本人考试；管理端对考试 CRUD。
-- 全部 IF NOT EXISTS、幂等可重复执行；本 schema 数据量小，无需 CONCURRENTLY。

-- 1) 考试表：每条考试关联一门课程（course_id），按学期（term）归档。
CREATE TABLE IF NOT EXISTS dtest2.exams (
    exam_id text PRIMARY KEY,
    course_id text NOT NULL,
    term text NOT NULL,
    exam_date date,
    start_time text,
    end_time text,
    location text,
    seat_no text,
    exam_type text DEFAULT 'final',
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2) 索引：学生查询按 course_id 匹配本班/已选课程，管理端/学生均按 term 过滤。
CREATE INDEX IF NOT EXISTS idx_exams_course_id ON dtest2.exams (course_id);
CREATE INDEX IF NOT EXISTS idx_exams_term ON dtest2.exams (term);

-- 3) 播种：从已有班级课表为每门课程播种一条期末考试，让学生端能看到真实数据。
--    放在建表之后单独执行；即使本语句失败（如源表为空），上面的建表已生效不受影响。
--    exam_date 取学期末附近固定日期，location 复用教室（无则留空）。
INSERT INTO dtest2.exams (exam_id, course_id, term, exam_date, start_time, end_time, location, seat_no, exam_type)
SELECT 'ex-seed-' || src.course_id,
       src.course_id,
       src.term,
       DATE '2026-07-06',
       '09:00',
       '11:00',
       src.classroom,
       NULL,
       'final'
  FROM (
    SELECT DISTINCT ON (csi.course_id)
           csi.course_id, csi.term, csi.classroom
      FROM dtest2.class_schedule_items csi
     ORDER BY csi.course_id, csi.item_id
  ) src
ON CONFLICT (exam_id) DO NOTHING;
