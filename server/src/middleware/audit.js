// 审计落库中间件：自动记录全部 /api 写操作（非 GET）+ 登录/注册等认证事件。
// 响应结束（finish）后异步写 dtest2.audit_logs，失败只记服务端日志，绝不阻断业务请求。
// 不记录请求体中的敏感字段（密码 / 验证码一律不落库），detail_json 仅存方法/路径/状态码。
const crypto = require('crypto');
const { pool } = require('../db');

// 路由 → 可读操作名映射（按序匹配 `${METHOD} ${path}`；未命中走兜底「METHOD path」）
const RULES = [
  { re: /^POST \/api\/auth\/login$/, label: '登录', type: 'login', target: '认证' },
  { re: /^POST \/api\/auth\/register$/, label: '注册账号', type: 'auth', target: '认证' },
  { re: /^POST \/api\/auth\/reset-password$/, label: '找回密码', type: 'auth', target: '认证' },
  { re: /^POST \/api\/auth\/email-code$/, label: '请求邮箱验证码', type: 'auth', target: '认证' },
  { re: /^POST \/api\/auth\/verify-email-code$/, label: '校验邮箱验证码', type: 'auth', target: '认证' },
  { re: /^POST \/api\/selections$/, label: '选课', type: 'selection', target: 'body.courseId' },
  { re: /^DELETE \/api\/selections$/, label: '退课', type: 'selection', target: 'body.courseId' },
  { re: /^PUT \/api\/profile$/, label: '修改个人资料', type: 'profile', target: '个人资料' },
  { re: /^POST \/api\/leave$/, label: '提交请假申请', type: 'leave', target: '请假' },
  { re: /^POST \/api\/feedback$/, label: '提交意见反馈', type: 'feedback', target: '反馈' },
  { re: /^POST \/api\/evaluations\/([^/]+)\/submit$/, label: '提交评教', type: 'evaluation', target: '$1' },
  { re: /^POST \/api\/practice\/([^/]+)\/signup$/, label: '实践报名', type: 'practice', target: '$1' },
  { re: /^DELETE \/api\/practice\/([^/]+)\/signup$/, label: '取消实践报名', type: 'practice', target: '$1' },
  { re: /^POST \/api\/notices\/([^/]+)\/read$/, label: '标记通知已读', type: 'notice', target: '$1' },
  { re: /^POST \/api\/admin\/grades\/([^/]+)\/input$/, label: '录入成绩', type: 'grades', target: '$1' },
  { re: /^POST \/api\/admin\/grades\/([^/]+)\/scores$/, label: '按学生打分', type: 'grades', target: '$1' },
  { re: /^POST \/api\/admin\/grades\/([^/]+)\/approve$/, label: '成绩审核通过（发布）', type: 'grades', target: '$1' },
  { re: /^POST \/api\/admin\/grades\/([^/]+)\/reject$/, label: '成绩驳回', type: 'grades', target: '$1' },
  { re: /^POST \/api\/admin\/approvals\/([^/]+)\/approve$/, label: '审批通过', type: 'approval', target: '$1' },
  { re: /^POST \/api\/admin\/approvals\/([^/]+)\/reject$/, label: '审批驳回', type: 'approval', target: '$1' },
  { re: /^PATCH \/api\/admin\/feedback\/([^/]+)$/, label: '处理意见反馈', type: 'feedback', target: '$1' },
  { re: /^POST \/api\/admin\/notices$/, label: '发布通知', type: 'notice', target: '通知中心' },
  { re: /^POST \/api\/admin\/courses$/, label: '新增课程', type: 'course', target: '课程目录' },
  { re: /^PUT \/api\/admin\/courses\/([^/]+)$/, label: '编辑课程', type: 'course', target: '$1' },
  { re: /^DELETE \/api\/admin\/courses\/([^/]+)$/, label: '删除课程', type: 'course', target: '$1' },
  { re: /^PUT \/api\/admin\/selection\/rounds\/([^/]+)\/status$/, label: '变更选课轮次状态', type: 'selection-admin', target: '$1' },
  { re: /^PUT \/api\/admin\/selection\/rounds\/([^/]+)\/time$/, label: '修改选课轮次时间', type: 'selection-admin', target: '$1' },
  { re: /^PUT \/api\/admin\/eval-period$/, label: '切换评教开关', type: 'eval-admin', target: '评教期' },
  { re: /^POST \/api\/admin\/eval\/templates$/, label: '新建评教模板', type: 'eval-admin', target: '评教模板' },
  { re: /^PUT \/api\/admin\/eval\/templates\/([^/]+)$/, label: '编辑评教模板', type: 'eval-admin', target: '$1' },
  { re: /^DELETE \/api\/admin\/eval\/templates\/([^/]+)$/, label: '删除评教模板', type: 'eval-admin', target: '$1' },
  { re: /^POST \/api\/admin\/calendar$/, label: '新增校历事件', type: 'system', target: '教学日历' },
  { re: /^DELETE \/api\/admin\/calendar\/([^/]+)$/, label: '删除校历事件', type: 'system', target: '$1' },
  { re: /^POST \/api\/admin\/db\/tables\/([^/]+)\/rows$/, label: '数据库插入行', type: 'db', target: '$1' },
  { re: /^PUT \/api\/admin\/db\/tables\/([^/]+)\/rows$/, label: '数据库修改行', type: 'db', target: '$1' },
  { re: /^DELETE \/api\/admin\/db\/tables\/([^/]+)\/rows$/, label: '数据库删除行', type: 'db', target: '$1' }
];

