// 实践报名事务：审查问题4（行锁防并发超名额）+ 名额/重复校验分支。
jest.mock('../src/db', () => require('./helpers/dbMock'));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const token = signToken({ sub: '2023307020941', role: 'student' });

function routes(overrides = {}) {
  const d = {
    proj: [{ slots_total: 8 }],
    existing: [],
    count: [{ n: 0 }],
    insert: [],
    detail: [{
      project_id: 'p1', title: '数据结构实训', org: '计算机学院', category: '专业实践',
      credits: 2, period: '2026春', location: '实训楼', mentor: '王老师',
      slots_total: 8, slots_taken: 6, signed_up: true, description: '', requirements_json: []
    }]
  };
  const c = Object.assign({}, d, overrides);
  return [
    { match: /FROM dtest2\.practice_projects WHERE project_id=\$1 FOR UPDATE/, result: c.proj },
    { match: /SELECT status FROM dtest2\.practice_signups WHERE project_id/, result: c.existing },
    { match: /COUNT\(\*\)::int AS n FROM dtest2\.practice_signups/, result: c.count },
    { match: /INSERT INTO dtest2\.practice_signups/, result: c.insert },
    { match: /FROM dtest2\.practice_projects p/, result: c.detail }
  ];
}

function signup() {
  return request(app).post('/api/practice/p1/signup').set('Authorization', `Bearer ${token}`);
}

beforeEach(() => __mock.reset());

describe('POST /api/practice/:id/signup', () => {
  test('正常报名 → 200', async () => {
    __mock.setRoutes(routes());
    const res = await signup();
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('问题4：报名对项目行加 FOR UPDATE 行锁', async () => {
    __mock.setRoutes(routes());
    await signup();
    expect(__mock.executed('FOR UPDATE')).toBe(true);
  });

  test('项目不存在 → 404 且回滚', async () => {
    __mock.setRoutes(routes({ proj: [] }));
    const res = await signup();
    expect(res.status).toBe(404);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('重复报名 → 409', async () => {
    __mock.setRoutes(routes({ existing: [{ status: 'signedUp' }] }));
    const res = await signup();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('已报名');
  });

  test('名额已满 → 409', async () => {
    __mock.setRoutes(routes({ count: [{ n: 8 }] }));
    const res = await signup();
    expect(res.status).toBe(409);
    expect(res.body.error).toContain('名额已满');
  });
});
