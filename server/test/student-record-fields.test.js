// 学籍注册字段（roadmap #3）测试：
//   1. GET /api/profile/record 返回新字段（null-safe）
//   2. PUT /api/admin/students/:id/record 写字段并防越权
jest.mock('../src/db', () => require('./helpers/dbMock'));

const request = require('supertest');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');
const app = require('../src/index');

const STU = '2023001';
const stuToken = signToken({ sub: STU, role: 'student' });
const stuAuth = `Bearer ${stuToken}`;

const ADMIN = 'admin-001';
const adminToken = signToken({ sub: ADMIN, role: 'admin' });
const adminAuth = `Bearer ${adminToken}`;

// 权限检查 mock：让 permissionRequired 校验通过（admin_profiles → role_permissions 联查返回 1 行）
const PERM = { match: /FROM dtest2\.admin_profiles ap/, result: [{ ok: 1 }] };

beforeEach(() => __mock.reset());

// ---- 辅助：构造 student_profiles 行（含新字段）----
function makeProfileRow(overrides = {}) {
  return Object.assign(
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
      political_status: null,
      ethnicity: null,
      native_place: null,
      enrollment_date: null,
      program_length: null,
      education_level: null,
      enrollment_status: null,
      gpa: null,
      earned_credits: null,
      passed_count: null
    },
    overrides
  );
}

describe('GET /api/profile/record — 学籍注册字段', () => {
  test('200：新字段有值时正确返回（camelCase 映射）', async () => {
    __mock.setRoutes([
      {
        match: /FROM dtest2\.student_profiles sp/,
        result: [
          makeProfileRow({
            political_status: '共青团员',
            ethnicity: '汉族',
            native_place: '江西省景德镇市',
            enrollment_date: '2023-09-01',
            program_length: '4年',
            education_level: '本科',
            enrollment_status: '在读',
            gpa: '3.5',
            earned_credits: '18',
            passed_count: '6'
          })
        ]
      }
    ]);

    const res = await request(app)
      .get('/api/profile/record')
      .set('Authorization', stuAuth);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const rec = res.body.data;
    expect(rec.politicalStatus).toBe('共青团员');
    expect(rec.ethnicity).toBe('汉族');
    expect(rec.nativePlace).toBe('江西省景德镇市');
    expect(rec.enrollmentDate).toBe('2023-09-01');
    expect(rec.programLength).toBe('4年');
    expect(rec.educationLevel).toBe('本科');
    expect(rec.enrollmentStatus).toBe('在读');
  });

  test('200：新字段 null 时返回 null（不编造假值）', async () => {
    __mock.setRoutes([
      {
        match: /FROM dtest2\.student_profiles sp/,
        result: [makeProfileRow()]
      }
    ]);

    const res = await request(app)
      .get('/api/profile/record')
      .set('Authorization', stuAuth);

    expect(res.status).toBe(200);
    const rec = res.body.data;
    expect(rec.politicalStatus).toBeNull();
    expect(rec.ethnicity).toBeNull();
    expect(rec.nativePlace).toBeNull();
    expect(rec.enrollmentDate).toBeNull();
    expect(rec.programLength).toBeNull();
    expect(rec.educationLevel).toBeNull();
    expect(rec.enrollmentStatus).toBeNull();
  });

  test('JWT 防越权：学号取自 token，不取 query/body', async () => {
    __mock.setRoutes([
      {
        match: /FROM dtest2\.student_profiles sp/,
        result: [makeProfileRow()]
      }
    ]);

    // 请求者 token 学号 = STU；即使带 query 也只查 STU
    const res = await request(app)
      .get('/api/profile/record?studentId=EVIL-999')
      .set('Authorization', stuAuth);

    expect(res.status).toBe(200);
    // 确认查询 SQL 参数为 JWT 学号，不含攻击者学号
    const entry = __mock.getLog().find((e) => /FROM dtest2\.student_profiles sp/.test(e.sql));
    expect(entry).toBeDefined();
    expect(entry.params[0]).toBe(STU);
    expect(entry.params[0]).not.toBe('EVIL-999');
  });
});

describe('PUT /api/admin/students/:id/record — 管理端写学籍字段', () => {
  test('200：写全部新字段，SQL 按学号更新', async () => {
    __mock.setRoutes([
      PERM,
      {
        match: /UPDATE dtest2\.student_profiles/,
        result: [{ rowCount: 1 }]
      }
    ]);

    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({
        politicalStatus: '中共党员',
        ethnicity: '回族',
        nativePlace: '新疆维吾尔自治区',
        enrollmentDate: '2023-09-01',
        programLength: '4年',
        educationLevel: '本科',
        enrollmentStatus: '在读'
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.updated).toBe(true);
    expect(res.body.data.studentId).toBe(STU);

    // 断言 SQL 含目标字段，参数列表含学号（最后一个参数）
    const entry = __mock.getLog().find((e) => /UPDATE dtest2\.student_profiles/.test(e.sql));
    expect(entry).toBeDefined();
    expect(entry.sql).toContain('political_status');
    expect(entry.sql).toContain('enrollment_status');
    expect(entry.params[entry.params.length - 1]).toBe(STU);
  });

  test('200：部分字段更新（仅提交的字段写 DB）', async () => {
    __mock.setRoutes([
      PERM,
      {
        match: /UPDATE dtest2\.student_profiles/,
        result: [{ rowCount: 1 }]
      }
    ]);

    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({ enrollmentStatus: '休学' });

    expect(res.status).toBe(200);
    const entry = __mock.getLog().find((e) => /UPDATE dtest2\.student_profiles/.test(e.sql));
    expect(entry.sql).toContain('enrollment_status');
    expect(entry.sql).not.toContain('ethnicity');
  });

  test('200：null 值清空字段', async () => {
    __mock.setRoutes([
      PERM,
      {
        match: /UPDATE dtest2\.student_profiles/,
        result: [{ rowCount: 1 }]
      }
    ]);

    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({ politicalStatus: null });

    expect(res.status).toBe(200);
    const entry = __mock.getLog().find((e) => /UPDATE dtest2\.student_profiles/.test(e.sql));
    expect(entry).toBeDefined();
    // null 参数写入
    expect(entry.params).toContain(null);
  });

  test('400：enrollment_date 格式错误', async () => {
    __mock.setRoutes([PERM]);
    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({ enrollmentDate: '不是日期' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('400：没有提交任何可更新字段', async () => {
    __mock.setRoutes([PERM]);
    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('404：学生不存在（rowCount=0）', async () => {
    __mock.setRoutes([
      PERM,
      {
        match: /UPDATE dtest2\.student_profiles/,
        result: []
      }
    ]);

    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', adminAuth)
      .send({ enrollmentStatus: '毕业' });

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('401：未登录', async () => {
    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .send({ enrollmentStatus: '在读' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('403：学生 token 无法访问管理端接口', async () => {
    const res = await request(app)
      .put(`/api/admin/students/${STU}/record`)
      .set('Authorization', stuAuth)
      .send({ enrollmentStatus: '在读' });

    // 学生 token 无 students.manage:update 权限，期望 403
    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });
});
