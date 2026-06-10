// 数据库管理域：表白名单校验、行查询、按主键增删改、鉴权（system.config，fail-closed）。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

const TABLE_OK = { match: /information_schema\.tables/, result: [{ table_name: 'class_students' }] };
const COLUMNS = {
  match: /information_schema\.columns/,
  result: [
    { column_name: 'student_id', data_type: 'text', is_nullable: 'NO', column_default: null },
    { column_name: 'name', data_type: 'text', is_nullable: 'NO', column_default: null },
    { column_name: 'gender', data_type: 'text', is_nullable: 'YES', column_default: null }
  ]
};
const PK = { match: /pg_index/, result: [{ column_name: 'student_id' }] };

beforeEach(() => __mock.reset());

describe('鉴权', () => {
  test('无 token → 401', async () => {
    const res = await request(app).get('/api/admin/db/tables');
    expect(res.status).toBe(401);
  });

  test('学生 token → 403', async () => {
    const res = await request(app).get('/api/admin/db/tables').set('Authorization', stu);
    expect(res.status).toBe(403);
  });

  test('管理员无 system.config 权限 → 403（fail-closed）', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.admin_profiles ap/, result: [] }]);
    const res = await request(app).get('/api/admin/db/tables').set('Authorization', adm);
    expect(res.status).toBe(403);
  });
});

describe('GET /api/admin/db/tables', () => {
  test('返回表清单与行数', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      TABLE_OK,
      { match: /SELECT count\(\*\) AS n FROM dtest2\."class_students"/, result: [{ n: '47' }] }
    ]);
    const res = await request(app).get('/api/admin/db/tables').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data[0]).toEqual({ name: 'class_students', rows: 47 });
  });
});

describe('GET /api/admin/db/tables/:table/rows', () => {
  test('非法表名 → 404（不触发任何拼接查询）', async () => {
    __mock.setRoutes([PERM_GRANT]);
    const res = await request(app).get('/api/admin/db/tables/Robert%22%3BDROP/rows').set('Authorization', adm);
    expect(res.status).toBe(404);
  });

  test('白名单外的表 → 404', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /information_schema\.tables/, result: [] }]);
    const res = await request(app).get('/api/admin/db/tables/nosuch/rows').set('Authorization', adm);
    expect(res.status).toBe(404);
  });

  test('返回列元数据 + 分页行', async () => {
    __mock.setRoutes([
      PERM_GRANT, TABLE_OK, COLUMNS, PK,
      { match: /SELECT count\(\*\) AS n FROM dtest2\."class_students"/, result: [{ n: '1' }] },
      { match: /SELECT \* FROM dtest2\."class_students"/, result: [{ student_id: '2023307020941', name: '李仕炜', gender: '男' }] }
    ]);
    const res = await request(app).get('/api/admin/db/tables/class_students/rows').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data.pk).toEqual(['student_id']);
    expect(res.body.data.columns).toHaveLength(3);
    expect(res.body.data.columns[0]).toMatchObject({ name: 'student_id', pk: true });
    expect(res.body.data.rows[0].name).toBe('李仕炜');
  });
});

describe('写操作', () => {
  test('INSERT：仅接受真实列并 RETURNING', async () => {
    __mock.setRoutes([
      PERM_GRANT, TABLE_OK, COLUMNS, PK,
      { match: /INSERT INTO dtest2\."class_students"/, result: [{ student_id: 's1', name: '新生', gender: null }] }
    ]);
    const res = await request(app).post('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ values: { student_id: 's1', name: '新生', evil_column: 'x' } });
    expect(res.status).toBe(200);
    expect(res.body.data.row.name).toBe('新生');
    const insertSql = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2."class_students"') >= 0);
    expect(insertSql.sql).not.toContain('evil_column');
  });

  test('UPDATE：缺主键 → 400', async () => {
    __mock.setRoutes([PERM_GRANT, TABLE_OK, COLUMNS, PK]);
    const res = await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: {}, values: { name: '改名' } });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('主键');
  });

  test('UPDATE：按主键更新并 RETURNING', async () => {
    __mock.setRoutes([
      PERM_GRANT, TABLE_OK, COLUMNS, PK,
      { match: /UPDATE dtest2\."class_students" SET/, result: [{ student_id: 's1', name: '改名', gender: '男' }] }
    ]);
    const res = await request(app).put('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' }, values: { name: '改名' } });
    expect(res.status).toBe(200);
    expect(res.body.data.row.name).toBe('改名');
  });

  test('DELETE：主键不匹配 → 404', async () => {
    __mock.setRoutes([
      PERM_GRANT, TABLE_OK, PK,
      { match: /DELETE FROM dtest2\."class_students"/, result: [] }
    ]);
    const res = await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 'nope' } });
    expect(res.status).toBe(404);
  });

  test('DELETE：按主键删除成功', async () => {
    __mock.setRoutes([
      PERM_GRANT, TABLE_OK, PK,
      { match: /DELETE FROM dtest2\."class_students"/, result: [{ deleted: 1 }] }
    ]);
    const res = await request(app).delete('/api/admin/db/tables/class_students/rows').set('Authorization', adm)
      .send({ pk: { student_id: 's1' } });
    expect(res.status).toBe(200);
    expect(res.body.data.deleted).toBe(true);
  });
});
