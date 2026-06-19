// 分支覆盖补测：针对 db/admin-courses/admin-stats/grades 等域的异常分支、校验矩阵与边界钳制。
// 目标：把 CI coverageThreshold(branches>=80%) 拉回绿（既有用例只覆盖正路径，欠 4xx/500/钳制分支）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

function pgError(message, code) {
  const e = new Error(message);
  e.code = code;
  return e;
}

beforeEach(() => __mock.reset());

// ====================== 数据库管理域 db.routes ======================

const TABLE_OK = { match: /information_schema\.tables/, result: [{ table_name: 'class_students' }] };
const COLUMNS = {
  match: /information_schema\.columns/,
  result: [
    { column_name: 'student_id', data_type: 'text', is_nullable: 'NO', column_default: null },
    { column_name: 'name', data_type: 'text', is_nullable: 'NO', column_default: null },
    { column_name: 'meta', data_type: 'jsonb', is_nullable: 'YES', column_default: null },
    { column_name: 'age', data_type: 'integer', is_nullable: 'YES', column_default: null }
  ]
};
const PK = { match: /pg_index/, result: [{ column_name: 'student_id' }] };
const NO_PK = { match: /pg_index/, result: [] };

describe('db.routes 异常与边界分支', () => {
  test('GET tables：底层查询抛错 → 500 通用文案', async () => {
    __mock.setRoutes([PERM, { match: /information_schema\.tables/, result: new Error('boom') }]);
    const res = await request(app).get('/api/admin/db/tables').set('Authorization', adm);
    expect(res.status).toBe(500);
    expect(res.body.error).not.toContain('boom');
  });

  test('GET rows：q 搜索命中文本列 + limit/offset 钳制（999→200、-5→0）', async () => {
    __mock.setRoutes([
      PERM, TABLE_OK, COLUMNS, PK,
      { match: /SELECT count\(\*\) AS n/, result: [{ n: '0' }] },
      { match: /SELECT \* FROM dtest2\."class_students"/, result: [] }
    ]);
    const res = await request(app)
      .get('/api/admin/db/tables/class_students/rows?q=%E6%9D%8E&limit=999&offset=-5')
      .set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.limit).toBe(200);
    expect(res.body.data.offset).toBe(0);
    const sel = __mock.getLog().find((e) => e.sql.indexOf('SELECT * FROM') >= 0);
    expect(sel.sql).toContain('ILIKE');
  });

  test('GET rows：q 搜索但表无文本列 → 不拼 WHERE', async () => {
    __mock.setRoutes([
      PERM, TABLE_OK,
      { match: /information_schema\.columns/, result: [{ column_name: 'age', data_type: 'integer', is_nullable: 'YES', column_default: null }] },
      NO_PK,
      { match: /SELECT count\(\*\) AS n/, result: [{ n: '0' }] },
      { match: /SELECT \* FROM dtest2\."class_students"/, result: [] }
    ]);
    const res = await request(app)
      .get('/api/admin/db/tables/class_students/rows?q=abc&limit=abc')
      .set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.limit).toBe(50);
    const sel = __mock.getLog().find((e) => e.sql.indexOf('SELECT * FROM') >= 0);
    expect(sel.sql).not.toContain('ILIKE');
    expect(sel.sql).not.toContain('ORDER BY');
  });

  test('GET rows：底层抛错 → 500', async () => {
    __mock.setRoutes([PERM, TABLE_OK, { match: /information_schema\.columns/, result: new Error('x') }]);
    const res = await request(app).get('/api/admin/db/tables/class_students/rows').set('Authorization', adm);
    expect(res.status).toBe(500);
  });

  test('INSERT：values 全是非法列 → 400', async () => {
    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK]);
    const res = await request(app).post('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ values: { evil: 'x' } });
    expect(res.status).toBe(400);
  });

  test('INSERT：jsonb 列显式 cast', async () => {
    __mock.setRoutes([
      PERM, TABLE_OK, COLUMNS, PK,
      { match: /INSERT INTO dtest2\."class_students"/, result: [{ student_id: 's1' }] }
    ]);
    const res = await request(app).post('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ values: { student_id: 's1', meta: '{"a":1}' } });
    expect(res.status).toBe(200);
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO') >= 0);
    expect(ins.sql).toContain('::jsonb');
  });

  test('INSERT：表不存在 → 404；pg 约束错误 → 400 精确原因；非 pg 错误 → 500', async () => {
    __mock.setRoutes([PERM, { match: /information_schema\.tables/, result: [] }]);
    const r404 = await request(app).post('/api/admin/db/tables/nosuch/rows').set('Authorization', adm)
      .send({ values: { name: 'x' } });
    expect(r404.status).toBe(404);

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK,
      { match: /INSERT INTO/, result: pgError('duplicate key', '23505') }]);
    const r400 = await request(app).post('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ values: { name: 'x' } });
    expect(r400.status).toBe(400);
    // 安全：pg 约束错误回「分类文案」，不泄露 e.message 中的约束名/表名等 schema 细节
    expect(r400.body.error).toContain('唯一约束');
    expect(r400.body.error).not.toContain('duplicate key');

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK,
      { match: /INSERT INTO/, result: new Error('conn reset') }]);
    const r500 = await request(app).post('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ values: { name: 'x' } });
    expect(r500.status).toBe(500);
    expect(r500.body.error).not.toContain('conn reset');
  });

  test('UPDATE：表不存在 404 / 无主键表 409 / 仅主键列 400 / 主键不匹配 404', async () => {
    __mock.setRoutes([PERM, { match: /information_schema\.tables/, result: [] }]);
    expect((await request(app).put('/api/admin/db/tables/nosuch/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' }, values: { name: 'x' } })).status).toBe(404);

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, NO_PK]);
    expect((await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: {}, values: { name: 'x' } })).status).toBe(409);

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK]);
    expect((await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' }, values: { student_id: 's2' } })).status).toBe(400);

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK, { match: /UPDATE dtest2\."class_students"/, result: [] }]);
    expect((await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 'nope' }, values: { name: 'x' } })).status).toBe(404);
  });

  test('UPDATE：pg 错误 → 400；非 pg 错误 → 500', async () => {
    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK,
      { match: /UPDATE dtest2\."class_students"/, result: pgError('invalid input', '22P02') }]);
    expect((await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' }, values: { name: 'x' } })).status).toBe(400);

    __mock.setRoutes([PERM, TABLE_OK, COLUMNS, PK,
      { match: /UPDATE dtest2\."class_students"/, result: new Error('down') }]);
    expect((await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' }, values: { name: 'x' } })).status).toBe(500);
  });

  test('DELETE：表不存在 404 / 无主键表 409 / 缺主键 400 / 外键约束 400 / 非 pg 错误 500', async () => {
    __mock.setRoutes([PERM, { match: /information_schema\.tables/, result: [] }]);
    expect((await request(app).delete('/api/admin/db/tables/nosuch/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' } })).status).toBe(404);

    __mock.setRoutes([PERM, TABLE_OK, NO_PK]);
    expect((await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: {} })).status).toBe(409);

    __mock.setRoutes([PERM, TABLE_OK, PK]);
    expect((await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: {} })).status).toBe(400);

    __mock.setRoutes([PERM, TABLE_OK, PK,
      { match: /DELETE FROM dtest2\."class_students"/, result: pgError('violates foreign key', '23503') }]);
    expect((await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' } })).status).toBe(400);

    __mock.setRoutes([PERM, TABLE_OK, PK,
      { match: /DELETE FROM dtest2\."class_students"/, result: new Error('down') }]);
    expect((await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' } })).status).toBe(500);
  });
});

