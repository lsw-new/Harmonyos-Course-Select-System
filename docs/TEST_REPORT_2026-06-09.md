# D:\test2 后端域名迁移复测报告

- **测试日期**：2026-06-09
- **当前公网 API**：`https://lsw666.dns.army/api`
- **测试范围**：文档契约收口、本地后端自动化门禁、依赖审计、线上 HTTPS/鉴权/只读验证、线上受控写入验证
- **线上写入前缀**：`cc_test_20260609_*`
- **状态**：PASS WITH WARNINGS / 复测通过但有警告；本地后端门禁通过，线上可信 HTTPS、鉴权、只读与受控写入已复测通过；线上测试反馈/请假/审批/实践报名副作用已在服务器清理并复验为 0 行；仍有 npm audit endpoint 超时阻塞、branch coverage 低于通用 80% 目标。

## 1. 执行摘要

> 2026-06-09 证书重新签发后，`lsw666.dns.army` 已呈现匹配当前域名的证书，线上 HTTPS/API 复测恢复通过。本报告仍保留两个警告：生产依赖 `npm audit` 因 npmjs audit endpoint 超时未取得 advisory 明细；branch coverage 为 63.63%，低于通用 80% 质量目标。

| 检查项 | 当前状态 | 证据 |
|---|---|---|
| 文档契约检查 | PASS | README、server README、nginx 部署文档当前公网 API 契约为 `https://lsw666.dns.army/api`；README remote mode 明确失败会显式报错，无静默 local/mock fallback；旧 duckdns 仅作为历史证据保留。 |
| 本地语法检查 | PASS | `cd /d/test2/server && npm run check:syntax`：39 个 JS 文件无语法错误。 |
| Jest 全量测试 | PASS | `cd /d/test2/server && npm test -- --runInBand`：11 suites / 109 tests 全部通过；最终完成前再次执行同命令，仍为 11/11 suites、109/109 tests 通过。 |
| 覆盖率门禁 | PASS / WARN | `cd /d/test2/server && npm run test:coverage -- --runInBand`：Jest coverage 命令通过项目已配置阈值；Statements 82.29% (730/887)、Functions 80.41% (78/97)、Lines 83.19% (723/869) 均超过 80%；Branches 63.63% (364/572) 低于通用 80% 质量目标，记为质量警告，不阻断本地后端门禁。产物 `D:/test2/server/coverage/lcov.info`。 |
| 依赖审计 | BLOCKED / WARN | `cd /d/test2/server && npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none`：退出码 1；已显式使用 npmjs registry，但 audit bulk endpoint 请求超时（`connect ETIMEDOUT 198.18.1.81:443`），未取得 advisory 明细，不能记为通过。 |
| 线上 HTTPS / health | PASS | `openssl s_client -connect lsw666.dns.army:443 -servername lsw666.dns.army -verify_return_error -brief </dev/null`：TLSv1.3、`TLS_AES_256_GCM_SHA384`、`Peer certificate: CN=lsw666.dns.army`、`Verification: OK`。`GET https://lsw666.dns.army/api/health`：HTTP 200，JSON，`success=true`，`data` 含 `db`/`now`，`error=null`。 |
| 鉴权 / CORS | PASS | 未认证 `/api/courses` 返回 HTTP 401 JSON `code=unauthorized`；无效 token `/api/courses` 返回 HTTP 401 JSON `code=unauthorized`；`Origin: https://evil.example` 的 OPTIONS 响应没有放行该 Origin（无 `Access-Control-Allow-Origin: https://evil.example`），符合不可信跨域不放行预期。 |
| 线上只读接口 | PASS | 学生账号 `2023307020941` 登录 HTTP 200，`role=student`，token 存在但未打印；认证只读端点均 HTTP 200 JSON：课程 2、选课轮次 `round-2026-main`、已选课程 0、成绩 2、通知 2、请假 2、反馈 1、评教 1、实践 2。 |
| 学生端写入 | PASS / WARN | 无效验证码注册 HTTP 400，未创建账号；缺失账号找回密码 HTTP 404；选课 `course-cs101` HTTP 200 后退课 HTTP 200；反馈创建 HTTP 200，ID `fb-1781014485650`，已在服务器清理并复验 `feedback_rows=0`；请假创建 HTTP 200，ID `lv-1781014485969`，关联审批 `ap-lv-1781014485969` 已一并清理并复验 `leave_rows=0`、`approval_rows=0`；实践 `prac-001` 报名 HTTP 200 后取消 HTTP 200，测试 signup 行已清理并复验 `practice_signup_rows=0`。 |
| 管理端写入 | PASS / WARN | 管理员账号 `A20251001` 登录 HTTP 200，`role=admin`，token 存在但未打印；管理端只读端点均 HTTP 200：学生 1、角色 2、审计日志 2、评教模板 2；评教模板创建/更新/删除均 HTTP 200，ID `qt-1781014489014` 已删除；持久通知发布按安全策略跳过，因该操作用户可见、持久且无删除端点，需另行明确批准。 |

