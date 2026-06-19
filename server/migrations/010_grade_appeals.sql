-- 成绩申诉（grade appeals）：学生对某次成绩任务提交申诉，管理端受理/驳回。
-- 全部 IF NOT EXISTS，幂等可重复执行；本 schema 数据量小，迁移在事务内，无需 CONCURRENTLY。

CREATE TABLE IF NOT EXISTS dtest2.grade_appeals (
    appeal_id text PRIMARY KEY,
    student_id text NOT NULL,
    task_id text,
    course_id text,
    term text,
    reason text NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    reply text,
    handled_by text,
    handled_at timestamptz,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT grade_appeals_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
);

-- 学生查询本人申诉列表（WHERE student_id=$1 ORDER BY submitted_at DESC）。
CREATE INDEX IF NOT EXISTS idx_grade_appeals_student
  ON dtest2.grade_appeals (student_id, submitted_at DESC);

-- 管理端按状态筛选申诉（GET /api/admin/grade-appeals?status=）。
CREATE INDEX IF NOT EXISTS idx_grade_appeals_status
  ON dtest2.grade_appeals (status);
