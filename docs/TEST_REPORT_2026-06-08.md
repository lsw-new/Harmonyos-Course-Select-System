# D:\test2 全方位测试报告

- **测试日期**：2026-06-08
- **项目**：景德镇艺术职业大学教务 App（HarmonyOS ArkTS 客户端 + Node/Express/PostgreSQL 后端）
- **测试方式**：最大并发多代理测试 + 主会话补充验证
- **测试结论**：**NEEDS WORK（主体可运行，但存在发布/线上健康检查/依赖安全/客户端覆盖率风险）**

> **历史报告说明（2026-06-09 更新）**：本报告记录的是 2026-06-08 对旧公网域名 `lsw666.duckdns.org` 的测试证据。当前后端公网 API 契约已迁移为 `https://lsw666.dns.army/api`，新域名复测结果见 `docs/TEST_REPORT_2026-06-09.md`。为保持审计可追溯性，下文旧域名命令和输出不批量改写。

## 1. 执行摘要

本轮对 `D:\test2` 执行了全方位测试，覆盖：

1. 后端语法检查、Jest 全量测试与覆盖率门禁。
2. 后端高风险业务规则：选课并发、容量、时间冲突、实践报名、管理端/学生端写操作。
3. 后端 API 路由契约与测试映射。
4. 线上 API HTTPS/TLS 冒烟、认证拒绝、CORS 基础检查。
5. HarmonyOS/ArkTS 客户端构建、HAP/APP 产物、本地 Hypium 单测、设备测试可用性。
6. 客户端测试覆盖率与 OHOS instrument 测试缺口。
7. 静态安全：密钥、JWT、CORS、限流、SQL 参数化、日志与错误处理。
8. 依赖供应链：`npm audit`、lockfile、签名验证。
9. 质量门禁：源码大文件、console 使用、文档/CI一致性。

### 总体结果

| 维度 | 状态 | 摘要 |
|---|---:|---|
| 后端语法检查 | PASS | 39 个 JS 文件语法检查通过。 |
| 后端 Jest 全量测试 | PASS | 11/11 suites、108/108 tests 通过。 |
| 后端覆盖率门禁 | PASS/WARN | 达到项目配置阈值；全局分支覆盖率 63.63%，低于通用 80% 目标。 |
| 高风险业务规则 | PASS | 5 个定向套件、51/51 tests 通过。 |
| 依赖安全 | FAIL | `nodemailer@6.10.1` 存在 1 个生产高危漏洞，修复需大版本升级。 |
| 线上 API 冒烟 | FAIL | `https://lsw666.duckdns.org/api/health` 返回 404 HTML；受保护接口 401 正常。 |
| TLS/HTTPS | PASS | TLSv1.3、Let's Encrypt 证书校验 OK；HTTP 跳 HTTPS 正常。 |
| HarmonyOS 构建 | WARN | `assembleHap`、`assembleApp` 均成功，但产物未签名，release 混淆未启用。 |
| ArkTS 本地测试 | PASS/WARN | 16/16 本地单测通过，但客户端覆盖率极低。 |
| OHOS 设备测试 | BLOCKED | `hdc list targets` 返回 `[Empty]`，无模拟器/真机目标。 |
| 静态安全 | WARN | 无明显硬编码生产密钥；有依赖高危、健康端点不一致、启动日志 `console.log`。 |
| 文档/CI一致性 | WARN | README 中后端测试数与覆盖率基本一致；线上 `/api/health` 与文档/部署契约不一致。 |

## 2. 测试环境与约束

### 2.1 本地环境

- 工作目录：`D:\test2`
- 分支：`master`
- 当前工作树额外未跟踪历史文件：
  - `findings.md`
  - `progress.md`
  - `task_plan.md`
- Node/npm：后端依赖审计代理检测到 `Node.js v24.15.0`、`npm 11.12.1`。
- 后端脚本：`server/package.json`
  - `npm run check:syntax`
  - `npm test`
  - `npm run test:coverage`
