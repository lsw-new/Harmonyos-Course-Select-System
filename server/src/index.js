// 景德镇艺术职业大学教务 App 后端 API · Track B 垂直切片（认证 / 课程 / 选课）
// 返回 App 端 ApiResponse 信封 { success, data, error }；连本地 Postgres(dtest2 schema)。
require('dotenv').config();
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

// P2-01：CORS 收紧。原生 App 不受浏览器 CORS 约束；默认关闭跨域，
// 仅当 .env 配置 CORS_ORIGINS（逗号分隔）时放行可信域名。
const CORS_ORIGINS = (process.env.CORS_ORIGINS || '')
  .split(',').map((s) => s.trim()).filter((s) => s.length > 0);
app.use(cors({ origin: CORS_ORIGINS.length > 0 ? CORS_ORIGINS : false, credentials: true }));

app.use(globalLimiter);
app.use(express.json());

// ---- 健康检查 ----
app.get('/health', async (req, res) => {
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

// ---- 成绩域（当前学生已发布成绩）已抽到 ./routes/grades.routes ----
app.use(require('./routes/grades.routes'));

// ---- 班级课表域（按学生所在班级返回本班课表，含课程-教师绑定）----
app.use(require('./routes/schedule.routes'));

// ---- 通知域（列表 / 详情 / 标记已读）已抽到 ./routes/notices.routes ----
app.use(require('./routes/notices.routes'));

// ---- 请假域（我的请假 / 提交请假含 approval 闭环）已抽到 ./routes/leave.routes ----
app.use(require('./routes/leave.routes'));

// ---- 反馈域（我的反馈 / 提交反馈）已抽到 ./routes/feedback.routes ----
app.use(require('./routes/feedback.routes'));

// ---- 评教域（评教任务 / 评教提交）已抽到 ./routes/evaluations.routes ----
app.use(require('./routes/evaluations.routes'));

// ---- 实践域（列表 / 详情 / 报名含行锁 / 取消报名）已抽到 ./routes/practice.routes ----
app.use(require('./routes/practice.routes'));

// ================= 管理端域（需 role=admin + 细粒度权限）=================
// 学生管理 / 成绩审核录入 / 审批 / 通知发布 / 角色权限 / 操作日志 / 评教模板
// 全部端点已抽到 ./routes/admin.routes（permissionRequired 细粒度鉴权）
app.use(require('./routes/admin.routes'));

const PORT = parseInt(process.env.PORT || '8090', 10);
// 仅当作为主模块（node src/index.js / pm2）运行时才监听端口；
// 被测试 require 时不监听，便于 supertest 直接挂载 app。
if (require.main === module) {
  app.listen(PORT, () => console.log(`[dtest2-api] listening on :${PORT}`));
}

// 导出供测试：app 用于 supertest，纯函数用于规则单测。
module.exports = app;
module.exports.parseCourseWeeks = parseCourseWeeks;
module.exports.coursesConflict = coursesConflict;