## 2. 文档与域名契约

| 检查对象 | 当前状态 | 备注 |
|---|---|---|
| 根 README 公网 API 契约 | PASS | 当前公网客户端/API 契约为 `https://lsw666.dns.army/api`；remote mode 失败显式报错，不静默回退 local/mock。 |
| server README / 部署说明 | PASS | 当前说明使用 `https://lsw666.dns.army/api`，并保留后端本机/内网监听语境。 |
| nginx HTTPS 部署文档 | PASS | 当前域名、反代路径与仅公网暴露 80/443 的说明已对齐新域名契约；证书复验已确认 `CN=lsw666.dns.army`。 |
| 2026-06-08 历史报告迁移说明 | PASS | 旧 duckdns 证据保留为历史性质，不作为当前契约。 |

### 2.1 域名残留扫描

本轮按 Task 4 要求扫描仓库文本文件中的 `lsw666.duckdns.org`、`lsw666.dns.army`、`140.245.121.125`、`138.2.47.185`、`:8090`，排除 `node_modules`、`.git`、`coverage`、`.hvigor`、`build` 等依赖/构建产物。

结论：当前运行配置与当前契约文档使用 `lsw666.dns.army`；旧 `lsw666.duckdns.org` 仅保留在历史报告或生成测试缓存中，不作为当前 source/runtime 契约。

- AppConfig 当前基路径：`entry/src/main/ets/app/AppConfig.ets` 为 `static baseUrl: string = 'https://lsw666.dns.army/api';`。
- README / nginx / server 文档状态：根 `README.md`、`server/README.md`、`server/deploy/nginx-https-setup.md` 当前公网客户端契约均为 `https://lsw666.dns.army/api`；部署说明中的服务器 IP `140.245.121.125` 仅作为 DNS A 记录/部署主机信息保留。
- 旧 duckdns 处理：`docs/TEST_REPORT_2026-06-08.md` 中的 `lsw666.duckdns.org` 已在报告开头和命令区标明为 2026-06-08 历史测试证据；本报告仅在历史问题复核中提及旧域名，不作为当前契约。
- `:8090` 处理：`:8090` 仅出现在 Node/pm2 本机监听、nginx upstream、`localhost:8090` 本地 smoke 或部署安全说明中；公开客户端/API 文档不把 `:8090` 描述为公网入口。
- 生成缓存说明：扫描发现 `entry/.test/default/cache/default/default@UnitTestArkTS/esmodule/debug/entry/src/main/ets/app/AppConfig.ts` 与 `entry/.test/default/outputs/test/reports/app/AppConfig.ets.html` 含旧 `https://lsw666.duckdns.org/api`。`entry/.test` 是测试生成缓存/报告，不是源代码或运行时契约，按本任务要求作为 generated artifact 排除，不在本轮改写。
- 未发现 `138.2.47.185` 残留。

## 3. 本地后端自动化测试

