// 线上冒烟测试：对已部署后端跑端到端闭环验证（Node 18+，零依赖，用内置 fetch）。
// 用法：node scripts/smoke-live.js          （默认打线上 https://lsw666.dns.army/api）
//       BASE_URL=http://127.0.0.1:8090/api node scripts/smoke-live.js   （打本机）
// 特性：所有写操作自清理（选课必退课），不发真实邮件，不动管理端数据；
//       任一断言失败进程退出码非 0（可接 CI / 部署后验证）。
'use strict';

const BASE = process.env.BASE_URL || 'https://lsw666.dns.army/api';
const STUDENT = { account: process.env.SMOKE_STUDENT || '2023307020941', password: process.env.SMOKE_STUDENT_PWD || 'Elysia@2024' };
const ADMIN = { account: process.env.SMOKE_ADMIN || 'A20251001', password: process.env.SMOKE_ADMIN_PWD || 'Admin@2024' };

let passed = 0;
let failed = 0;
const failures = [];

function check(name, ok, detail) {
  if (ok) {
    passed += 1;
    console.log(`  ✓ ${name}`);
  } else {
    failed += 1;
    failures.push(`${name}${detail ? ' — ' + detail : ''}`);
    console.log(`  ✗ ${name}${detail ? ' — ' + detail : ''}`);
  }
}

