// 分支覆盖补测（学生域 + 认证域）：通知/请假/反馈/实践/评教/课表/资料/选课/认证的
// 异常分支——catch 500、校验 4xx、节流 429、SMTP 550 精确提示、事务回滚。
jest.mock('../src/db', () => require('./helpers/dbMock'));
jest.mock('../src/email', () => ({ sendVerificationCode: jest.fn() }));
const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');
const { sendVerificationCode } = require('../src/email');
const codeStore = require('../src/codeStore');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const emptySub = `Bearer ${signToken({ sub: '', role: 'student' })}`;
const boom = () => new Error('db down');

beforeEach(() => {
  __mock.reset();
  sendVerificationCode.mockReset();
});

// ====================== 通知域 ======================

describe('notices 异常分支', () => {
  test('列表/详情查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.notices n/, result: boom() }]);
    expect((await request(app).get('/api/notices').set('Authorization', stu)).status).toBe(500);
    expect((await request(app).get('/api/notices/n1').set('Authorization', stu)).status).toBe(500);
  });

  test('标记已读：token 无学号 400；写入抛错 500', async () => {
    expect((await request(app).post('/api/notices/n1/read').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.notice_reads/, result: boom() }]);
    expect((await request(app).post('/api/notices/n1/read').set('Authorization', stu)).status).toBe(500);
  });
});

// ====================== 请假域 ======================

describe('leave 异常分支', () => {
  test('列表：token 无学号 400；查询抛错 500', async () => {
    expect((await request(app).get('/api/leave').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.leave_requests/, result: boom() }]);
    expect((await request(app).get('/api/leave').set('Authorization', stu)).status).toBe(500);
  });

  test('提交：信息不完整 400；事务内抛错 500 且回滚', async () => {
    const r400 = await request(app).post('/api/leave').set('Authorization', stu)
      .send({ type: 'sick', startDate: '', endDate: '2026-06-12', reason: 'r' });
    expect(r400.status).toBe(400);

    __mock.setRoutes([{ match: /INSERT INTO dtest2\.leave_requests/, result: boom() }]);
    const r500 = await request(app).post('/api/leave').set('Authorization', stu)
      .send({ type: 'sick', startDate: '2026-06-11', endDate: '2026-06-12', reason: 'r' });
    expect(r500.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });
});

// ====================== 反馈域 ======================

describe('feedback 异常分支', () => {
  test('列表：token 无学号 400；查询/写入抛错 500', async () => {
    expect((await request(app).get('/api/feedback').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.feedback_items/, result: boom() }]);
    expect((await request(app).get('/api/feedback').set('Authorization', stu)).status).toBe(500);
    __mock.setRoutes([{ match: /INSERT INTO dtest2\.feedback_items/, result: boom() }]);
    expect((await request(app).post('/api/feedback').set('Authorization', stu)
      .send({ category: 'bug', title: 't', content: 'c' })).status).toBe(500);
  });
});

// ====================== 实践域 ======================

describe('practice 异常分支', () => {
  test('列表/详情：查询抛错 500；详情不存在 404', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.practice_projects/, result: boom() }]);
    expect((await request(app).get('/api/practice').set('Authorization', stu)).status).toBe(500);
    expect((await request(app).get('/api/practice/p1').set('Authorization', stu)).status).toBe(500);

    __mock.setRoutes([{ match: /FROM dtest2\.practice_projects/, result: [] }]);
    expect((await request(app).get('/api/practice/p1').set('Authorization', stu)).status).toBe(404);
  });

  test('报名：token 无学号 400；事务内抛错 500 且回滚', async () => {
    expect((await request(app).post('/api/practice/p1/signup').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FOR UPDATE/, result: boom() }]);
    const r = await request(app).post('/api/practice/p1/signup').set('Authorization', stu);
    expect(r.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('取消报名：token 无学号 400；未报名 404；更新抛错 500', async () => {
    expect((await request(app).delete('/api/practice/p1/signup').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /UPDATE dtest2\.practice_signups/, result: [] }]);
    expect((await request(app).delete('/api/practice/p1/signup').set('Authorization', stu)).status).toBe(404);
    __mock.setRoutes([{ match: /UPDATE dtest2\.practice_signups/, result: boom() }]);
    expect((await request(app).delete('/api/practice/p1/signup').set('Authorization', stu)).status).toBe(500);
  });
});

// ====================== 评教域（学生侧） ======================