| 检查项 | 当前状态 | 命令/证据 |
|---|---|---|
| 语法检查 | PASS | 初次在 `D:/test2` 误运行 `npm run check:syntax`，因根目录缺少 `package.json` 失败；这是工作目录错误，不计入后端门禁结果。随后执行 `cd /d/test2/server && npm run check:syntax`：`✓ 语法检查通过：39 个 JS 文件无语法错误。` |
| Jest 全量测试 | PASS | `cd /d/test2/server && npm test -- --runInBand`：11 个测试套件全部通过；109 个测试全部通过；Snapshots 0。完成前复验再次执行同命令，结果仍为 11 suites / 109 tests 全部通过。 |
| 覆盖率 | PASS / WARN | `cd /d/test2/server && npm run test:coverage -- --runInBand`：11 个测试套件全部通过；109 个测试全部通过；Jest coverage 命令通过项目已配置阈值。Statements 82.29% (730/887)、Functions 80.41% (78/97)、Lines 83.19% (723/869) 均超过 80%；Branches 63.63% (364/572) 低于通用 80% 质量目标，记为质量警告，不阻断本地后端门禁。覆盖率产物已生成：`D:/test2/server/coverage/lcov.info`。 |
| 高风险定向套件 | PASS | 领域写入/规则/并发定向：`node node_modules/jest/bin/jest.js --config D:/test2/server/package.json D:/test2/server/test/concurrency.test.js D:/test2/server/test/rules.test.js D:/test2/server/test/selections.test.js D:/test2/server/test/practice.test.js D:/test2/server/test/mutations.test.js --runInBand`，5 suites / 51 tests 全部通过。鉴权/安全/限流定向：`node node_modules/jest/bin/jest.js --config D:/test2/server/package.json D:/test2/server/test/auth.test.js D:/test2/server/test/auth-flows.test.js D:/test2/server/test/security.test.js D:/test2/server/test/ratelimit.test.js --runInBand`，4 suites / 26 tests 全部通过。 |
| `/api/health` 定向复验 | PASS | 完成前复验执行 `node node_modules/jest/bin/jest.js --config D:/test2/server/package.json D:/test2/server/test/endpoints-read.test.js --runInBand`：1 suite / 24 tests 全部通过，包含 `/api/health` 成功信封测试。 |

## 4. 依赖与供应链审计

记录 `npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none` 结果。本轮未运行 `npm audit fix`，未修改 `package.json` / `package-lock.json`，本计划不改变依赖版本。

| 检查项 | 当前状态 | 备注 |
|---|---|---|
| npm audit（生产依赖） | BLOCKED / WARN | 执行命令：`cd /d/test2/server && npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none`。退出码：1。输出摘要：`npm warn audit request to https://registry.npmjs.org/-/npm/v1/security/advisories/bulk failed, reason: connect ETIMEDOUT 198.18.1.81:443`；随后 `npm error audit endpoint returned an error`。结论：npmjs registry audit endpoint 网络/注册表访问失败，未取得漏洞清单，不能判定 PASS。 |
| advisory 摘要 | BLOCKED | 因 audit endpoint 超时，未返回 advisory summary。包名：未返回；严重级别：未返回；受影响版本：未返回；修复可用性：未返回。 |
| 依赖变更 | PASS | 未运行 `npm audit fix`；未修改 `package.json`、`package-lock.json`；本计划不改变依赖版本。 |
| lockfile / integrity / signatures | NOT RUN | 本任务仅执行生产依赖 audit；未执行额外签名或完整性检查。 |
| registry mirror 限制 | PASS / WARN | 命令已显式使用 `--registry=https://registry.npmjs.org`，未使用 npmmirror audit API；但 npmjs audit endpoint 本次超时，审计结果仍为 BLOCKED / WARN。 |

### 4.1 历史问题复核

| 历史问题 | 旧报告状态 | 当前复核状态 | 备注 |
|---|---|---|---|
| `nodemailer` audit 高危提示 | 2026-06-08：FAIL | BLOCKED / WARN | 本轮 audit 使用 npmjs registry 但 endpoint 超时，未返回 advisory 明细；无法确认当前是否仍存在 `nodemailer` advisory。 |
| `/api/health` 在旧 duckdns 基路径返回 404 | 2026-06-08：FAIL | PASS | 当前域名已迁移为 `lsw666.dns.army`；证书修复后 `GET /api/health` 返回 HTTP 200 JSON 成功信封。 |
| npm mirror audit limitation | 2026-06-08：OPEN | PASS / WARN | 本轮命令已显式使用 `--registry=https://registry.npmjs.org`，规避 npmmirror audit API 限制；但 npmjs audit endpoint 超时导致审计仍 BLOCKED / WARN。 |
| HarmonyOS 客户端设备测试、覆盖率、签名、混淆 | 2026-06-08：WARN/BLOCKED/OPEN | OUT OF SCOPE | 本报告聚焦后端域名迁移复测；客户端/设备/签名项不在本轮后端域名复测范围内。 |

## 5. 线上 HTTPS、鉴权、CORS 与只读验证