// ====================== 课程管理域 admin-courses.routes ======================

describe('admin-courses 校验矩阵与异常分支', () => {
  const valid = { code: 'CS1', name: '课', teacher: '师', category: 'required', credit: 2, capacity: 50, status: 'open', timeText: '周一 3-4 节' };
  const courseRow = {
    course_id: 'ac-1', code: 'CS1', name: '课', teacher: '师', category: 'elective',
    credit: '2.0', capacity: 50, status: 'open', weekday: 7, period_start: 9, period_end: 10,
    weeks_text: null, selected_count: 0
  };

  async function post(body) {
    return request(app).post('/api/admin/courses').set('Authorization', adm).send(body);
  }

  test('校验矩阵：类别/状态/学分/容量逐项 400', async () => {
    __mock.setRoutes([PERM]);
    expect((await post(Object.assign({}, valid, { category: 'weird' }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { status: 'weird' }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { credit: 0 }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { credit: 'abc' }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { credit: 25 }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { capacity: 1.5 }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { capacity: -1 }))).status).toBe(400);
    expect((await post(Object.assign({}, valid, { capacity: 2000 }))).status).toBe(400);
  });

  test('status 缺省走 draft + 周天映射 weekday=7', async () => {
    __mock.setRoutes([
      PERM,
      { match: /INSERT INTO dtest2\.courses/, result: [] },
      { match: /FROM dtest2\.courses c/, result: [courseRow] }
    ]);
    const body = Object.assign({}, valid, { timeText: '周天 9-10 节' });
    delete body.status;
    const res = await post(body);
    expect(res.status).toBe(200);
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.courses') >= 0);
    expect(ins.params).toContain('draft');
    expect(ins.params).toContain(7);
  });

  test('timeText 节次越界（13-14 节）→ 原文存 weeks_text', async () => {
    __mock.setRoutes([
      PERM,
      { match: /INSERT INTO dtest2\.courses/, result: [] },
      { match: /FROM dtest2\.courses c/, result: [courseRow] }
    ]);
    const res = await post(Object.assign({}, valid, { timeText: '周日 13-14 节' }));
    expect(res.status).toBe(200);
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.courses') >= 0);
    expect(ins.params).toContain('周日 13-14 节');
  });

  test('插入后课程查不到 → data 为 null（防御分支）', async () => {
    __mock.setRoutes([
      PERM,
      { match: /INSERT INTO dtest2\.courses/, result: [] },
      { match: /FROM dtest2\.courses c/, result: [] }
    ]);
    const res = await post(valid);
    expect(res.status).toBe(200);
    expect(res.body.data).toBeNull();
  });

  test('GET 列表 500 / POST pg 错误 400 / POST 非 pg 错误 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.courses c/, result: new Error('down') }]);
    expect((await request(app).get('/api/admin/courses').set('Authorization', adm)).status).toBe(500);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.courses/, result: pgError('dup', '23505') }]);
    expect((await post(valid)).status).toBe(400);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.courses/, result: new Error('down') }]);
    expect((await post(valid)).status).toBe(500);
  });

  test('PUT 成功回显 / pg 错误 400 / 非 pg 错误 500', async () => {
    __mock.setRoutes([
      PERM,
      { match: /UPDATE dtest2\.courses SET/, result: [{ u: 1 }] },
      { match: /FROM dtest2\.courses c/, result: [courseRow] }
    ]);
    const okRes = await request(app).put('/api/admin/courses/ac-1').set('Authorization', adm).send(valid);
    expect(okRes.status).toBe(200);
    expect(okRes.body.data.timeText).toBe('周日 9-10 节');

    __mock.setRoutes([PERM, { match: /UPDATE dtest2\.courses SET/, result: pgError('bad', '22P02') }]);
    expect((await request(app).put('/api/admin/courses/ac-1').set('Authorization', adm).send(valid)).status).toBe(400);

    __mock.setRoutes([PERM, { match: /UPDATE dtest2\.courses SET/, result: new Error('down') }]);
    expect((await request(app).put('/api/admin/courses/ac-1').set('Authorization', adm).send(valid)).status).toBe(500);
  });

  test('DELETE 课程不存在 404 / 被引用 23503→409 / 其他 pg 错误 400 / 非 pg 错误 500', async () => {
    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.courses/, result: [] }]);
    expect((await request(app).delete('/api/admin/courses/x').set('Authorization', adm)).status).toBe(404);

    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.courses/, result: pgError('fk', '23503') }]);
    const r409 = await request(app).delete('/api/admin/courses/x').set('Authorization', adm);
    expect(r409.status).toBe(409);
    expect(r409.body.error).toContain('归档');

    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.courses/, result: pgError('bad', '22P02') }]);
    expect((await request(app).delete('/api/admin/courses/x').set('Authorization', adm)).status).toBe(400);

    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.courses/, result: new Error('down') }]);
    expect((await request(app).delete('/api/admin/courses/x').set('Authorization', adm)).status).toBe(500);
  });
});

