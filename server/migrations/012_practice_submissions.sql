-- 实践提交（practice submissions）：学生对已报名的实践项目提交成果/报告，管理端打分/认定。
-- 报名表为 dtest2.practice_signups（主键 project_id+student_id，status signedUp/cancelled）；
-- 项目表为 dtest2.practice_projects（主键 project_id）。本表 project_id 对应实践项目 ID。
-- 全部 IF NOT EXISTS，幂等可重复执行；本 schema 数据量小，迁移在事务内，无需 CONCURRENTLY。

CREATE TABLE IF NOT EXISTS dtest2.practice_submissions (
    submission_id text PRIMARY KEY,
    project_id text NOT NULL,
    student_id text NOT NULL,
    content text,
    attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'submitted',
    score numeric,
    feedback text,
    scored_by text,
    scored_at timestamptz,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT practice_submissions_status_check
      CHECK (status IN ('submitted', 'scored', 'passed', 'rejected'))
);

-- 学生查询/去重本人某项目的提交（WHERE student_id=$1 [AND project_id=$2]）。
CREATE INDEX IF NOT EXISTS idx_practice_submissions_student
  ON dtest2.practice_submissions (student_id);

-- 管理端按项目筛选提交（GET /api/admin/practice-submissions?projectId=）。
CREATE INDEX IF NOT EXISTS idx_practice_submissions_project
  ON dtest2.practice_submissions (project_id);

-- 管理端按状态筛选提交（GET /api/admin/practice-submissions?status=）。
CREATE INDEX IF NOT EXISTS idx_practice_submissions_status
  ON dtest2.practice_submissions (status);
