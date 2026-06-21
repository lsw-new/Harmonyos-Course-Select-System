// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { ok } = require('./envelope');
// 仅保留 /health 与底部 re-export 所需；各域路由各自 require 自己的依赖。
const { parseCourseWeeks, coursesConflict } = require('./mappers');
const { globalLimiter } = require('./middleware/rateLimit');
const { serverError } = require('./middleware/errorHandler');

const app = express();

// HTTPS：仅信任本地回环反代（nginx）转发的 X-Forwarded-For，使限流/req.ip 取到真实客户端 IP；
// 外部直连 :8090 的对端非回环，不会被信任，无法伪造 IP 绕过限流。
app.set('trust proxy', 'loopback');

// 安全响应头（security-reviewer M6）：手写中间件，零新增依赖。
// 防 MIME 嗅探 / 点击劫持 / Referer 泄露；HTTPS 由 nginx 终止，HSTS 仅在 https 时附加。
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  if (req.secure || req.headers['x-forwarded-proto'] === 'https') {
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  // 含敏感数据的 API 响应不缓存（静态 /admin 资源不受影响，已在前面单独挂载）
  if (req.path.indexOf('/api/') === 0) {
    res.setHeader('Cache-Control', 'no-store');
  }
  next();
});

// P2-01：CORS 收紧。原生 App 不受浏览器 CORS 约束；默认关闭跨域，
// 仅当 .env 配置 CORS_ORIGINS（逗号分隔）时放行可信域名。
const CORS_ORIGINS = (process.env.CORS_ORIGINS || '')
  .split(',').map((s) => s.trim()).filter((s) => s.length > 0);
app.use(cors({ origin: CORS_ORIGINS.length > 0 ? CORS_ORIGINS : false, credentials: true }));

// 后端管理控制台（纯静态单页，数据全部经 /api 管理端点，JWT + 细粒度权限由后端校验）
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));

app.use(globalLimiter);
// 300kb：兼容压缩后 base64 头像（默认 100kb 不够）
app.use(express.json({ limit: '300kb' }));
// 审计落库：自动记录全部 /api 写操作 + 认证事件（响应结束后异步写，不阻断业务）
app.use(require('./middleware/audit').auditTrail());

// ---- 健康检查（/api/health 供公网经 nginx /api 反代访问；裸 /health 供本机直连）----
app.get(['/health', '/api/health'], async (req, res) => {
  try {
    const r = await pool.query('SELECT now() AS now');
    res.json(ok({ db: 'ok', now: r.rows[0].now }));
  } catch (e) {
    serverError(res, '数据库连接失败', e);
  }
});

// ---- 认证域（登录 / 邮箱验证码 / 注册 / 找回密码）已抽到 ./routes/auth.routes ----
app.use(require('./routes/auth.routes'));

// ---- 选课域（课程列表 / 选课轮次 / 我的已选 / 选课 / 退课）已抽到 ./routes/selection.routes ----
app.use(require('./routes/selection.routes'));

// ---- 个人资料域（学生更新本人头像/联系方式）----
app.use(require('./routes/profile.routes'));

// ---- 成绩域（当前学生已发布成绩）已抽到 ./routes/grades.routes ----
app.use(require('./routes/grades.routes'));

// ---- 班级课表域（按学生所在班级返回本班课表，含课程-教师绑定）----
app.use(require('./routes/schedule.routes'));

// ---- 通知域（列表 / 详情 / 标记已读）已抽到 ./routes/notices.routes ----
app.use(require('./routes/notices.routes'));

// ---- 消息中心域（个人消息流 / 标记已读 / 未读数，已读状态服务端落库跨设备同步）----
app.use(require('./routes/messages.routes'));

// ---- 请假域（我的请假 / 提交请假含 approval 闭环）已抽到 ./routes/leave.routes ----
app.use(require('./routes/leave.routes'));

// ---- 反馈域（我的反馈 / 提交反馈）已抽到 ./routes/feedback.routes ----
app.use(require('./routes/feedback.routes'));

// ---- 评教域（评教任务 / 评教提交）已抽到 ./routes/evaluations.routes ----
app.use(require('./routes/evaluations.routes'));

// ---- 实践域（列表 / 详情 / 报名含行锁 / 取消报名）已抽到 ./routes/practice.routes ----
app.use(require('./routes/practice.routes'));

// ---- 成绩申诉域（学生提交 / 管理端受理驳回）----
app.use(require('./routes/grade-appeals.routes'));

// ---- 考试安排域（学生按班级/已选查考试 / 管理端 CRUD）----
app.use(require('./routes/exams.routes'));

// ================= 管理端域（需 role=admin + 细粒度权限）=================
// 学生管理 / 成绩审核录入 / 审批 / 通知发布 / 角色权限 / 操作日志 / 评教模板
// 全部端点已抽到 ./routes/admin.routes（permissionRequired 细粒度鉴权）
app.use(require('./routes/admin.routes'));

// ---- 管理端统计域（仪表盘 / 选课统计 / 评教统计，实时聚合）----
app.use(require('./routes/admin-stats.routes'));

// ---- 管理端课程管理域（课程目录 CRUD，与选课中心同源）----
app.use(require('./routes/admin-courses.routes'));

// ---- 管理端报表导出域（成绩/选课/评教统计 Excel 下载，复用统计聚合 SQL）----
app.use(require('./routes/admin-reports.routes'));

// ---- 对象存储域（上传/下载图片等二进制对象，roadmap #9）----
app.use(require('./routes/uploads.routes'));

// ---- 推送通知域（设备 token 注册/注销，roadmap #8）----
app.use(require('./routes/push.routes'));

// ---- 数据库管理域（Web 控制台表级 CRUD，仅 system.config 权限）----
app.use(require('./routes/db.routes'));

const PORT = parseInt(process.env.PORT || '8090', 10);
// 仅当作为主模块（node src/index.js / pm2）运行时才监听端口；
// 被测试 require 时不监听，便于 supertest 直接挂载 app。
if (require.main === module) {
  app.listen(PORT, () => console.log(`[dtest2-api] listening on :${PORT}`));
}

// 推送出站箱 sweeper（roadmap #8）：每 30 秒轮询 pushed_at IS NULL 消息，尝试推送后标记。
// 双重保护：
//   1. NODE_ENV !== 'test'：jest 运行时绝不启动，避免 open handle 导致进程挂起。
//   2. t.unref()：sweeper timer 不阻止进程正常退出（pm2 graceful stop 可用）。
if (process.env.NODE_ENV !== 'test') {
  const { sweepAndPush } = require('./push');
  const t = setInterval(() => { sweepAndPush(pool).catch(() => {}); }, 30000);
  t.unref();
}

// 导出供测试：app 用于 supertest，纯函数用于规则单测。
module.exports = app;
module.exports.parseCourseWeeks = parseCourseWeeks;
module.exports.coursesConflict = coursesConflict;