describe('evaluations 异常分支', () => {
  test('评教期读：查询抛错 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.system_settings/, result: boom() }]);
    expect((await request(app).get('/api/eval-period').set('Authorization', stu)).status).toBe(500);
  });

  test('任务列表：token 无学号 400；查询抛错 500', async () => {
    expect((await request(app).get('/api/evaluations').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.evaluation_tasks et/, result: boom() }]);
    expect((await request(app).get('/api/evaluations').set('Authorization', stu)).status).toBe(500);
  });

  test('提交：无学号 400；答案空 400；开关查询抛错 500', async () => {
    expect((await request(app).post('/api/evaluations/t1/submit').set('Authorization', emptySub)
      .send({ answers: [{ score: 5 }] })).status).toBe(400);
    expect((await request(app).post('/api/evaluations/t1/submit').set('Authorization', stu)
      .send({ answers: [] })).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.system_settings/, result: boom() }]);
    expect((await request(app).post('/api/evaluations/t1/submit').set('Authorization', stu)
      .send({ answers: [{ score: 5 }] })).status).toBe(500);
  });

  test('提交：任务非开放期 409；事务内抛错 500 且回滚', async () => {
    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.evaluation_tasks/, result: [{ status: 'submitted' }] }]);
    const r409 = await request(app).post('/api/evaluations/t1/submit').set('Authorization', stu)
      .send({ answers: [{ score: 5 }] });
    expect(r409.status).toBe(409);
    expect(__mock.executed('ROLLBACK')).toBe(true);

    __mock.setRoutes([{ match: /SELECT status FROM dtest2\.evaluation_tasks/, result: boom() }]);
    expect((await request(app).post('/api/evaluations/t1/submit').set('Authorization', stu)
      .send({ answers: [{ score: 5 }] })).status).toBe(500);
  });
});

// ====================== 班级课表域 ======================

describe('schedule 异常分支', () => {
  test('token 无学号 → 400；查询抛错 → 500', async () => {
    expect((await request(app).get('/api/schedule').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.class_students/, result: boom() }]);
    expect((await request(app).get('/api/schedule').set('Authorization', stu)).status).toBe(500);
  });
});

// ====================== 个人资料域 ======================

describe('profile 校验矩阵与异常分支', () => {
  const PROFILE_ROW = { match: /FROM dtest2\.student_profiles/, result: [{ student_id: '2023307020941', name: '李仕炜', college: 'c', major: 'm', class_name: 'cl', grade: 'g', phone: null, email: null, address: null, emergency_contact: null, avatar_url: null, bio: null }] };

  test('头像清除（空串）与 https 链接均放行', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.student_profiles/, result: [{ u: 1 }] }, PROFILE_ROW]);
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ avatarUrl: '' })).status).toBe(200);
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ avatarUrl: 'https://example.com/a.png' })).status).toBe(200);
  });

  test('头像过大 400；普通字段超长 400', async () => {
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ avatarUrl: 'data:image/jpeg;base64,' + 'A'.repeat(200001) })).status).toBe(400);
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ phone: '1'.repeat(201) })).status).toBe(400);
  });

  test('学生资料不存在 404；更新抛错 500', async () => {
    __mock.setRoutes([{ match: /UPDATE dtest2\.student_profiles/, result: [] }]);
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ phone: '13800000000' })).status).toBe(404);
    __mock.setRoutes([{ match: /UPDATE dtest2\.student_profiles/, result: boom() }]);
    expect((await request(app).put('/api/profile').set('Authorization', stu)
      .send({ phone: '13800000000' })).status).toBe(500);
  });
});

// ====================== 选课域（学生侧补漏） ======================

describe('selection 学生侧补漏分支', () => {
  test('active 轮次：有 running 轮次时返回映射字段', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.selection_rounds/, result: [{
      round_id: 'r1', name: '2026 春', status: 'running',
      start_time: '2026-06-01T00:00:00Z', end_time: '2026-07-01T00:00:00Z', credit_limit: '30'
    }] }]);
    const res = await request(app).get('/api/selection-rounds/active').set('Authorization', stu);
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('r1');
    expect(res.body.data.creditLimit).toBe(30);
  });

  test('active 轮次查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.selection_rounds/, result: boom() }]);
    expect((await request(app).get('/api/selection-rounds/active').set('Authorization', stu)).status).toBe(500);
  });

  test('我的已选：token 无学号 400；查询抛错 500', async () => {
    expect((await request(app).get('/api/selections').set('Authorization', emptySub)).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.selections s/, result: boom() }]);
    expect((await request(app).get('/api/selections').set('Authorization', stu)).status).toBe(500);
  });

  test('选课：courseId 缺失 400；事务内抛错 500 且回滚', async () => {
    expect((await request(app).post('/api/selections').set('Authorization', stu)
      .send({ courseId: '  ' })).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.selection_rounds/, result: boom() }]);
    const r = await request(app).post('/api/selections').set('Authorization', stu).send({ courseId: 'c1' });
    expect(r.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('退课：courseId 缺失 400；轮次查询抛错 500', async () => {
    expect((await request(app).delete('/api/selections').set('Authorization', stu)
      .send({})).status).toBe(400);
    __mock.setRoutes([{ match: /FROM dtest2\.selection_rounds/, result: boom() }]);
    expect((await request(app).delete('/api/selections').set('Authorization', stu)
      .send({ courseId: 'c1' })).status).toBe(500);
  });
});

