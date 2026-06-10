// 导入真实校历：《景德镇艺术职业大学 2025-2026 学年校历》→ dtest2.calendar_events（UPSERT 幂等）。
// 覆盖两个学期的关键节点：开学/上课/教学检查/法定假期/校运会/期末考试/实践教学周/寒暑假。
// 用法：cd server && node scripts/import-school-calendar.js
require('dotenv').config();
const { pool } = require('../src/db');

// [id, date, title, type]；type ∈ term/exam/holiday/selection/makeup/other
const EVENTS = [
  // ===== 2025-2026 学年第一学期 =====
  ['sc1-01', '2025-09-03', '教工开学（第一学期）', 'term'],
  ['sc1-02', '2025-09-05', '老生报到（9月5日-7日）', 'term'],
  ['sc1-03', '2025-09-08', '老生与专升本新生上课', 'term'],
  ['sc1-04', '2025-09-08', '集中教学检查（9月8日-12日）', 'other'],
  ['sc1-05', '2025-09-11', '2025级本、专科新生报到（9月11日-13日）', 'term'],
  ['sc1-06', '2025-09-16', '新生军训（9月16日-30日）', 'other'],
  ['sc1-07', '2025-10-01', '国庆节假期', 'holiday'],
  ['sc1-08', '2025-10-06', '中秋节假期', 'holiday'],
  ['sc1-09', '2025-11-06', '校运会（11月6日-8日）', 'other'],
  ['sc1-10', '2026-01-01', '元旦假期', 'holiday'],
  ['sc1-11', '2026-01-05', '期末集中考试（1月5日-7日）', 'exam'],
  ['sc1-12', '2026-01-08', '校外实践教学周（1月8日-16日）', 'other'],
  ['sc1-13', '2026-01-17', '学生寒假开始（社会实践活动）', 'holiday'],
  ['sc1-14', '2026-01-24', '教工寒假开始', 'holiday'],
  // ===== 2025-2026 学年第二学期（当前学期，第1周=3月2日，共20周）=====
  ['sc2-01', '2026-03-05', '教工开学（第二学期）', 'term'],
  ['sc2-02', '2026-03-06', '学生开学报到及教材发放（3月6日-8日）', 'term'],
  ['sc2-03', '2026-03-09', '正式上课（第二学期）', 'term'],
  ['sc2-04', '2026-03-09', '集中教学检查（3月9日-13日）', 'other'],
  ['sc2-05', '2026-04-05', '清明节假期', 'holiday'],
  ['sc2-06', '2026-05-01', '劳动节假期', 'holiday'],
  ['sc2-07', '2026-06-19', '端午节假期', 'holiday'],
  ['sc2-08', '2026-06-29', '期末集中考试（6月29日-7月1日）', 'exam'],
  ['sc2-09', '2026-07-02', '校外实践教学周（7月2日-10日）', 'other'],
  ['sc2-10', '2026-07-11', '学生暑假开始（社会实践活动）', 'holiday'],
  ['sc2-11', '2026-07-18', '教工暑假开始', 'holiday']
];

async function main() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const ev of EVENTS) {
      await client.query(
        `INSERT INTO dtest2.calendar_events (event_id, event_date, title, type)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (event_id) DO UPDATE
           SET event_date = EXCLUDED.event_date, title = EXCLUDED.title, type = EXCLUDED.type`,
        ev
      );
    }
    await client.query('COMMIT');
    console.log(`done. 校历事件导入/更新 ${EVENTS.length} 条（两学期）。`);
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
