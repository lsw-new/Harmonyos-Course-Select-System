// 学籍详情补真 + 登录历史两个 GET 端点的接口测试（supertest + dbMock）。
// 仅覆盖新增端点，不触碰 PUT /api/profile 行为。
jest.mock('../src/db', () => require('./helpers/dbMock'));

const request = require('supertest');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');
const app = require('../src/index');

const STU = '2023001';
const token = signToken({ sub: STU, role: 'student' });
const auth = `Bearer ${token}`;

beforeEach(() => __mock.reset());

describe('GET /api/profile/record', () => {
  test('200：返回学籍详情，GPA/学分/门数来自聚合而非写死', async () => {
    __mock.setRoutes([
      {
        match: /FROM dtest2\.student_profiles sp/,
        result: [
          {
            student_id: STU,
            name: '李仕炜',
            avatar_url: null,
            college: '数字媒体学院',
            major: '数字媒体艺术',
            class_name: '数媒2301',
            grade: '2023',
            phone: '138****0000',
            email: 'lsw@example.com',
            address: '宿舍A',
            emergency_contact: '父亲',
            bio: '你好',
            // 聚合子查询的真实回行（非端点写死）
            gpa: '3.5',
            earned_credits: '18',
            passed_count: '6'
          }
        ]
      }
    ]);

    const res = await request(app)
      .get('/api/profile/record')
      .set('Authorization', auth);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const rec = res.body.data;
    expect(rec.studentId).toBe(STU);
    expect(rec.name).toBe('李仕炜');
    expect(rec.className).toBe('数媒2301');
    // 关键：聚合值来自 mock 行（3.5 / 18 / 6），证明非写死常量
    expect(rec.gpa).toBe(3.5);
    expect(rec.earnedCredits).toBe(18);
    expect(rec.passedCount).toBe(6);
    // 数据库确无字段返回 null（不编造）
    expect(rec.advisor).toBeNull();
    expect(rec.dormitory).toBeNull();
    expect(rec.eduSystem).toBeNull();
    expect(rec.trainingType).toBeNull();

    // 断言聚合 SQL 真在按 published_at 过滤（真实聚合而非常量）
    expect(__mock.executed('published_at IS NOT NULL')).toBe(true);
    expect(__mock.executed('AVG(g.grade_point)')).toBe(true);
  });

  test('200：无已发布成绩时 GPA=null、学分/门数=0', async () => {
    __mock.setRoutes([
      {
        match: /FROM dtest2\.student_profiles sp/,
        result: [
          {
            student_id: STU,
            name: '李仕炜',
            avatar_url: null,
            college: '数字媒体学院',
            major: '数字媒体艺术',
            class_name: '数媒2301',
            grade: '2023',
            phone: null,
            email: null,
            address: null,
            emergency_contact: null,
            bio: null,
            gpa: null,
            earned_credits: null,
            passed_count: null
          }
        ]
      }
    ]);

    const res = await request(app)
      .get('/api/profile/record')
      .set('Authorization', auth);

    expect(res.status).toBe(200);
    expect(res.body.data.gpa).toBeNull();
    expect(res.body.data.earnedCredits).toBe(0);
    expect(res.body.data.passedCount).toBe(0);
  });

  test('404：学生资料不存在', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.student_profiles sp/, result: [] }]);
    const res = await request(app)
      .get('/api/profile/record')
      .set('Authorization', auth);
    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('401：未登录', async () => {
    const res = await request(app).get('/api/profile/record');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});

describe('GET /api/profile/login-history', () => {
  test('200：返回最近登录事件（camelCase 映射）', async () => {
    // 查询现取 login+logout 两类（升序），端点内部配对后返回近 10 条 login 倒序。
    __mock.setRoutes([
      {
        match: /FROM dtest2\.audit_logs/,
        result: [
          { log_id: 'log-1', action: '登录', action_type: 'login', result: 'failed', ip: '5.6.7.8', geo: '', created_at: '2026-06-18T09:00:00Z' },
          { log_id: 'log-2', action: '登录', action_type: 'login', result: 'success', ip: '1.2.3.4', geo: '江西省·景德镇市', created_at: '2026-06-19T10:00:00Z' }
        ]
      }
    ]);

    const res = await request(app)
      .get('/api/profile/login-history')
      .set('Authorization', auth);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data).toHaveLength(2);
    // 时间倒序：最近一条在前
    expect(res.body.data[0]).toEqual({
      id: 'log-2',
      action: '登录',
      result: 'success',
      ip: '1.2.3.4',
      location: '江西省·景德镇市',
      durationMinutes: null,
      time: '2026-06-19T10:00:00Z'
    });
    // 断言取本账号的 login/logout 类事件
    expect(__mock.executed("action_type IN ('login', 'logout')")).toBe(true);
    const logEntry = __mock.getLog().find((e) => /FROM dtest2\.audit_logs/.test(e.sql));
    expect(logEntry.params[0]).toBe(STU);
  });

  test('200：无记录时返回空数组', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.audit_logs/, result: [] }]);
    const res = await request(app)
      .get('/api/profile/login-history')
      .set('Authorization', auth);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('401：未登录', async () => {
    const res = await request(app).get('/api/profile/login-history');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});