| 检查项 | 当前状态 | 证据 |
|---|---|---|
| `/api/health` | PASS | `GET https://lsw666.dns.army/api/health`：HTTP 200；`Content-Type: application/json; charset=utf-8`；JSON `success=true`，`data` 含 `db`/`now`，`error=null`。 |
| TLS / SNI / 证书链 | PASS | `openssl s_client -connect lsw666.dns.army:443 -servername lsw666.dns.army -verify_return_error -brief </dev/null`：exit 0；`Protocol version: TLSv1.3`；`Ciphersuite: TLS_AES_256_GCM_SHA384`；`Peer certificate: CN=lsw666.dns.army`；`Verification: OK`。 |
| HTTP 到 HTTPS 行为 | NOT RUN | 本轮聚焦 HTTPS API 契约，未额外测试明文 HTTP 重定向。 |
| 未认证拒绝 | PASS | `GET /api/courses` 不带 token：HTTP 401；JSON `success=false`，`code=unauthorized`。 |
| 无效 token 拒绝 | PASS | `GET /api/courses` 携带 `Authorization: Bearer invalid.invalid.invalid`：HTTP 401；JSON `success=false`，`code=unauthorized`。 |
| 不可信 Origin / CORS | PASS | `OPTIONS /api/auth/login` 携带 `Origin: https://evil.example`：HTTP 200，`Allow: POST`，未出现 `Access-Control-Allow-Origin: https://evil.example`；按响应头判断，不可信 Origin 未被放行。 |
| 学生登录 | PASS | POST `/api/auth/login`，账号 `2023307020941`：HTTP 200；JSON `success=true`，`role=student`，`accountId=2023307020941`，token 存在但未在报告或摘要中打印。 |
| 只读端点 | PASS | 使用学生 token（未打印）访问：`/api/courses?status=open` HTTP 200 items=2；`/api/selection-rounds/active` HTTP 200 id=`round-2026-main`；`/api/selections` HTTP 200 items=0；`/api/grades` HTTP 200 items=2；`/api/notices` HTTP 200 items=2；`/api/leave` HTTP 200 items=2；`/api/feedback` HTTP 200 items=1；`/api/evaluations` HTTP 200 items=1；`/api/practice` HTTP 200 items=2。 |

## 6. 线上受控写入验证

| 写入类别 | 当前状态 | 计划约束 / 实际执行情况 |
|---|---|---|
| 注册成功路径 / 真实邮箱验证码路径 | NOT RUN | 未请求真实邮箱验证码，未执行注册成功路径；避免产生真实邮件副作用。 |
| 找回密码成功路径 / 真实验证码路径 | NOT RUN | 未执行 reset-password 成功路径；避免依赖真实邮箱验证码。 |
| 注册 / 重置负向检查 | PASS | 注册无效验证码：HTTP 400，`success=false`，错误为验证码不存在/需重新获取；缺失账号找回密码：HTTP 404，`success=false`，错误为账号不存在。未创建账号。 |
| 学生登录 / token 前置条件 | PASS | 学生账号 `2023307020941` 登录 HTTP 200，token 存在但未打印。 |
| 选课 / 退课 | PASS | 候选课程 `course-cs101`；POST `/api/selections` HTTP 200，`success=true`，data keys 含 `selected`；随后 DELETE `/api/selections` HTTP 200，`success=true`，data keys 含 `dropped`。最终选课副作用已回滚。 |
| 反馈 | PASS / CLEANED | POST `/api/feedback` HTTP 200，`success=true`，创建反馈 ID `fb-1781014485650`；随后服务器事务清理已删除该记录，复验 `feedback_rows=0`。 |
| 请假 | PASS / CLEANED | POST `/api/leave` HTTP 200，`success=true`，创建请假 ID `lv-1781014485969`，并产生关联审批 `ap-lv-1781014485969`；随后服务器事务清理已删除请假及关联审批，复验 `leave_rows=0`、`approval_rows=0`。 |
| 实践报名 / 取消 | PASS | 候选项目 `prac-001`；POST `/api/practice/prac-001/signup` HTTP 200；随后 DELETE `/api/practice/prac-001/signup` HTTP 200。最终实践报名已取消。 |
| 管理端登录 / token 前置条件 | PASS | 管理员账号 `A20251001` 登录 HTTP 200，`role=admin`，token 存在但未打印。 |
| 管理端权限读取 | PASS | 使用 admin token（未打印）访问：`/api/admin/students` HTTP 200 items=1；`/api/admin/roles` HTTP 200 items=2；`/api/admin/audit-logs` HTTP 200 items=2；`/api/admin/eval/templates` HTTP 200 items=2。 |
| 管理端评教模板 create/update/delete | PASS | POST `/api/admin/eval/templates` HTTP 200，创建 ID `qt-1781014489014`；PUT 同 ID HTTP 200；DELETE 同 ID HTTP 200，data keys 含 `deleted`。最终模板副作用已清理。 |
| 管理端持久通知发布 | SKIPPED | 未执行 POST `/api/admin/notices`。该操作会发布用户可见持久通知且没有删除端点，即使其他验证通过也需要用户第二次明确批准；本轮未获得该批准。 |