// ====================== 统计域 admin-stats.routes ======================

describe('admin-stats 边界与异常分支', () => {
  test('dashboard 底层抛错 → 500', async () => {
    __mock.setRoutes([{ match: /AS students/, result: new Error('down') }]);
    const res = await request(app).get('/api/admin/dashboard').set('Authorization', adm);
    expect(res.status).toBe(500);
  });

  test('选课统计：时间缺失进度=0；已过期进度钳制 100；查询抛错 500', async () => {
    __mock.setRoutes([PERM, { match: /FROM dtest2\.selection_rounds r/, result: [
      { round_id: 'r1', name: 'a', status: 'notStarted', start_time: null, end_time: null, start_raw: null, end_raw: null, participants: '0', selections: '0', avg_credit: '0' },
      { round_id: 'r2', name: 'b', status: 'ended', start_time: '2020-01-01 00:00', end_time: '2020-02-01 00:00', start_raw: '2020-01-01T00:00:00Z', end_raw: '2020-02-01T00:00:00Z', participants: '1', selections: '1', avg_credit: '2' }
    ] }]);
    const res = await request(app).get('/api/admin/selection/stats').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data[0].progressPercent).toBe(0);
    expect(res.body.data[1].progressPercent).toBe(100);

    __mock.setRoutes([PERM, { match: /FROM dtest2\.selection_rounds r/, result: new Error('down') }]);
    expect((await request(app).get('/api/admin/selection/stats').set('Authorization', adm)).status).toBe(500);
  });

  test('评教统计：answers 非数组/rating 回退/越界分跳过/零样本默认值', async () => {
    __mock.setRoutes([
      PERM,
      { match: /AS total_tasks/, result: [{ total_tasks: '0', submitted_tasks: '0', task_students: '0', submitted_students: '0', term: null }] },
      { match: /SELECT answers_json/, result: [
        { answers_json: 'not-an-array' },
        { answers_json: [{ rating: 3 }, { score: 99 }, { noScore: true }] }
      ] }
    ]);
    const res = await request(app).get('/api/admin/eval/stats').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.term).toBe('2025-2026-2');
    expect(res.body.data.participationRate).toBe(0);
    expect(res.body.data.completionRate).toBe(0);
    expect(res.body.data.averageScore).toBe(3);
    expect(res.body.data.ratingDistribution.find((b) => b.star === 3).count).toBe(1);
  });

  test('评教统计：查询抛错 → 500', async () => {
    __mock.setRoutes([PERM, { match: /AS total_tasks/, result: new Error('down') }]);
    expect((await request(app).get('/api/admin/eval/stats').set('Authorization', adm)).status).toBe(500);
  });

  test('轮次状态/时间端点：查询抛错 500 与时间端点轮次不存在 404', async () => {
    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.selection_rounds/, result: new Error('down') }]);
    expect((await request(app).put('/api/admin/selection/rounds/r1/status').set('Authorization', adm)
      .send({ status: 'ended' })).status).toBe(500);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.selection_rounds/, result: [] }]);
    expect((await request(app).put('/api/admin/selection/rounds/r1/time').set('Authorization', adm)
      .send({ startTime: '2026-06-01 09:00', endTime: '2026-06-30 22:00' })).status).toBe(404);

    __mock.setRoutes([PERM, { match: /SELECT status FROM dtest2\.selection_rounds/, result: new Error('down') }]);
    expect((await request(app).put('/api/admin/selection/rounds/r1/time').set('Authorization', adm)
      .send({ startTime: '2026-06-01 09:00', endTime: '2026-06-30 22:00' })).status).toBe(500);
  });

  test('教学日历：日期/标题/类型校验 400、删除 404、查询抛错 500', async () => {
    __mock.setRoutes([PERM]);
    const base = { date: '2026-06-10', title: '校历事件', type: 'term' };
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm)
      .send(Object.assign({}, base, { date: '2026/06/10' }))).status).toBe(400);
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm)
      .send(Object.assign({}, base, { title: '' }))).status).toBe(400);
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm)
      .send(Object.assign({}, base, { title: '长'.repeat(61) }))).status).toBe(400);
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm)
      .send(Object.assign({}, base, { type: 'weird' }))).status).toBe(400);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.calendar_events/, result: [] }]);
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm).send(base)).status).toBe(200);

    __mock.setRoutes([PERM, { match: /INSERT INTO dtest2\.calendar_events/, result: new Error('down') }]);
    expect((await request(app).post('/api/admin/calendar').set('Authorization', adm).send(base)).status).toBe(500);

    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.calendar_events/, result: [] }]);
    expect((await request(app).delete('/api/admin/calendar/x').set('Authorization', adm)).status).toBe(404);

    __mock.setRoutes([PERM, { match: /DELETE FROM dtest2\.calendar_events/, result: new Error('down') }]);
    expect((await request(app).delete('/api/admin/calendar/x').set('Authorization', adm)).status).toBe(500);

    __mock.setRoutes([{ match: /FROM dtest2\.calendar_events/, result: new Error('down') }]);
    expect((await request(app).get('/api/calendar').set('Authorization', stu)).status).toBe(500);
  });
});

// ====================== 成绩域 grades.routes ======================

describe('grades.routes 分支', () => {
  test('term 过滤参数生效', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.grades g/, result: [{
      grade_id: 'g1', term: '2025-2026-2', score: '92', grade_point: '4.0', rank: 1, published_at: '2026-06-10',
      code: 'C1', teaching_class_no: '01', name: '课', category: 'required', credit: '2'
    }] }]);
    const res = await request(app).get('/api/grades?term=2025-2026-2').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data[0].score).toBe(92);
    const sel = __mock.getLog().find((e) => e.sql.indexOf('FROM dtest2.grades') >= 0);
    expect(sel.params[1]).toBe('2025-2026-2');
  });

  test('token 无学号 → 400；查询抛错 → 500', async () => {
    const empty = `Bearer ${signToken({ sub: '', role: 'student' })}`;
    expect((await request(app).get('/api/grades').set('Authorization', empty)).status).toBe(400);

    __mock.setRoutes([{ match: /FROM dtest2\.grades g/, result: new Error('down') }]);
    expect((await request(app).get('/api/grades').set('Authorization', stu)).status).toBe(500);
  });
});
