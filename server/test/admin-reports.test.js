// 管理端报表导出域：成绩/选课/评教统计 Excel(xlsx) 下载。
// 校验权限闸门（401/403）、未知类型 400，以及成功分支的 Content-Type + 非空二进制体。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };
const PERM_DENY = { match: /FROM dtest2\.admin_profiles ap/, result: [] };

const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

beforeEach(() => __mock.reset());

describe('GET /api/admin/reports/grades/export', () => {
  test('成功 → 200 + xlsx Content-Type + 非空二进制体', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /AS grade_pending/, result: [{ grade_pending: '2', grade_published: '5', grade_total: '9' }] }
    ]);
    const res = await request(app)
      .get('/api/admin/reports/grades/export')
      .set('Authorization', adm)
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (ch) => chunks.push(Buffer.from(ch)));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe(XLSX_MIME);
    expect(res.headers['content-disposition']).toMatch(/attachment; filename="report-grades-\d{8}\.xlsx"/);
    expect(Buffer.isBuffer(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    // xlsx 即 zip：以 'PK' 魔数开头，确认是真实工作簿字节
    expect(res.body.slice(0, 2).toString()).toBe('PK');
  });

  test('无 token → 401', async () => {
    const res = await request(app).get('/api/admin/reports/grades/export');
    expect(res.status).toBe(401);
  });

  test('学生 token → 403', async () => {
    const res = await request(app).get('/api/admin/reports/grades/export').set('Authorization', stu);
    expect(res.status).toBe(403);
  });

  test('无权限管理员 → 403（fail-closed）', async () => {
    __mock.setRoutes([PERM_DENY]);
    const res = await request(app).get('/api/admin/reports/grades/export').set('Authorization', adm);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/admin/reports/selection/export', () => {
  test('成功 → 200 + xlsx + 非空体', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /FROM dtest2\.selection_rounds r/, result: [{
        round_id: 'round-2026-main', name: '2026 春主轮', status: 'running',
        start_time: '2026-06-01 00:00', end_time: '2026-07-01 00:00',
        participants: '1', selections: '2', avg_credit: '4.50'
      }] }
    ]);
    const res = await request(app)
      .get('/api/admin/reports/selection/export')
      .set('Authorization', adm)
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (ch) => chunks.push(Buffer.from(ch)));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe(XLSX_MIME);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('无权限管理员 → 403', async () => {
    __mock.setRoutes([PERM_DENY]);
    const res = await request(app).get('/api/admin/reports/selection/export').set('Authorization', adm);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/admin/reports/evaluation/export', () => {
  test('成功 → 200 + xlsx + 非空体', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /AS total_tasks/, result: [{ total_tasks: '9', submitted_tasks: '3', task_students: '1', submitted_students: '1', term: '2025-2026-2' }] },
      { match: /SELECT answers_json/, result: [{ answers_json: [{ questionId: 'q-1', score: 5 }, { questionId: 'q-4', score: 4 }] }] }
    ]);
    const res = await request(app)
      .get('/api/admin/reports/evaluation/export')
      .set('Authorization', adm)
      .buffer(true)
      .parse((r, cb) => {
        const chunks = [];
        r.on('data', (ch) => chunks.push(Buffer.from(ch)));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe(XLSX_MIME);
    expect(res.body.length).toBeGreaterThan(0);
  });
});

describe('未知报表类型', () => {
  test('GET /api/admin/reports/nosuch/export → 400', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).get('/api/admin/reports/nosuch/export').set('Authorization', adm);
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toContain('nosuch');
  });
});
