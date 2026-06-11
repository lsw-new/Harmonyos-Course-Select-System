-- 名册补全学院/专业：class_name（如 23计算机科学与技术U9）三段含义为
-- 「23=2023 年级 + 计算机科学与技术=专业 + U9=班号」，学院在原始名册数据中缺失，
-- 本名册全部学生均属电子信息工程学院。补列后注册时学院/专业直接取自名册，
-- 不再写死'待完善'；class_name 保持原样（课表/评教/成绩均按其关联）。
ALTER TABLE dtest2.class_students ADD COLUMN IF NOT EXISTS college text;
ALTER TABLE dtest2.class_students ADD COLUMN IF NOT EXISTS major text;

-- 回填存量名册：学院统一为电子信息工程学院；专业 = class_name 去掉前导年级数字与尾部班号（U+数字）
UPDATE dtest2.class_students
   SET college = COALESCE(college, '电子信息工程学院'),
       major   = COALESCE(major, regexp_replace(class_name, '^[0-9]+|U[0-9]+$', '', 'g'));

-- 已注册学生资料中注册时写死的'待完善'按名册回填（仅覆盖'待完善'，不动学生手动改过的值）
UPDATE dtest2.student_profiles sp
   SET college    = CASE WHEN sp.college = '待完善' THEN cs.college ELSE sp.college END,
       major      = CASE WHEN sp.major   = '待完善' THEN cs.major   ELSE sp.major   END,
       updated_at = now()
  FROM dtest2.class_students cs
 WHERE cs.student_id = sp.student_id
   AND (sp.college = '待完善' OR sp.major = '待完善');
