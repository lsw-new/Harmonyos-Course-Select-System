-- 性能审查（performance-optimizer）补齐高频查询缺失索引。
-- 说明：审查初稿建议的多数索引（grades(student_id,term)、selections(course_id,status)、
-- evaluation_tasks(student_id,term,status)、audit_logs(operator_id,created_at)、
-- class_schedule_items(class_name) 等）建表迁移里已存在；此处仅补真正缺失的三项。
-- 全部 IF NOT EXISTS，幂等可重复执行；本 schema 数据量小，无需 CONCURRENTLY（迁移在事务内）。

-- 1) 按班级定位名册：成绩打分名单校验、评教任务同步、课表班级匹配都按 class_name 过滤，
--    而 class_students 仅有 student_id 主键索引，class_name 查询此前走全表扫描。
CREATE INDEX IF NOT EXISTS idx_class_students_class_name
  ON dtest2.class_students (class_name);

-- 2) 管理端意见反馈按状态/分类筛选（GET /api/admin/feedback），此前无对应索引。
CREATE INDEX IF NOT EXISTS idx_feedback_state_category
  ON dtest2.feedback_items (state, category);

-- 3) 学生查询本人反馈列表（WHERE student_id=$1 ORDER BY submitted_at DESC）。
CREATE INDEX IF NOT EXISTS idx_feedback_student
  ON dtest2.feedback_items (student_id, submitted_at DESC);