function resolveRule(method, path) {
  const key = `${method} ${path}`;
  for (const rule of RULES) {
    const m = rule.re.exec(key);
    if (m) {
      return { label: rule.label, type: rule.type, target: rule.target, match: m };
    }
  }
  return null;
}

// 操作人：已登录取 JWT；认证类公开端点从请求体取账号/学号（永不读取密码字段）
function resolveOperator(req) {
  if (req.auth && req.auth.sub) {
    return String(req.auth.sub);
  }
  const b = req.body || {};
  if (typeof b.account === 'string' && b.account.trim()) {
    return b.account.trim();
  }
  if (typeof b.studentId === 'string' && b.studentId.trim()) {
    return b.studentId.trim();
  }
  if (typeof b.email === 'string' && b.email.trim()) {
    // 邮箱做脱敏后入库（验证码请求阶段尚无账号）
    const email = b.email.trim();
    const at = email.indexOf('@');
    return at > 1 ? `${email.slice(0, 2)}***${email.slice(at)}` : '***';
  }
  return '';
}

async function writeAudit(entry) {
  // 操作人姓名按账号反查（管理员 → 学生资料 → 班级名册），查不到留空
  let name = '';
  if (entry.operatorId && entry.operatorId.indexOf('*') < 0) {
    try {
      const r = await pool.query(
        `SELECT COALESCE(
           (SELECT name FROM dtest2.admin_profiles WHERE admin_id=$1),
           (SELECT name FROM dtest2.student_profiles WHERE student_id=$1),
           (SELECT name FROM dtest2.class_students WHERE student_id=$1),
           '') AS name`,
        [entry.operatorId]
      );
      name = (r.rows[0] && r.rows[0].name) || '';
    } catch (e) { /* 姓名解析失败不阻断审计写入 */ }
  }
  const logId = `log-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  await pool.query(
    `INSERT INTO dtest2.audit_logs
       (log_id, operator_id, operator_name, action, action_type, target, result, ip, detail_json)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb)`,
    [logId, entry.operatorId, name, entry.action, entry.actionType, entry.target,
      entry.result, entry.ip, JSON.stringify(entry.detail)]
  );
}

// Express 中间件：挂在路由之前；finish 时机 req.auth 已由各路由的鉴权中间件填充
function auditTrail() {
  return (req, res, next) => {
    res.on('finish', () => {
      try {
        if (req.method === 'GET' || req.path.indexOf('/api/') !== 0) {
          return;
        }
        if (req.path === '/api/health') {
          return;
        }
        const rule = resolveRule(req.method, req.path);
        let target = rule ? rule.target : req.path;
        if (rule && rule.target === 'body.courseId') {
          target = String((req.body && req.body.courseId) || '') || '选课';
        } else if (rule && rule.target.indexOf('$') === 0) {
          target = rule.match[Number(rule.target.slice(1))] || '';
        }
        const entry = {
          operatorId: resolveOperator(req),
          action: rule ? rule.label : `${req.method} ${req.path}`,
          actionType: rule ? rule.type : 'other',
          target,
          result: res.statusCode < 400 ? 'success' : 'failed',
          ip: req.ip || '',
          detail: { method: req.method, path: req.path, status: res.statusCode }
        };
        writeAudit(entry).catch((e) => {
          console.error('[dtest2-api] 审计日志写入失败:', e.message);
        });
      } catch (e) {
        console.error('[dtest2-api] 审计日志组装失败:', e.message);
      }
    });
    next();
  };
}

module.exports = { auditTrail };