- HarmonyOS/DevEco：检测到
  - SDK：`D:/DevEco Studio/sdk`
  - Node：`D:/DevEco Studio/tools/node/node.exe`
  - Hvigor：`D:/DevEco Studio/tools/hvigor/bin/hvigorw.js`
  - Hvigor 版本：`5.19.7`

### 2.2 已知限制

- 本轮未修改业务源码，也未提交 git。
- 构建/测试会生成正常产物：`server/coverage/`、`entry/build/`、`entry/.test/`、`build/outputs/` 等。
- 未执行会写入线上数据的操作：未注册、未发送验证码、未创建选课/请假/反馈等生产数据。
- 未使用真实账号登录线上 API，因此线上已授权业务流未做完整 E2E。
- 无 HarmonyOS 模拟器/真机在线，OHOS instrument 测试未执行。
- 最大并发 workflow 中部分静态代理长时间未返回，已停止该 workflow，并使用主会话补充复核缺口。

## 3. 后端自动化测试

### 3.1 语法检查

命令：

```bash
cd /d/test2/server && npm run check:syntax
```

结果：**PASS**

证据：

```text
✓ 语法检查通过：39 个 JS 文件无语法错误。
```

### 3.2 Jest 全量测试

命令：

```bash
npm --prefix /d/test2/server test -- --runInBand
```

结果：**PASS**

证据：

```text
Test Suites: 11 passed, 11 total
Tests:       108 passed, 108 total
Snapshots:   0 total
Time:        3.459 s
```

### 3.3 Jest 覆盖率

命令：

```bash
npm --prefix /d/test2/server run test:coverage -- --runInBand
```

结果：**PASS（项目阈值通过） / WARN（分支覆盖率不足 80%）**

证据：

| 指标 | 当前值 | 已覆盖/总量 | 项目阈值 | 结论 |
|---|---:|---:|---:|---|
| Statements | 82.29% | 730/887 | 79% | PASS |
| Branches | 63.63% | 364/572 | 62% | PASS，但低于通用 80% 目标 |
| Functions | 80.41% | 78/97 | 80% | PASS |
| Lines | 83.19% | 723/869 | 80% | PASS |

覆盖率产物：

- `D:/test2/server/coverage/lcov.info`
- `D:/test2/server/coverage/lcov-report/index.html`

### 3.4 后端覆盖率缺口

从 LCOV 解析出的最低覆盖文件：

| 文件 | 行覆盖 | 函数覆盖 | 分支覆盖 | 风险 |
|---|---:|---:|---:|---|
| `src/codeStore.js` | 21.62% | 0.00% | 5.56% | 邮箱验证码/一次性码逻辑缺测试。 |
| `src/mappers.js` | 78.79% | 60.00% | 53.47% | 数据映射、空值/枚举/边界分支不足。 |
| `src/routes/admin.routes.js` | 79.26% | 94.44% | 63.97% | 管理端错误分支/权限分支仍有缺口。 |
| `src/routes/evaluations.routes.js` | 82.22% | 66.67% | 62.50% | 评教提交/异常分支不足。 |
| `src/repositories/profile.repo.js` | 84.62% | 100.00% | 30.77% | profile 可选字段/空权限/异常分支不足。 |
| `src/middleware/rateLimit.js` | 88.00% | 66.67% | 55.00% | 限流边界、窗口重置、IP 分支不足。 |

统计：

```text
LCOV_BELOW_80_LINES:    3 files
LCOV_BELOW_80_BRANCHES: 18 files
LCOV_TOTAL_FILES:       20 files
```

建议优先新增测试：

1. `codeStore.js`：生成、读取、消费、过期、清理、空 code、重复消费。
2. `mappers.js`：null/undefined、缺字段、枚举状态、空数组、所有导出 mapper。
3. `admin.routes.js`：缺权限、参数校验失败、repository error、空结果集、非 happy path。
4. `rateLimit.js`：超过阈值、窗口重置、不同 IP、auth/global 不同阈值。

## 4. 高风险业务规则测试

### 4.1 定向命令