async function call(method, path, token, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(BASE + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  let json = null;
  try {
    json = await res.json();
  } catch (e) { /* 非 JSON 响应 */ }
  return { status: res.status, body: json };
}

async function login(account, password) {
  const r = await call('POST', '/auth/login', null, { account, password });
  if (r.status !== 200 || !r.body || !r.body.data || !r.body.data.token) {
    throw new Error(`登录失败 ${account}（HTTP ${r.status}）`);
  }
  return r.body.data;
}

(async () => {
  console.log(`冒烟目标: ${BASE}\n`);

  // ---- 1. 健康检查 ----
  console.log('[1] 健康检查');
  const health = await call('GET', '/health', null);
  check('GET /health 200 且 db ok', health.status === 200 && health.body.data.db === 'ok');

  // ---- 2. 认证 ----
  console.log('[2] 认证与鉴权');
  const stu = await login(STUDENT.account, STUDENT.password);
  check('学生登录返回真实 profile', !!stu.profile && stu.profile.name.length > 0);
  const adm = await login(ADMIN.account, ADMIN.password);
  check('管理员登录返回权限矩阵', !!adm.profile && Array.isArray(adm.profile.permissions) && adm.profile.permissions.length > 0);
  const badLogin = await call('POST', '/auth/login', null, { account: STUDENT.account, password: 'wrong-password' });
  check('错误密码 → 401', badLogin.status === 401);
  const noToken = await call('GET', '/grades', null);
  check('无 token 访问业务端点 → 401', noToken.status === 401);
  const stuToAdmin = await call('GET', '/admin/students', stu.token);
  check('学生 token 访问管理端 → 403', stuToAdmin.status === 403);

  // ---- 3. 课程与年级定向 ----
  console.log('[3] 课程列表 / 年级定向 / 详情数据源');
  const open = await call('GET', '/courses?status=open', stu.token);
  check('学生 open 课程列表 ≥ 10 门', open.status === 200 && open.body.data.length >= 10, `实际 ${open.body && open.body.data ? open.body.data.length : '?'}`);
  const myGrade = `${STUDENT.account.slice(0, 4)}级`;
  const gradeOk = open.body.data.every((c) => !c.targetGrade || c.targetGrade === myGrade);
  check(`定向课程只含本人年级（${myGrade}）或全部年级`, gradeOk);
  const all = await call('GET', '/courses', stu.token);
  check('全量课程目录（详情数据源）≥ open 数', all.status === 200 && all.body.data.length >= open.body.data.length);
  check('目录字段含 targetGrade', all.body.data.every((c) => c.targetGrade !== undefined));

  // ---- 4. 选课轮次 ----
  console.log('[4] 选课轮次');
  const round = await call('GET', '/selection-rounds/active', stu.token);
  const roundOpen = round.status === 200 && !!round.body.data;
  check('查询当前轮次成功', round.status === 200);

  // ---- 5. 选课闭环（仅轮次开放时跑；写操作自清理）----
  console.log('[5] 选课多选闭环（自清理）');
  if (roundOpen) {
    const mineBefore = await call('GET', `/selections?studentId=${STUDENT.account}`, stu.token);
    const already = new Set((mineBefore.body.data || []).map((s) => s.courseId || s.id));
    // 挑两门不同时段、未选过的 open 课程
    const candidates = open.body.data.filter((c) => !already.has(c.id)).slice(0, 8);
    const pickTwo = [];
    for (const c of candidates) {
      if (pickTwo.length === 2) { break; }
      if (pickTwo.length === 0 || pickTwo[0].timeText !== c.timeText) {
        pickTwo.push(c);
      }
    }
    if (pickTwo.length === 2) {
      const tried = [];
      try {
        const s1 = await call('POST', '/selections', stu.token, { courseId: pickTwo[0].id });
        if (s1.status === 200) { tried.push(pickTwo[0].id); }
        check(`选第一门（${pickTwo[0].name}）→ 200`, s1.status === 200, s1.body && s1.body.error);
        const s2 = await call('POST', '/selections', stu.token, { courseId: pickTwo[1].id });
        if (s2.status === 200) { tried.push(pickTwo[1].id); }
        check(`再选第二门（${pickTwo[1].name}）→ 200（多选已放开）`, s2.status === 200, s2.body && s2.body.error);
        const dup = await call('POST', '/selections', stu.token, { courseId: pickTwo[0].id });
        check('重复选同一门 → 409', dup.status === 409);
        // 评教任务跟随当前课程：选课后列表应含新课
        const evalAfter = await call('GET', '/evaluations', stu.token);
        const evalIds = evalAfter.body.data.map((t) => t.courseCode);
        check('选课后评教任务即时跟随（含新选课程）', evalAfter.status === 200 && evalIds.indexOf(pickTwo[0].code) >= 0);
      } finally {
        for (const id of tried) {
          await call('DELETE', '/selections', stu.token, { courseId: id });
        }
      }
      const mineAfter = await call('GET', `/selections?studentId=${STUDENT.account}`, stu.token);
      check('退课清理完成（恢复原状）', (mineAfter.body.data || []).length === (mineBefore.body.data || []).length);
    } else {
      check('找到两门可选课程', false, '可选课程不足，跳过选课闭环');
    }
  } else {
    console.log('  - 轮次未开放，跳过选课写闭环（只读检查已覆盖）');
  }

  // ---- 6. 学生业务只读端点 ----
  console.log('[6] 学生业务端点');
  const reads = [
    ['/grades', '成绩'], ['/notices', '通知'], ['/leave', '请假'],
    ['/practice', '实践'], ['/schedule', '班级课表'], ['/evaluations', '评教'],
    ['/eval-period', '评教开关'], ['/calendar', '校历']
  ];
  for (const pair of reads) {
    const r = await call('GET', pair[0], stu.token);
    check(`GET ${pair[0]}（${pair[1]}）→ 200`, r.status === 200);
  }
  const evals = await call('GET', '/evaluations', stu.token);
  check('评教任务数 ≥ 班级课程数（8）', evals.body.data.length >= 8, `实际 ${evals.body.data.length}`);

  // ---- 7. 管理端只读端点 ----
  console.log('[7] 管理端端点');
  const adminReads = [
    ['/admin/dashboard', '仪表盘'], ['/admin/students', '学生'], ['/admin/grades', '成绩任务'],
    ['/admin/approvals', '审批'], ['/admin/selection/stats', '选课统计'],
    ['/admin/courses', '课程目录'], ['/admin/verification-codes', '验证码监控'],
    ['/admin/roles', '角色权限'], ['/admin/audit-logs', '审计日志']
  ];
  for (const pair of adminReads) {
    const r = await call('GET', pair[0], adm.token);
    check(`GET ${pair[0]}（${pair[1]}）→ 200`, r.status === 200);
  }
  const codes = await call('GET', '/admin/verification-codes', adm.token);
  check('验证码监控不泄露验证码明文', codes.body.data.every((c) => c.code === undefined));
  const adminCourses = await call('GET', '/admin/courses', adm.token);
  check('管理端课程目录含 targetGrade 字段', adminCourses.body.data.every((c) => c.targetGrade !== undefined));

  // ---- 汇总 ----
  console.log(`\n结果：${passed} 通过 / ${failed} 失败（共 ${passed + failed} 项）`);
  if (failed > 0) {
    console.log('失败项：');
    for (const f of failures) {
      console.log(`  - ${f}`);
    }
    process.exit(1);
  }
  console.log('全部通过 ✓');
  process.exit(0);
})().catch((e) => {
  console.error(`\n冒烟中断：${e.message}`);
  process.exit(1);
});
