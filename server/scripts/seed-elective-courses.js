// 选课中心扩充：批量新增选修/公选课程（教师为虚构姓名），UPSERT 幂等可重跑。
// 须在 dtest2-api 目录运行：node scripts/seed-elective-courses.js
require('dotenv').config();
const { pool } = require('../src/db');

// 时间错开（晚间 7-8 / 9-10 节为主），避免与白天必修课表硬冲突；
// target_grade 留空 = 全部年级，'2023级' = 仅 2023 级可见可选。
const COURSES = [
  { id: 'CER20101', code: 'CER20101', name: '陶艺拉坯实训', teacher: '林晚晴', category: 'elective', credit: 2, capacity: 30, weekday: 2, ps: 9, pe: 10, grade: null },
  { id: 'ART20201', code: 'ART20201', name: '数字摄影基础', teacher: '沈知行', category: 'elective', credit: 2, capacity: 40, weekday: 3, ps: 9, pe: 10, grade: null },
  { id: 'MUS10102', code: 'MUS10102', name: '古典音乐鉴赏', teacher: '顾青崖', category: 'public', credit: 2, capacity: 60, weekday: 5, ps: 9, pe: 10, grade: null },
  { id: 'HIS21003', code: 'HIS21003', name: '景德镇陶瓷文化史', teacher: '苏黎', category: 'public', credit: 2, capacity: 50, weekday: 1, ps: 9, pe: 10, grade: null },
  { id: 'LIT11502', code: 'LIT11502', name: '创意写作工坊', teacher: '韩沐宸', category: 'elective', credit: 2, capacity: 25, weekday: 1, ps: 7, pe: 8, grade: '2023级' },
  { id: 'CSE30104', code: 'CSE30104', name: 'Python 数据可视化入门', teacher: '陆星河', category: 'elective', credit: 3, capacity: 45, weekday: 5, ps: 7, pe: 8, grade: '2023级' },
  { id: 'PE10506', code: 'PE10506', name: '篮球（体育选项）', teacher: '白若鸿', category: 'public', credit: 1, capacity: 40, weekday: 3, ps: 7, pe: 8, grade: null },
  { id: 'COM12001', code: 'COM12001', name: '跨文化沟通艺术', teacher: '唐砚秋', category: 'elective', credit: 2, capacity: 35, weekday: 2, ps: 7, pe: 8, grade: null }
];

(async () => {
  let upserted = 0;
  for (const c of COURSES) {
    await pool.query(
      `INSERT INTO dtest2.courses
         (course_id, code, name, category, credit, teacher, capacity, status,
          weekday, period_start, period_end, target_grade)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'open',$8,$9,$10,$11)
       ON CONFLICT (course_id) DO UPDATE SET
         name=EXCLUDED.name, teacher=EXCLUDED.teacher, category=EXCLUDED.category,
         credit=EXCLUDED.credit, capacity=EXCLUDED.capacity, status='open',
         weekday=EXCLUDED.weekday, period_start=EXCLUDED.period_start,
         period_end=EXCLUDED.period_end, target_grade=EXCLUDED.target_grade, updated_at=now()`,
      [c.id, c.code, c.name, c.category, c.credit, c.teacher, c.capacity, c.weekday, c.ps, c.pe, c.grade]
    );
    upserted += 1;
  }
  const open = await pool.query(`SELECT COUNT(*)::int AS n FROM dtest2.courses WHERE status='open'`);
  console.log(`已 UPSERT ${upserted} 门选修/公选课程；当前选课中心 open 课程共 ${open.rows[0].n} 门`);
  process.exit(0);
})().catch((e) => { console.error('FAIL:', e.message); process.exit(1); });