```bash
node /d/test2/server/node_modules/jest/bin/jest.js \
  --config /d/test2/server/package.json \
  /d/test2/server/test/concurrency.test.js \
  /d/test2/server/test/rules.test.js \
  /d/test2/server/test/selections.test.js \
  /d/test2/server/test/practice.test.js \
  /d/test2/server/test/mutations.test.js \
  --runInBand
```

结果：**PASS**

证据：

```text
Test Suites: 5 passed, 5 total
Tests:       51 passed, 51 total
Time:        1.313 s
```

### 4.2 已验证风险

| 风险 | 覆盖情况 |
|---|---|
| 选课容量超卖 | `concurrency.test.js` 用 `Promise.all` 模拟 20 人抢 1/5 个名额，成功数精确等于容量。 |
| 行锁意图 | `selections.test.js` 验证课程行 `FOR UPDATE`。 |
| 无锁对照 | 并发 mock 关闭序列化时出现超卖，证明断言非恒真。 |
| 选课轮次 | 无 active round 返回 409 并回滚。 |
| 课程不存在/关闭 | 返回 404/409 并回滚。 |
| 重复选课 | 返回 409。 |
| 学分上限 | 超限返回 409 并回滚。 |
| 时间冲突 | 返回 409，并包含冲突课程名。 |
| 实践报名容量/重复 | `practice.test.js` + 并发测试覆盖。 |
| 学生/管理端写操作 | `mutations.test.js` 覆盖退课、通知已读、请假、反馈、评教提交、实践取消、成绩录入/审批/驳回、公告、评教模板 CRUD。 |

### 4.3 注意事项

这些测试大量使用 Jest mock / stateful mock，能验证路由逻辑、SQL 片段、事务 commit/rollback 与并发意图；但还不是真实 PostgreSQL 隔离级别测试。建议未来补充 disposable PostgreSQL 集成测试，验证实际行锁与事务隔离行为。

## 5. 后端 API 契约与测试映射

### 5.1 当前路由清单

| 路由文件 | 端点 |
|---|---|
| `admin.routes.js` | `GET /api/admin/students`、`GET /api/admin/grades`、`POST /api/admin/grades/:id/input`、`POST /api/admin/grades/:id/approve`、`POST /api/admin/grades/:id/reject`、`GET /api/admin/approvals`、`POST /api/admin/approvals/:id/approve`、`POST /api/admin/approvals/:id/reject`、`POST /api/admin/notices`、`GET /api/admin/roles`、`GET /api/admin/audit-logs`、`GET /api/admin/eval/templates`、`POST /api/admin/eval/templates`、`PUT /api/admin/eval/templates/:id`、`DELETE /api/admin/eval/templates/:id` |
| `auth.routes.js` | `POST /api/auth/login`、`POST /api/auth/email-code`、`POST /api/auth/verify-email-code`、`POST /api/auth/register`、`POST /api/auth/reset-password` |
| `evaluations.routes.js` | `GET /api/evaluations`、`POST /api/evaluations/:taskId/submit` |
| `feedback.routes.js` | `GET /api/feedback`、`POST /api/feedback` |
| `grades.routes.js` | `GET /api/grades` |
| `leave.routes.js` | `GET /api/leave`、`POST /api/leave` |
| `notices.routes.js` | `GET /api/notices`、`GET /api/notices/:id`、`POST /api/notices/:id/read` |
| `practice.routes.js` | `GET /api/practice`、`GET /api/practice/:id`、`POST /api/practice/:id/signup`、`DELETE /api/practice/:id/signup` |
| `selection.routes.js` | `GET /api/courses`、`GET /api/selection-rounds/active`、`GET /api/selections`、`POST /api/selections`、`DELETE /api/selections` |

### 5.2 测试文件映射