Task 8-9 结论：线上可信 HTTPS 修复后，学生端核心写入（选课/退课、反馈、请假、实践报名/取消）与管理端评教模板 CRUD 均可达并返回成功；未使用 `curl -k`，未关闭证书校验，未绕过邮箱验证码或限流。注册/找回密码成功路径因需要真实邮箱验证码未执行，管理端持久通知发布因持久且无删除端点未执行。

## 7. 线上副作用与清理建议

| 副作用类别 | 当前状态 | 当前记录 | 清理建议 |
|---|---|---|---|
| 线上注册账号 | NOT CREATED | 未执行注册成功路径；无 `cc_test_20260609_*` 账号创建。 | 无需清理。 |
| 学生端选课 / 退课 | CLEANED | `course-cs101` 已选后立即退课成功。 | 无需清理。 |
| 学生端反馈 | CLEANED | 反馈 ID：`fb-1781014485650`；标题含 `cc_test_20260609_domain_retest`。服务器事务清理已删除该记录；复验 `feedback_rows=0`。 | 已清理，无需后续处理。 |
| 学生端请假 / 审批实例 | CLEANED | 请假 ID：`lv-1781014485969`；关联审批 ID：`ap-lv-1781014485969`。服务器事务清理已删除请假及关联审批；复验 `leave_rows=0`、`approval_rows=0`。 | 已清理，无需后续处理。 |
| 实践报名 / 取消 | CLEANED | `prac-001` 报名后取消成功；服务器清理已删除本轮取消后的 `practice_signups` 测试行；复验 `practice_signup_rows=0`。 | 已清理，无需后续处理。 |
| 密码重置 / 邮件验证码 | NOT CREATED | 未执行真实邮箱验证码请求或成功重置路径。 | 无需清理。 |
| 管理端评教模板 | CLEANED | 模板 ID：`qt-1781014489014`；创建、更新后已删除成功。 | 无需清理。 |
| 管理端持久通知 | NOT CREATED / SKIPPED | 未执行 notice publish；未发布持久通知。该操作用户可见且无删除端点，需另行批准。 | 无需清理。 |

## 7.1 阻塞 / 跳过 / 警告项汇总

- 依赖审计：`npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none` 因 npmjs audit endpoint `connect ETIMEDOUT 198.18.1.81:443` 阻塞，未返回 advisory 明细；不能声明依赖审计通过。
- 覆盖率警告：branch coverage 为 63.63%，低于通用 80% 质量目标；Jest 项目阈值已通过，但仍建议补充分支测试。
- 注册/找回密码成功路径：未执行真实邮箱验证码路径，避免触发真实邮件副作用；本轮仅验证无效验证码和缺失账号负向路径。
- 管理端持久通知：未执行，因其会创建用户可见持久数据且无删除端点，需要第二次明确批准。
- 线上持久副作用：反馈 `fb-1781014485650`、请假 `lv-1781014485969` 及关联审批 `ap-lv-1781014485969` 已通过服务器事务清理；复验 `feedback_rows=0`、`leave_rows=0`、`approval_rows=0`。

## 8. 结论与后续建议

当前结论：**PASS WITH WARNINGS / 复测通过但有警告**。

证书重新签发并配置生效后，`lsw666.dns.army` 的可信 HTTPS 已恢复：证书 `CN=lsw666.dns.army`，链验证 OK；`/api/health`、未认证/无效 token 拒绝、CORS 不可信 Origin、学生端只读接口、学生端受控写入、管理端只读与评教模板 CRUD 均完成线上复测。未绕过 TLS，未打印 token，未发布持久通知。

仍需跟进：

1. npmjs audit endpoint 可达后，重新运行 `cd /d/test2/server && npm audit --omit=dev --registry=https://registry.npmjs.org --audit-level=none`；在取得 advisory 明细前不要声明 dependency audit pass。
2. 处理 branch coverage 63.63% 低于通用 80% 目标的问题，优先补足高风险分支路径测试。
3. 线上测试副作用已清理：反馈 `fb-1781014485650`、请假 `lv-1781014485969`、审批 `ap-lv-1781014485969` 与本轮实践报名测试行均已删除并复验为 0 行。
4. 如需执行管理端持久通知发布，需另行明确批准，并在执行后记录通知 ID 与清理方案。