// ====================== 认证域 ======================

describe('auth 异常分支', () => {
  test('发码：60 秒节流 → 429', async () => {
    sendVerificationCode.mockResolvedValue(undefined);
    const first = await request(app).post('/api/auth/email-code').send({ email: 'throttle@test.com' });
    expect(first.status).toBe(200);
    const second = await request(app).post('/api/auth/email-code').send({ email: 'throttle@test.com' });
    expect(second.status).toBe(429);
  });

  test('发码：SMTP 550 收件人不存在 → 400 精确提示；其他发送失败 → 500', async () => {
    const e550 = new Error('550 user not found');
    e550.responseCode = 550;
    sendVerificationCode.mockRejectedValueOnce(e550);
    const r400 = await request(app).post('/api/auth/email-code').send({ email: 'no-such@test.com' });
    expect(r400.status).toBe(400);
    expect(r400.body.error).toContain('邮箱');

    sendVerificationCode.mockRejectedValueOnce(new Error('smtp down'));
    const r500 = await request(app).post('/api/auth/email-code').send({ email: 'down@test.com' });
    expect(r500.status).toBe(500);
  });

  test('验码：缺参 400；错码 400；正确码 200 且消费', async () => {
    expect((await request(app).post('/api/auth/verify-email-code').send({ email: 'bad', code: '1' })).status).toBe(400);
    expect((await request(app).post('/api/auth/verify-email-code')
      .send({ email: 'verify@test.com', code: '000000' })).status).toBe(400);
    const code = codeStore.issue('verify@test.com');
    const okRes = await request(app).post('/api/auth/verify-email-code').send({ email: 'verify@test.com', code });
    expect(okRes.status).toBe(200);
    expect(okRes.body.data.valid).toBe(true);
  });

  test('注册：密码过短 400；名册查询抛错 500；事务内抛错 500 且回滚', async () => {
    expect((await request(app).post('/api/auth/register')
      .send({ studentId: '2023307020941', name: '李仕炜', email: 'a@test.com', emailCode: '1', password: '123' })).status).toBe(400);

    __mock.setRoutes([{ match: /FROM dtest2\.class_students/, result: boom() }]);
    expect((await request(app).post('/api/auth/register')
      .send({ studentId: '2023307020941', name: '李仕炜', email: 'a@test.com', emailCode: '1', password: '123456' })).status).toBe(500);

    const code = codeStore.issue('reg-tx@test.com');
    __mock.setRoutes([
      { match: /FROM dtest2\.class_students/, result: [{ student_id: '2023307020941', name: '李仕炜', class_name: '23计算机科学与技术U9' }] },
      { match: /SELECT 1 FROM dtest2\.accounts/, result: boom() }
    ]);
    const r = await request(app).post('/api/auth/register')
      .send({ studentId: '2023307020941', name: '李仕炜', email: 'reg-tx@test.com', emailCode: code, password: '123456' });
    expect(r.status).toBe(500);
    expect(__mock.executed('ROLLBACK')).toBe(true);
  });

  test('找回密码：缺参 400；密码过短 400；验证码错误 400；查询抛错 500', async () => {
    expect((await request(app).post('/api/auth/reset-password')
      .send({ account: '', contact: 'a@test.com', verifyCode: '1', newPassword: '123456' })).status).toBe(400);
    expect((await request(app).post('/api/auth/reset-password')
      .send({ account: '2023307020941', contact: 'a@test.com', verifyCode: '1', newPassword: '123' })).status).toBe(400);

    __mock.setRoutes([
      { match: /SELECT account_id, role FROM dtest2\.accounts/, result: [{ account_id: '2023307020941', role: 'student' }] },
      { match: /SELECT email FROM dtest2\.student_profiles/, result: [{ email: 'reset@test.com' }] }
    ]);
    const rCode = await request(app).post('/api/auth/reset-password')
      .send({ account: '2023307020941', contact: 'reset@test.com', verifyCode: '000000', newPassword: '123456' });
    expect(rCode.status).toBe(400);

    __mock.setRoutes([{ match: /SELECT account_id, role FROM dtest2\.accounts/, result: boom() }]);
    expect((await request(app).post('/api/auth/reset-password')
      .send({ account: '2023307020941', contact: 'reset@test.com', verifyCode: '1', newPassword: '123456' })).status).toBe(500);
  });

  test('登录：底层查询抛错 → 500', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.accounts WHERE account_id/, result: boom() }]);
    expect((await request(app).post('/api/auth/login')
      .send({ account: 'x', password: 'y' })).status).toBe(500);
  });
});