| 测试文件 | 覆盖重点 |
|---|---|
| `auth.test.js` | 登录、`authRequired`、无 token/错 token。 |
| `auth-flows.test.js` | 注册、找回密码、邮箱验证码发送/验证。 |
| `security.test.js` | P0-01 IDOR、P0-02 管理端细粒度权限。 |
| `ratelimit.test.js` | 登录限流。 |
| `endpoints-read.test.js` | `/health`、学生/管理员只读端点。 |
| `coverage-extra.test.js` | 更多只读端点、异常 catch 分支。 |
| `selections.test.js` | 选课写入规则、事务、容量、冲突。 |
| `concurrency.test.js` | 选课/实践并发防超卖。 |
| `practice.test.js` | 实践报名写入规则。 |
| `mutations.test.js` | 学生和管理端关键 mutation。 |
| `rules.test.js` | 课程周次解析、时间冲突纯函数。 |

总体判断：后端 API 契约测试覆盖面较广，核心认证/授权/业务规则均有回归保护；主要缺口在分支覆盖率、真实数据库集成、线上 `/api/health` 部署契约。

## 6. 线上 API / HTTPS 冒烟

目标：`https://lsw666.duckdns.org/api`

### 6.1 健康检查

命令：

```bash
curl -sS -i --max-time 15 https://lsw666.duckdns.org/api/health
```

结果：**FAIL**

证据：

```text
HTTP/1.1 404 Not Found
Content-Type: text/html; charset=utf-8

Cannot GET /api/health
```

影响：

- 文档/记忆中的线上后端基路径是 `https://lsw666.duckdns.org/api`。
- 如果健康检查按基路径拼接为 `/api/health`，当前线上不可用。
- 返回 HTML，不是后端统一 `{ success, data, error }` 信封。

对照：代理发现 `https://lsw666.duckdns.org/health` 返回 200，但响应为：

```json
{"database":"healthy","status":"healthy"}
```

这与仓库当前 `server/src/index.js` 的 `ok({ db: 'ok', now })` 信封也不一致，提示线上根路径 `/health` 可能来自不同版本/不同代理路径。

### 6.2 受保护接口未认证拒绝

命令：

```bash
curl -sS -i --max-time 15 https://lsw666.duckdns.org/api/courses
```

结果：**PASS**

证据：

```text
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{"success":false,"data":null,"error":"未授权","code":"unauthorized"}
```

### 6.3 无效 token 拒绝

结果：**PASS**

证据：

```json
{"success":false,"data":null,"error":"登录态已失效，请重新登录","code":"unauthorized"}
```

### 6.4 TLS / HTTPS

结果：**PASS**

证据摘要：

- TLS 协议：`TLSv1.3`
- Cipher：`TLS_AES_256_GCM_SHA384`
- 证书 CN/SAN：`lsw666.duckdns.org`
- 颁发者：Let's Encrypt `E7`
- 验证：`Verification: OK`
- 有效期：2026-05-23 至 2026-08-21
- HTTP 明文访问会 301 跳转到 HTTPS。

### 6.5 CORS 基础检查

对 `Origin: https://evil.example` 请求受保护接口，响应没有 `Access-Control-Allow-Origin`，符合默认关闭不可信跨域预期。

## 7. HarmonyOS / ArkTS 客户端构建与测试

### 7.1 工具链发现

检测到：

```text
D:/DevEco Studio/sdk
D:/DevEco Studio/tools/node/node.exe
D:/DevEco Studio/tools/hvigor/bin/hvigorw.js
D:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe
```

Hvigor：

```text
Hvigor 5.19.7
```

### 7.2 Hvigor tasks

命令：

```bash
DEVECO_SDK_HOME=D:/DevEco Studio/sdk \
NODE_HOME=D:/DevEco Studio/tools/node \
"D:/DevEco Studio/tools/node/node.exe" \
"D:/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
tasks --no-daemon --stacktrace
```

结果：**PASS**

证据：`BUILD SUCCESSFUL in 22 s 682 ms`。

### 7.3 assembleHap

结果：**WARN**

证据：

```text
BUILD SUCCESSFUL in 33 s 769 ms
WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured in current project.
```

产物：

- `D:/test2/entry/build/default/outputs/default/entry-default-unsigned.hap`

### 7.4 assembleApp

结果：**WARN**

证据：

```text
BUILD SUCCESSFUL in 25 s 950 ms
WARN: Will skip sign 'hos_hap'
WARN: Will skip sign 'app'
WARN: If obfuscation is needed, enable obfuscation settings...
```

