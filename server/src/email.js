// 邮件发送（QQ SMTP via nodemailer）。SMTP 凭据从环境变量读取，绝不硬编码。
const nodemailer = require('nodemailer');

let cachedTransporter = null;

// 惰性创建 transporter；缺少凭据时抛错，由调用方转成业务失败返回。
function getTransporter() {
  if (cachedTransporter) {
    return cachedTransporter;
  }
  const host = process.env.SMTP_HOST || 'smtp.qq.com';
  const port = parseInt(process.env.SMTP_PORT || '465', 10);
  const secure = (process.env.SMTP_SECURE || 'true') === 'true';
  const user = process.env.SMTP_SENDER_EMAIL;
  const pass = process.env.SMTP_SENDER_PASSWORD;
  if (!user || !pass) {
    throw new Error('SMTP 未配置：缺少 SMTP_SENDER_EMAIL / SMTP_SENDER_PASSWORD');
  }
  cachedTransporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass }
  });
  return cachedTransporter;
}

function buildHtml(appName, code) {
  return `
  <div style="max-width:480px;margin:0 auto;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#2b2b2b;">
    <div style="padding:24px 0;text-align:center;">
      <div style="font-size:18px;font-weight:600;color:#d6336c;">${appName}</div>
    </div>
    <div style="background:#fff5f8;border:1px solid #ffd6e4;border-radius:16px;padding:28px 24px;">
      <p style="margin:0 0 14px;font-size:14px;">您正在进行邮箱验证，验证码为：</p>
      <div style="font-size:34px;font-weight:700;letter-spacing:8px;color:#d6336c;text-align:center;margin:18px 0;">${code}</div>
      <p style="margin:14px 0 0;font-size:12px;color:#8a8a8a;">验证码 5 分钟内有效，请勿向他人泄露。如非本人操作，请忽略本邮件。</p>
    </div>
    <div style="padding:18px 0;text-align:center;font-size:11px;color:#b0b0b0;">本邮件由系统自动发送，请勿直接回复。</div>
  </div>`;
}

// 发送验证码邮件；SMTP 握手/鉴权失败会 throw，由路由层捕获。
async function sendVerificationCode(toEmail, code) {
  const user = process.env.SMTP_SENDER_EMAIL;
  const appName = process.env.APP_NAME || '景德镇艺术职业大学教学管理系统';
  const transporter = getTransporter();
  await transporter.sendMail({
    from: `"${appName}" <${user}>`,
    to: toEmail,
    subject: `【${appName}】邮箱验证码`,
    text: `您的验证码是 ${code}，5 分钟内有效，请勿向他人泄露。如非本人操作请忽略本邮件。`,
    html: buildHtml(appName, code)
  });
}

module.exports = { sendVerificationCode, getTransporter };
