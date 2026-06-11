// 审计落库中间件：写操作/认证事件自动入库、GET 不记录、按账号过滤与账号清单端点。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const adm = `Bearer ${signToken({ sub: 'A20251001', role: 'admin' })}`;
const PERM_GRANT = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

// 审计写入在响应 finish 后异步执行，等一个短 tick 再断言
const tick = () => new Promise((resolve) => setTimeout(resolve, 30));

beforeEach(() => __mock.reset());

function auditInsert() {
  return __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.audit_logs') >= 0);
}

describe('审计中间件自动落库', () => {
  test('登录成功 → 记录 login 事件（账号 + success）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.accounts WHERE account_id/, result: [] }
    ]);
    await request(app).post('/api/auth/login').send({ account: 'A20251001', password: 'x' });
    await tick();
    const ins = auditInsert();
    expect(ins).toBeDefined();
    expect(ins.params).toContain('A20251001');
    expect(ins.params).toContain('登录');
    // 账号不存在 → 401 → failed
    expect(ins.params).toContain('failed');
    // 密码绝不入库
    expect(JSON.stringify(ins.params)).not.toContain('"x"');
  });

  test('学生选课 → 记录 selection 事件（目标=课程 id）', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.selection_rounds/, result: [] }
    ]);
    await request(app).post('/api/selections').set('Authorization', stu).send({ courseId: 'CER20101' });
    await tick();
    const ins = auditInsert();
    expect(ins).toBeDefined();
    expect(ins.params).toContain('2023307020941');
    expect(ins.params).toContain('选课');
    expect(ins.params).toContain('CER20101');
  });

  test('GET 只读请求不写审计', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.courses c/, result: [] }]);
    await request(app).get('/api/courses').set('Authorization', stu);
    await tick();
    expect(auditInsert()).toBeUndefined();
  });

  test('请求验证码 → 邮箱脱敏入库', async () => {
    await request(app).post('/api/auth/verify-email-code').send({ email: 'student@example.com', code: '000000' });
    await tick();
    const ins = auditInsert();
    expect(ins).toBeDefined();
    expect(ins.params).toContain('st***@example.com');
    expect(JSON.stringify(ins.params)).not.toContain('student@example.com');
  });

  test('审计写入失败不阻断业务响应', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.audit_logs/, result: new Error('audit down') },
      { match: /FROM dtest2\.selection_rounds/, result: [] }
    ]);
    const res = await request(app).post('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(res.status).toBe(409);
    await tick();
  });
});

describe('按账号查询日志', () => {
  test('GET /api/admin/audit-logs?operator= 过滤参数透传', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /FROM dtest2\.audit_logs/, result: [] }]);
    const res = await request(app).get('/api/admin/audit-logs?operator=2023307020941').set('Authorization', adm);
    expect(res.status).toBe(200);
    const q = __mock.getLog().find((e) => e.sql.indexOf('FROM dtest2.audit_logs') >= 0 && e.sql.indexOf('ORDER BY created_at') >= 0);
    expect(q.params).toContain('2023307020941');
  });

  test('GET /api/admin/audit-operators 返回账号分组清单', async () => {
    __mock.setRoutes([
      PERM_GRANT,
      { match: /GROUP BY operator_id/, result: [
        { operator_id: 'A20251001', operator_name: '爱莉希雅', log_count: 12, last_at: '2026-06-11T01:00:00Z' },
        { operator_id: '2023307020941', operator_name: '李仕炜', log_count: 5, last_at: '2026-06-11T00:30:00Z' }
      ] }
    ]);
    const res = await request(app).get('/api/admin/audit-operators').set('Authorization', adm);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data[0].operatorId).toBe('A20251001');
    expect(res.body.data[1].logCount).toBe(5);
  });

  test('学生 token → 403', async () => {
    const res = await request(app).get('/api/admin/audit-operators').set('Authorization', stu);
    expect(res.status).toBe(403);
  });

  test('账号清单查询失败 → 500 通用文案', async () => {
    __mock.setRoutes([PERM_GRANT, { match: /GROUP BY operator_id/, result: new Error('boom') }]);
    const res = await request(app).get('/api/admin/audit-operators').set('Authorization', adm);
    expect(res.status).toBe(500);
    expect(res.body.error).not.toContain('boom');
  });
});