产物：

- `D:/test2/build/outputs/default/test2-default-unsigned.app`
- `D:/test2/build/outputs/default/symbol/release/app-symbol.zip`

### 7.5 ArkTS 本地单测

命令：

```bash
DEVECO_SDK_HOME=D:/DevEco Studio/sdk \
NODE_HOME=D:/DevEco Studio/tools/node \
"D:/DevEco Studio/tools/node/node.exe" \
"D:/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
test --no-daemon --stacktrace
```

结果：**PASS**

证据：

```text
Tests run: 16
Failure:   0
Error:     0
Pass:      16
Ignore:    0
```

报告：

- `D:/test2/entry/.test/default/outputs/test/reports/index.html`
- `D:/test2/entry/.test/default/intermediates/test/coverage_data/test_result.txt`

### 7.6 UnitTestBuild

结果：**PASS**

证据：`BUILD SUCCESSFUL in 9 s 930 ms`。

### 7.7 客户端测试用例清单

本地单测：`entry/src/test/LocalUnit.test.ets`

| 用例数 | 覆盖方向 |
|---:|---|
| 16 | 课表导入解析、单双周展开、LocalDataStore fallback、数据库 schema、FileService 安全路径、SessionStorage、AdminCourseRepository CRUD/校验/删除保护等。 |

OHOS instrument：

| 文件 | 用例数 | 状态 |
|---|---:|---|
| `entry/src/ohosTest/ets/test/Ability.test.ets` | 1 | 未执行，需要模拟器/真机。 |
| `entry/src/ohosTest/ets/test/List.test.ets` | 0 | 空/模板文件。 |

设备状态：

```bash
"D:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe" list targets
```

结果：**BLOCKED**

```text
[Empty]
```

### 7.8 客户端覆盖率

结果：**WARN / 高风险缺口**

证据：

```text
Lines:     885/14268 = 6.203%
Functions: 150/6189 = 2.424%
Branches:  205/3700 = 5.541%
```

影响：

- 当前 16 个本地单测只能证明部分纯逻辑/仓储路径。
- 页面、导航、权限守卫、远程 API 错误路径、UI 状态流基本未被自动化覆盖。
- `pages` 目录覆盖率接近 0，需依赖设备测试/人工验证或引入更可重复的 UI 测试流程。

## 8. 静态安全审查

### 8.1 密钥与环境变量

结果：**PASS/WARN**

观察：

- `server/.env.example` 使用占位符：`JWT_SECRET=__REPLACE_WITH_RANDOM_SECRET__`。
- `server/test/jest.setup.js` 设置测试用 `JWT_SECRET`，属于测试环境固定值。
- `server/src/auth.js` 要求 `JWT_SECRET` 存在且长度至少 16，否则服务拒绝启动。
- SMTP、PG、CORS、限流等配置来自环境变量。

未发现明显生产硬编码 API key/token/private key。

### 8.2 JWT / 密码

结果：**PASS**

观察：

- JWT 使用 `jsonwebtoken`，`expiresIn: '7d'`。
- `server/src/hash.js` 新密码使用 `bcryptjs`，`BCRYPT_ROUNDS = 10`。
- 旧 SHA-256 账号登录成功后惰性升级到 bcrypt。

建议：

- 如果面向生产长期使用，考虑提升 bcrypt rounds 或按线上性能压测调整。
- 增加 token 轮换/注销策略测试。

### 8.3 SQL 注入

结果：**PASS/WARN**

观察：

- 路由中的用户输入基本通过 `$1/$2/...` 参数化查询传入。
- 动态 SQL 主要为内部常量拼接，如 `COURSE_COLUMNS`、`SELECTED_COUNT_JOIN`，未发现直接把用户输入拼进 SQL 的证据。

建议：

- 对所有未来新增排序/过滤字段使用白名单。
- 为动态查询新增测试，防止未来回归为字符串拼接。

### 8.4 CORS / 限流 / trust proxy

结果：**PASS/WARN**

观察：

