// 在任何被测模块加载前注入测试环境变量。
// auth.js 在 require 时即对 JWT_SECRET 做 fail-fast 校验，故必须在此先设好。
// dotenv 不覆盖已存在的 process.env，故这些值在测试中生效（本地无 .env 时尤其如此）。
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-key-0123456789abcdef';
process.env.NODE_ENV = 'test';
// 常规用例把限流阈值调到极高避免误触发；限流专项用例会在其文件顶部 require 之前自行下调。
process.env.RATE_LIMIT_WINDOW_MS = process.env.RATE_LIMIT_WINDOW_MS || '60000';
process.env.RATE_LIMIT_MAX = process.env.RATE_LIMIT_MAX || '1000000';
process.env.AUTH_RATE_LIMIT_MAX = process.env.AUTH_RATE_LIMIT_MAX || '1000000';
