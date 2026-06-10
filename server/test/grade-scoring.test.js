// 成绩打分闭环：打分名单查询、按学生打分（UPSERT+排名+进度自动计算）、审核通过即发布成绩行。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

const taskRow = {
  course_id: 'VDZ02119204',
  term: '2025-2026-2',
  teaching_class_name: '23计算机科学与技术U9',
  status: 'inputting'
};
const updatedTaskRow = {
  task_id: 'gt-VDZ02119204',
  teaching_class_name: '23计算机科学与技术U9',
  teacher_name: '方坚',
  input_progress: 50,
  status: 'inputting',
  reject_reason: null,
  updated_at: '2026-06-10T08:00:00Z',
  course_name: '鸿蒙应用开发初级认证'
};

beforeEach(() => __mock.reset());

describe('GET /api/admin/grades/:id/scores', () => {
  test('任务不存在 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FROM dtest2\.grade_tasks WHERE task_id/, result: [] }]);
    const res = await request(app).get('/api/admin/grades/gt-x/scores').set('Authorization', adm);
    expect(res.status).toBe(404);
  });

  test('返回本班已注册学生名单与已录分数', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.grade_tasks WHERE task_id/, result: [Object.assign({ task_id: 'gt-VDZ02119204' }, taskRow)] },
      { match: /FROM dtest2\.class_students cs/, result: [
        { student_id: '2023307020941', name: '李仕炜', score: '92.00' },
        { student_id: '2023307020901', name: '罗翔', score: null }
      ] }
    ]);
    const res = await request(app).get('/api/admin/grades/gt-VDZ02119204/scores').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.students).toHaveLength(2);
    expect(res.body.data.students[0].score).toBe(92);
    expect(res.body.data.students[1].score).toBeNull();
  });
});

describe('POST /api/admin/grades/:id/scores', () => {
  test('分数非法 → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).post('/api/admin/grades/gt-x/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: '2023307020941', score: 120 }] });
    expect(res.status).toBe(400);
  });

  test('已发布任务 → 409 且回滚', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [Object.assign({}, taskRow, { status: 'published' })] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt-x/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: '2023307020941', score: 90 }] });
    expect(res.status).toBe(409);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('打分成功 → UPSERT 成绩 + 重算排名 + 进度自动更新', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [taskRow] },
      { match: /INSERT INTO dtest2\.grades/, result: [] },
      { match: /UPDATE dtest2\.grades g SET rank/, result: [] },
      { match: /SELECT[\s\S]*count\(\*\)[\s\S]*class_students/, result: [{ total: '2', scored: '1' }] },
      { match: /UPDATE dtest2\.grade_tasks SET input_progress/, result: [] },
      { match: /FROM dtest2\.grade_tasks gt LEFT JOIN/, result: [updatedTaskRow] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt-VDZ02119204/scores').set('Authorization', adm)
      .send({ scores: [{ studentId: '2023307020941', score: 92 }] });
    expect(res.status).toBe(200);
    expect(res.body.data.inputProgress).toBe(50);
    expect(__mock.executed('INSERT INTO dtest2.grades')).toBe(true);
    expect(__mock.executed('UPDATE dtest2.grades g SET rank')).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
    // 写入分数时不直接发布（published_at=NULL），审核通过才发布
    const gradeInsert = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.grades') >= 0);
    expect(gradeInsert.sql).toContain('NULL');
  });
});

describe('POST /api/admin/grades/:id/approve（发布联动）', () => {
  test('审核通过 → 任务置 published 且成绩行 published_at 落值', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FOR UPDATE/, result: [{ status: 'pendingAudit', input_progress: 100 }] },
      { match: /UPDATE dtest2\.grade_tasks SET status='published'/, result: [] },
      { match: /UPDATE dtest2\.grades SET published_at/, result: [] }
    ]);
    const res = await request(app).post('/api/admin/grades/gt-VDZ02119204/approve').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(__mock.executed("UPDATE dtest2.grades SET published_at")).toBe(true);
    expect(__mock.executed('COMMIT')).toBe(true);
  });
});