- `app.set('trust proxy', 'loopback')`，避免外部直连伪造 IP 绕过限流。
- CORS 默认关闭，只有 `CORS_ORIGINS` 配置时才放行。
- `globalLimiter` / `authLimiter` 存在，并有 `ratelimit.test.js`。

建议：

- 增加全局限流、不同 IP、窗口重置的分支测试。
- 线上确认 nginx 代理链路与 Express `trust proxy` 行为一致。

### 8.5 错误处理与日志

结果：**WARN**

观察：

- `server/src/middleware/errorHandler.js` 对用户返回通用错误：`${label}，请稍后重试`，不会直接暴露 stack。
- 服务端日志会 `console.error` stack，属于服务端诊断用途。
- `server/src/index.js` 启动时使用 `console.log`。
- `migrate.js`、`seed.js` 有 CLI 输出，合理。

建议：

- 生产服务建议引入结构化 logger 替代 `console.log/error`，至少对敏感字段做脱敏。
- 目前未见密码/token 被直接打印。

### 8.6 依赖安全

结果：**FAIL**

详见第 9 节。

## 9. 依赖与供应链审计

### 9.1 npm audit

命令：

```bash
cd /d/test2/server && npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none
```

结果：**FAIL**

证据：

```text
nodemailer <=8.0.4
Severity: high
fix available via `npm audit fix --force`
Will install nodemailer@8.0.10, which is a breaking change
1 high severity vulnerability
```

受影响依赖：

- `nodemailer@6.10.1`
- 生产 direct dependency

相关 advisory：

- `GHSA-mm7p-fcc7-pg87`
- `GHSA-rcmh-qjqh-p98v`
- `GHSA-c7w3-x93f-qmm8`
- `GHSA-vvjj-xcjg-gr5g`

建议：

1. 不要直接无脑运行 `npm audit fix --force`。
2. 单独规划 `nodemailer` 大版本升级到 `8.0.10+`。
3. 阅读 breaking changes，验证 QQ SMTP / 验证码发送路径。
4. 升级后运行：
   - `npm run check:syntax`
   - `npm test -- --runInBand`
   - `npm run test:coverage -- --runInBand`
   - 邮箱验证码真实/沙箱发送验证。

### 9.2 registry 审计端点

默认 registry：`https://registry.npmmirror.com`

问题：默认 `npm audit` 对该镜像返回：

```text
[NOT_IMPLEMENTED] /-/npm/v1/security/* not implemented yet
```

建议：CI 安全审计命令显式使用：

```bash
npm audit --omit=dev --registry=https://registry.npmjs.org
```

### 9.3 lockfile 与签名

结果：**PASS**

证据摘要：

- `package-lock.json` 为 lockfileVersion 3。
- lockfile package count 390。
- 缺失 integrity 数：0。
- `npm audit signatures --registry=https://registry.npmjs.org`：388 packages verified，34 attestations verified。

## 10. 质量门禁与可维护性

### 10.1 源码大文件

排除 `.git`、`server/node_modules`、`.hvigor`、`build`、`entry/build`、`entry/.test`、`entry/.preview`、`server/coverage`、`oh_modules`、`.codegraph` 后，超过 800 行的真实源码/配置文件：

```text
5063 server/package-lock.json
```

结论：应用源码未发现超过 800 行的大文件；`package-lock.json` 是正常 lockfile，不作为拆分对象。

### 10.2 console 使用

发现：

- `server/src/index.js`：启动日志 `console.log`。
- `server/src/auth.js`：JWT_SECRET 缺失时 `console.error` 并退出。
- `server/src/db.js`：pg pool error 日志。
- `server/src/middleware/errorHandler.js`：服务端错误 stack 日志。
- `entry/src/main/ets/app/AppStartup.ets`：本地 DB 初始化失败日志。
- `entry/src/main/ets/repositories/AdminRepository.ets`：RDB 写入失败非阻断 warning。
- `migrate.js` / `seed.js`：CLI 输出。

结论：没有发现明显调试残留 `console.log` 泄露敏感数据；但生产后端最好替换为结构化 logger。

## 11. 文档与 CI 一致性

### 11.1 README 后端测试说明

README 记录：

- 108 个用例 / 11 个套件。
- 行覆盖率 83.2%、语句 82.3%、函数 80.4%、分支 63.6%。
- 本轮实测：108/108、11/11；覆盖率 83.19/82.29/80.41/63.63。

结论：**基本一致**。

### 11.2 客户端测试文档

`docs/CLIENT_TESTING.md` 说明：

- 本地单测在 `entry/src/test/`。
- 设备测试在 `entry/src/ohosTest/`。
- 设备测试依赖模拟器/真机。

本轮实测与文档一致：本地单测可跑，设备测试因 `hdc list targets` 为空而阻塞。

### 11.3 CI

`.github/workflows/backend-tests.yml`：

- `npm ci`
- `npm run check:syntax`
- `npm run test:coverage`

结论：后端 CI 与当前后端门禁一致。建议增加 `npm audit --omit=dev --registry=https://registry.npmjs.org`，并明确是否允许高危漏洞失败。

### 11.4 线上健康检查文档/部署契约

问题：文档/记忆中线上 API 基路径为 `https://lsw666.duckdns.org/api`，但 `/api/health` 当前 404。需统一：

- 后端是否应该暴露 `/health` 还是 `/api/health`。
- nginx `/api/` 是否 strip prefix。
- App/监控/README 使用哪个健康端点。

## 12. 问题清单

| 编号 | 严重级别 | 状态 | 问题 | 证据 | 建议 |
|---|---|---|---|---|---|
| P0-TEST-01 | HIGH | OPEN | 生产依赖 `nodemailer@6.10.1` 存在高危漏洞 | `npm audit --omit=dev --registry=https://registry.npmjs.org` 报 1 high | 规划升级到 `nodemailer@8.0.10+`，验证邮箱验证码发送。 |
| P0-TEST-02 | HIGH | OPEN | 线上文档化健康端点 `/api/health` 返回 404 HTML | `curl https://lsw666.duckdns.org/api/health` → 404 `Cannot GET /api/health` | 修复 nginx prefix 或后端增加 `/api/health`，统一 JSON 信封。 |
| P1-TEST-03 | MEDIUM | OPEN | 客户端 ArkTS 自动化覆盖率极低 | Lines 6.203%、Functions 2.424%、Branches 5.541% | 优先补 repository/common/AppRoute/RemoteApi 错误路径测试。 |
| P1-TEST-04 | MEDIUM | OPEN | OHOS 设备测试未执行 | `hdc list targets` → `[Empty]` | 启动模拟器/连接真机后运行 `entry/src/ohosTest/`。 |
| P1-TEST-05 | MEDIUM | OPEN | 后端分支覆盖率仅 63.63% | LCOV：18/20 文件分支覆盖低于 80% | 补 `codeStore.js`、`mappers.js`、`rateLimit.js`、route error branches。 |
| P2-TEST-06 | LOW | OPEN | HAP/APP 产物未签名 | Hvigor warning: skip sign | 本机/CI 安全配置 signingConfigs，不提交密钥。 |
| P2-TEST-07 | LOW | OPEN | release 混淆未启用 | assembleApp warning | 若正式发布，补混淆规则并验证路由/序列化不被破坏。 |
| P2-TEST-08 | LOW | OPEN | 默认 npm mirror 不支持 audit API | npmmirror audit endpoint 404 NOT_IMPLEMENTED | CI audit 显式使用 npmjs registry。 |
| P2-TEST-09 | LOW | OPEN | 生产日志仍使用 console | `server/src/index.js` 等 | 引入结构化 logger，保留 CLI 脚本 console。 |

## 13. 发布建议

### 13.1 当前是否可发布？

结论：**不建议直接作为正式生产发布包发布**。

原因：

1. `nodemailer` 存在生产高危依赖漏洞。
2. 线上 `/api/health` 与文档基路径不一致，监控/健康检查可能失败。
3. HarmonyOS 产物未签名，不能代表正式发布包。
4. 客户端 UI/设备流程未自动化执行，覆盖率很低。

### 13.2 可以认为已通过的部分

- 后端本地语法、单元/集成风格 Jest 测试、项目覆盖率门禁通过。
- 后端核心业务规则（选课/实践并发、防超卖、写操作）回归通过。
- TLS 证书与 HTTPS 重定向通过。
- 受保护接口未认证/无效 token 拒绝通过。
- HarmonyOS ArkTS 构建与本地单测通过。

### 13.3 建议下一轮修复顺序

1. **修复线上 `/api/health`**：统一 nginx 与后端路由，确保返回 `{ success, data, error }`。
2. **升级 `nodemailer`**：处理高危依赖，验证邮箱验证码流程。
3. **连接模拟器/真机执行 OHOS 测试**：至少 Ability 冒烟 + 登录/首页/选课/管理端关键路径人工或自动化记录。
4. **补后端覆盖率短板**：`codeStore.js`、`mappers.js`、`rateLimit.js`、admin/evaluation route 分支。
5. **补客户端测试**：repository/common/AppRoute/RemoteApi/状态转换；逐步建立设备测试门禁。
6. **配置签名与 release 验证**：生成可安装/可发布产物。

## 14. 推荐回归命令清单

> **历史命令说明（2026-06-09 更新）**：本节命令保留 2026-06-08 旧域名 `lsw666.duckdns.org` 的历史证据与当时建议，不代表当前域名迁移后的最新复测命令。当前复测命令与待填充证据请以 `docs/TEST_REPORT_2026-06-09.md` 为准。

### 后端

```bash
cd /d/test2/server
npm run check:syntax
npm test -- --runInBand
npm run test:coverage -- --runInBand
npm audit --omit=dev --registry=https://registry.npmjs.org
```

### 线上冒烟

```bash
curl -i https://lsw666.duckdns.org/api/health
curl -i https://lsw666.duckdns.org/api/courses
curl -i -H 'Authorization: Bearer invalid.invalid.invalid' https://lsw666.duckdns.org/api/courses
openssl s_client -connect lsw666.duckdns.org:443 -servername lsw666.duckdns.org -verify_return_error -brief </dev/null
```

### HarmonyOS / ArkTS

```bash
DEVECO_SDK_HOME='D:/DevEco Studio/sdk' \
NODE_HOME='D:/DevEco Studio/tools/node' \
'D:/DevEco Studio/tools/node/node.exe' \
'D:/DevEco Studio/tools/hvigor/bin/hvigorw.js' \
tasks --no-daemon --stacktrace

DEVECO_SDK_HOME='D:/DevEco Studio/sdk' \
NODE_HOME='D:/DevEco Studio/tools/node' \
'D:/DevEco Studio/tools/node/node.exe' \
'D:/DevEco Studio/tools/hvigor/bin/hvigorw.js' \
assembleHap --no-daemon --stacktrace

DEVECO_SDK_HOME='D:/DevEco Studio/sdk' \
NODE_HOME='D:/DevEco Studio/tools/node' \
'D:/DevEco Studio/tools/node/node.exe' \
'D:/DevEco Studio/tools/hvigor/bin/hvigorw.js' \
assembleApp --no-daemon --stacktrace

DEVECO_SDK_HOME='D:/DevEco Studio/sdk' \
NODE_HOME='D:/DevEco Studio/tools/node' \
'D:/DevEco Studio/tools/node/node.exe' \
'D:/DevEco Studio/tools/hvigor/bin/hvigorw.js' \
test --no-daemon --stacktrace

'D:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe' list targets
```

## 15. 最终判定

**NEEDS WORK**

项目主体质量比普通课程项目高：后端自动化测试扎实，业务规则和安全回归覆盖明确，HarmonyOS 构建也能通过。但正式发布前必须至少处理：

1. `nodemailer` 高危依赖。
2. 线上 `/api/health` 健康检查契约。
3. HarmonyOS 设备测试与签名发布验证。

完成这些后，再进行一次针对性回归测试，可重新评估为 **PASS / READY FOR RELEASE**。
