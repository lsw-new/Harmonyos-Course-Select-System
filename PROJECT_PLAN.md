# 教学管理系统 · 项目完善计划（从半成品到成品）

> 目标：把当前"可演示的高保真客户端原型"打磨成"功能完备、可交付、可发布"的成品。
> 本文档落到具体文件 / 接口 / 任务 / 验收标准 / 排期，作为后续迭代的唯一事实来源（SSOT）。

---

## 0. 如何使用本计划

- **优先级**：`P0`=成品必须；`P1`=完整体验应有；`P2`=加分项。
- **Track（口径）**：`A`=完整可用客户端（可单机/弱后端跑通全部功能，适合课程"成品"验收）；`B`=全栈产品（A + 独立后端服务、真实多用户）。
- 不想做后端就只走 **Track A**——它本身已是一个"功能完整、有持久化、有测试、能出签名包"的成品。Track B 是可选延伸。
- 每个任务给出 **现状 → 缺口 → 完成标准（DoD）→ 估时**（人日，按 1～2 人开发估算，仅供排期参考）。

---

## 1. 现状评估（诚实盘点）

### 已完成 ✅
- 34 个页面 UI + Elysia 设计系统（颜色/圆角/字体 token、`AppIcon` 矢量图标、`StateViews` 加载/空/错三态）。
- 清晰分层：`app`（启动/路由守卫/配置）· `models` · `repositories`（单例仓储）· `mock` · `common/{http,storage,utils,widgets,constants}` · `pages`。
- 全部页面已接入仓储；导航统一经 `AppRoute` 角色守卫；真实登录（mock 校验 + 会话写入）；关键交互（选退课、评教内联问卷、审批通过/驳回、表单提交）已生效。
- 编译通过（ArkTS 严格模式，`hvigorw assembleHap` BUILD SUCCESSFUL）。

### 本质局限 ⚠️（这就是"半成品"的根因）
1. **纯 mock / 内存数据**：`AppConfig.useMock = true`，所有 `Repository` 直接读 `mock/*`，写操作只改内存（重启即丢）。`HttpClient` 已写好却**未被任何仓储调用**。
2. **无真实持久化**：仅 `PreferenceStorage` 存了 token/角色/几个开关；业务数据（选课、成绩、申请…）不落盘。
3. **会话恢复不完整**：`SessionStorage.restore()` 只恢复 token/role，不恢复 `UserProfile`——冷启动后"已登录但无用户资料"。
4. **管理端多处仍是"只读壳"**：课程增删改、选课轮次启停、成绩录入/驳回、评教模板管理、角色/权限/日志等只有 UI 或 toast 占位。
5. **横切能力缺失**：真实文件上传/下载、头像选图、推送通知、深色模式真正换肤、分页/下拉刷新、搜索联动、i18n、无障碍。
6. **工程缺口**：无单元/E2E 测试（`hypium`/`hamock` 依赖与 `ohosTest`/`test` 目录已在，但基本是空的）；无签名配置（构建告警 `skip sign`）；无 CI/CD。

> 结论：**界面是成品级，数据与工程是原型级。** 本计划补齐后两者。

---

## 2. "成品"的定义（验收标准 / Definition of Done）

一个可交付成品需同时满足：

- [ ] 每个页面展示的都是**真实来源**的数据（后端或本地库），不再有写死假数据。
- [ ] 每个按钮/开关/表单都有**真实副作用并持久化**，重启后状态保留。
- [ ] 管理端具备**完整 CRUD 与流程**（课程、选课轮次、成绩、通知、评教、审批、权限）。
- [ ] **鉴权完整**：登录/登出/会话恢复/token 失效跳登录/按角色与权限控制可见性。
- [ ] **健壮性**：所有异步路径有加载/空/错三态 + 重试；表单边界校验；网络异常友好提示。
- [ ] **质量**：核心逻辑单测 ≥80%，关键流程 E2E 通过。
- [ ] **可发布**：配置签名，能产出可安装的 release HAP；通过 `code-linter`。
- [ ] **文档齐全**：README、API 文档、变更日志。

---

## 3. 目标架构演进

### 3.1 客户端（Track A & B 通用）
- 在每个仓储方法内做 `if (AppConfig.useMock) {读mock} else {走 HttpClient}` 分流；`HttpClient` 的 `setTokenProvider`/`setUnauthorizedHandler` 接到 `SessionStorage` 与"跳登录"。
- 新增 **DTO ↔ 领域模型映射层**（`repositories/mappers/`），隔离后端字段变化。
- `SessionStorage.restore()` 增加"冷启动后用 token 重新拉取 profile"。
- 本地持久化升级：用 `@ohos.data.relationalStore`(RDB) 做离线缓存与草稿（选课草稿、表单草稿、通知已读、设置项）。

### 3.2 后端（仅 Track B）
- 选型建议（任选其一）：**NestJS + PostgreSQL + Redis**（JS 栈，和前端同语言）或 **Spring Boot + PostgreSQL**；鉴权 **JWT（access + refresh）**。
- 统一响应封套复用前端已有的 `ApiResponse<T>`（`success/data/error/message/meta`）与 `PageMeta`。
- 部署：容器化 + 华为云/任意云；或课程演示用单机 docker-compose。

---

## 4. 功能补全清单（按模块，逐项到"完成"）

> 标注 `[A]`=客户端即可完成（可先用"内存可写仓储/本地库"实现真实增删改）；`[B]`=需后端支撑才算真。

### 4.1 认证与会话  `P0`
- [A] 🔴 **管理员登录入口缺失（致管理端整体不可达，最高优先）**：冷启动 `EntryAbility` 进学生 `LoginPage`，而该页只有"注册/忘记密码"入口、**没有跳转 `AdminLoginPage` 的按钮**；`AdminLoginPage` 本身已正确（`adminLogin → setAdminSession → clearTo(AdminDashboard)`）却无路可达。用管理员账号在学生登录页输入会被按学生规则校验而失败。**修复**：① `LoginPage` 增加"管理员登录 / Admin"入口 → `AppRoute.go(Routes.AdminLogin)`；② `AdminLoginPage` 增加"返回学生登录"。**DoD**：首屏可切到管理员登录并用 `A20251001 / Admin@2024` 进入仪表盘。`0.5d`
- [A] 会话恢复拉取 profile（修复冷启动空资料）。`0.5d`
- [A] 登出确认、token 失效自动跳登录（接 `HttpClient.onUnauthorized`）。`0.5d`
- [B] 真实登录/注册/找回（短信/邮箱验证码真实下发）、密码加密、refresh token。`3d`
- [A] 凭据安全存储（`preferences` 之上做加密，或用 `@ohos.security`）。`1d`

### 4.2 首页 / 课表 / 今日  `P0`
- [A] 首页搜索框联动（课程/通知/文件结果页）。`1d`
- [A] 课表列头日期按 `TermInfo.weekStartDate + 周次` 真实计算；今日高亮跨月正确。`0.5d`
- [A] 文件下载真实落地（`@ohos.request` 下载 + 打开）。`1d`

### 4.3 选课  `P0`
- [A] 选/退课写入本地库并持久化；学分上限校验、冲突检测真实生效。`1.5d`
- [B] 并发名额扣减、事务一致性、候补队列。`3d`

### 4.4 成绩 / 考试 / 学籍  `P0`
- [A] 学期筛选、GPA 统计由数据计算并缓存；学籍照片展示。`1d`
- [B] 成绩来源对接教务、考试日历同步。`2d`

### 4.5 通知  `P0`
- [A] 已读状态持久化、分类分页、附件下载。`1d`
- [B] 实时推送（`@ohos.pushService`/服务端推送）、发布范围生效。`2d`

### 4.6 评教 / 请假 / 反馈 / 实践  `P1`
- [A] 评教提交落库、进度统计真实；请假/反馈草稿与历史持久化、附件/截图上传。`2d`
- [A] 实践报名真实跳转/状态。`0.5d`

### 4.7 个人中心 / 设置  `P0`
- [A] 头像选图（`@ohos.file.picker` + 图片裁剪）并保存。`1d`
- [A] **深色模式真正换肤**：把 `ElysiaTheme` 改为响应式/`@ohos.arkui` 资源限定，全局生效（当前开关只存值不换肤）。`2d`
- [A] 字体大小、勿扰、提醒等开关真正作用于 UI/通知。`1d`
- [A] 清除缓存、检查更新接真实逻辑。`0.5d`

### 4.8 管理端 — 学生管理  `P0`
- [A] 学生详情页（缺）、学籍状态操作（休学/复学/毕业）、批量导入导出。`2d`

### 4.9 管理端 — 课程管理  `P0`（当前完全只读）
- [A] 课程**新增/编辑/删除**编辑器 + 仓储写方法 + 本地库；容量/时间冲突校验。`2.5d`

### 4.10 管理端 — 选课管理  `P0`（当前只读）
- [A] 轮次**启动/暂停/结束**、编辑起止时间、冲突明细与人工调整。`2.5d`

### 4.11 管理端 — 成绩管理  `P0`
- [A] 成绩**录入**界面、审核**通过/驳回**（补 `rejectGrade`）、异议处理。`2d`

### 4.12 管理端 — 通知发布  `P1`
- [A] 富文本/附件、定时发布、`receiverScope` 选择器（已修自定义文本，补部门/班级多选）。`1.5d`

### 4.13 管理端 — 评教管理  `P1`
- [A] 问卷模板 CRUD、评教期开启/关闭、评分分布真实数据（补 `EvaluationStats.ratingDistribution` 字段）。`2d`

### 4.14 管理端 — 审批中心  `P0`
- [A] 全流程（多级审批节点真实流转）、撤回、批量审批、附件预览。`2d`

### 4.15 管理端 — 管理员中心 / 权限  `P1`（当前 8 个入口是 toast 占位）
- [A] 角色管理、权限矩阵、操作日志、校历管理、审批流配置、消息模板、安全策略——逐个落地为真实页面。`5d`

### 4.16 横切能力  `P1`
- [A] 列表分页 + 下拉刷新 + 上拉加载统一封装。`1.5d`
- [A] 统一 Toast/对话框/确认封装；表单草稿自动保存。`1d`
- [A] 无障碍（语义标签、对比度）、多设备/折叠屏适配。`2d`
- [A] i18n（中/英）框架。`1.5d`

---

## 5. 数据模型与 API 契约（Track B）

为每个仓储方法定义 REST 端点（节选，完整版随实现补全到 `docs/API.md`）：

| 仓储方法 | Method | Path | 说明 |
| --- | --- | --- | --- |
| `AuthRepository.login` | POST | `/auth/login` | 返回 `{token, refreshToken, user}` |
| `AuthRepository.adminLogin` | POST | `/auth/admin/login` | 含图形验证码校验 |
| `CourseRepository.getSchedule` | GET | `/schedule?term&week` | 课表 |
| `CourseRepository.getSelectionCourses` | GET | `/selection/courses?q&category` | 可选课 |
| `CourseRepository.selectCourse/dropCourse` | POST/DELETE | `/selection/{courseId}` | 选/退（事务） |
| `AcademicRepository.getGrades` | GET | `/grades?term` | 成绩 |
| `EvaluationRepository.submit` | POST | `/evaluations/{taskId}` | 提交问卷 |
| `AdminRepository.approve/reject` | POST | `/approvals/{id}/(approve\|reject)` | 审批 |
| `AdminRepository.publishNotice` | POST | `/notices` | 发布通知 |
| … | … | … | 其余按模块补全 |

- 统一响应：`ApiResponse<T>`（已存在）；分页：`PageMeta`（已存在）；错误码表见 `HttpError.kind`。
- 数据库实体（PostgreSQL，约 14 张表）：`users/admins, courses, schedule, selections, grades, exams, student_records, notices, notice_reads, evaluations(+templates+answers), leaves, feedback, approvals(+flow), roles_permissions`。

---

## 6. 质量工程  `P0`

- **单元测试**（`entry/src/test`，用已装的 `hypium`）：`ValidatorUtils`、`DateUtils`、`TermUtils`、各 `Repository`（用 `hamock`）。目标 ≥80%。`3d`
- **组件/页面测试 + E2E**（`entry/src/ohosTest`，`@ohos.UiTest`）：登录→选课→评教、管理端审批等关键流。`3d`
- **可观测**：统一日志（`@ohos.hilog`）、错误上报、关键埋点。`1d`
- **性能**：长列表 `LazyForEach`、图片按尺寸加载、首屏预取。`2d`
- **安全**：token 加密存储、输入校验全覆盖（已有 `ValidatorUtils`）、HTTPS/证书校验、最小权限。`1.5d`

---

## 7. 交付与运维  `P0`

- **签名配置**：生成证书/profile，在 `build-profile.json5` 配 `signingConfigs`，消除 `skip sign`，产出 release HAP。`1d`
- **Lint 门禁**：接 `code-linter.json5` 到提交/CI。`0.5d`
- **CI/CD**：流水线跑 lint→build→test→出包（GitHub Actions / Gitee Go）。`1.5d`
- **文档**：`docs/API.md`、`CHANGELOG.md`、发布说明。`1d`

---

## 8. 路线图（里程碑）

| 里程碑 | 目标 | 主要范围 | 估时 |
| --- | --- | --- | --- |
| **M1 地基** | 真实数据闭环（仍可单机） | 4.1 会话/鉴权、仓储→本地库可写、4.7 换肤、测试脚手架、签名 | ~1.5 周 |
| **M2 学生端完备** | 学生侧全部功能真实生效 | 4.2–4.6 全部 `[A]`、文件/头像、分页刷新 | ~2 周 |
| **M3 管理端完备** | 管理端 CRUD 与流程闭环 | 4.8–4.15（课程/选课/成绩/审批/权限） | ~2.5 周 |
| **M4 质量与发布** | 可交付成品（Track A 完成） | 测试达标、性能、无障碍、CI/CD、release 包 | ~1.5 周 |
| **M5 全栈（可选）** | 接真实后端 | 后端服务、`useMock=false`、DTO 映射、联调 | ~3 周 |

> Track A（M1–M4）合计约 **7.5 周**（1～2 人）；Track B 再加 ~3 周。

---

## 9. 可执行任务清单（首个冲刺 Sprint-1，建议立即做的 P0）

| # | 任务 | 模块 | 估时 | 验收 |
| --- | --- | --- | --- | --- |
| 1 | 引入可写本地仓储（RDB 或内存+preferences 持久化），选退课/申请/审批落盘 | 仓储 | 2d | 重启后数据保留 |
| 2 | 会话恢复拉 profile + 401 自动跳登录 | 认证 | 1d | 冷启动资料正常、token 失效跳登录 |
| 3 | 深色模式全局真正换肤 | 设置 | 2d | 开关后全页变深色 |
| 4 | 管理端课程 CRUD（编辑器 + 写仓储） | 管理端 | 2.5d | 可新增/改/删并持久化 |
| 5 | 成绩录入 + 审核通过/驳回 | 管理端 | 2d | 状态流转正确 |
| 6 | 头像选图 + 文件下载 | 个人/首页 | 2d | 真实选图/下载成功 |
| 7 | 测试脚手架 + 核心 util/repo 单测到 60%+ | 质量 | 2d | `hypium` 跑通、覆盖率报告 |
| 8 | 签名配置 + 出 release 包 | 交付 | 1d | 生成可安装 HAP |
| 9 | 🔴 学生登录页补"管理员登录"入口；AdminLogin 补"返回学生登录" | 认证 | 0.5d | 首屏可切换并用管理员账号进入仪表盘 |

---

## 10. 风险与依赖

- **后端不存在**（Track B 最大风险）：建议先全力 Track A，用本地库把"真实数据闭环"做实，后端就绪后仅切 `useMock=false` + 映射层。
- **签名证书**：需华为开发者账号/证书；无证书时先用 debug 签名出包。
- **设备/模拟器**：可视化验证需真机或模拟器（本机用 `DEVECO_SDK_HOME` + `hvigorw assembleHap` 已跑通）。
- **工时**：以上为 1～2 人估算，团队人数变化按比例调整。

---

## 11. 建议的下一步

1. 确认口径：**先做 Track A 到 M4 成品**（推荐），还是同时启动 Track B 后端。
2. 批准 **Sprint-1（第 9 节）**，我可以从"任务 1：可写本地仓储 + 持久化"开始落地，沿用现有分层与 ArkTS 规范（见 README 技术架构）。

## 12. 页面"摆设"盘点与逐页完善计划

> 「摆设」= 界面上**看得见但没有真实行为**的元素：点了只弹"建设中"、开关拨了 UI/系统无变化、图表/数字写死、页面叫"管理"却不能增删改、上传/下载/换头像/搜索只是装饰。
> 说明：本节只列**已接线之后仍然是摆设**的部分；"数据是 mock、写操作不落盘"属另一类问题，见 §1/§4，不在此重复。估时与 §4 同源（同一份工作的"逐页视角"，不额外累加）。

### 12.1 摆设的五种类型（横切）

- **A 静态图表/统计**：写死或纯展示，不随真实数据变化。
- **B 占位入口**：点击只 `promptAction.showToast('该功能正在建设中')`，无目标页面。
- **C 空转开关**：`PreferenceStorage` 存了值，但 UI/系统**无任何变化**（最典型：夜间模式不换肤）。
- **D 只读"管理"页**：页面定位是管理，却没有新增/编辑/删除/状态流转入口。
- **E 假交互**：搜索框、文件上传/下载、换头像、学籍照片等是占位装饰。

### 12.2 逐页摆设清单

#### 学生端

| 页面 | 仍是"摆设"的元素 | 完善方案 | 优先级 | 估时 |
| --- | --- | --- | --- | --- |
| HomePage | 顶部**搜索框**输入无效（`query` 未使用）；文件卡"**下载**"图标无 onClick | 搜索→结果页/过滤；下载接 `@ohos.request`（见 §4.2） | P1 | 1.5d |
| MinePage | 部分**统计卡**（GPA/学分/待评教）无真实来源；`办事大厅`/`关于`→toast；夜间模式开关不换肤 | 统计接 `AcademicRepository.getGradeSummary` 等；入口实现或移除；换肤见 12.3 | P1 | 1d |
| AccountPage | "**更换头像**"只是跳转编辑页，非真实换图 | 接图片选择+裁剪+保存（见 §4.7） | P1 | 0.5d |
| RosterPage | 学籍**照片**为 `PHOTO` 占位 | 渲染 `StudentRecord.photoUrl`，缺省占位 | P2 | 0.5d |
| NoticeDetailPage | 附件"**下载**"→toast，非真实下载 | 统一 FileService 下载（见 12.3） | P1 | 0.5d |
| LeavePage / FeedbackPage | **附件/截图上传**为装饰 | 接 `@ohos.file.picker` 上传（见 §4.6） | P1 | 1d |
| SettingsPage | `主题`/`字体大小`/`用户协议`/`隐私政策`/`关于`→toast；夜间/字体/勿扰/各提醒/生物识别开关**存值不生效** | 协议/隐私/关于做真实详情页；开关接真实作用（见 12.3） | P1 | 2d |

> 说明：TodayPage / SchedulePage / SelectionPage / GradesPage / ExamPage / NoticesPage / EvalPage / EditInfoPage / 认证四页已**真实可用**（仅数据为 mock）；**但学生 LoginPage 缺少跳转"管理员登录"的入口，导致整个管理端不可达——见 §4.1 最高优先 P0。**

#### 管理端

| 页面 | 仍是"摆设"的元素 | 完善方案 | 优先级 | 估时 |
| --- | --- | --- | --- | --- |
| AdminCoursesPage | **只读**：课程无新增/编辑/删除 | 编辑器 + 写仓储（见 §4.9） | P0 | 2.5d |
| AdminSelectionPage | **只读**：轮次无启动/暂停/结束、冲突无处理 | 轮次操作 + 冲突明细（见 §4.10） | P0 | 2.5d |
| AdminGradesPage | 仅"通过"，**无录入/驳回** | 录入界面 + `rejectGrade`（见 §4.11） | P0 | 2d |
| AdminStudentsPage | 行**不可点**、无学生详情、无学籍操作 | 详情页 + 学籍状态操作（见 §4.8） | P1 | 2d |
| AdminEvalPage | **评分分布图写死**(42/35/15/5/3)；模板开关仅内存、无持久化/CRUD；无评教期开关 | 补 `ratingDistribution` 数据字段；模板 CRUD + 落盘；开/闭期按钮（见 §4.13） | P1 | 2d |
| AdminProfilePage | **8 个系统管理入口**(角色/权限/日志/校历/审批流/消息模板/安全策略)→toast；`修改密码`/`关于`→toast；夜间/推送开关空转 | 逐个落地真实页面（见 §4.15）；或精简掉不做的入口 | P1 | 5d |
| AdminNoticePage | 富文本/附件/定时发布缺（基本发布已可用） | 富文本+附件+定时（见 §4.12） | P2 | 1.5d |
| AdminDashboardPage | 统计卡/趋势/分布为 mock（展示型，正常）；图表组件为内联绘制 | 抽通用图表组件吃真实数据（见 12.3） | P2 | 1d |

> AdminApprovalsPage 审批通过/驳回/详情/深链已可用；多级流程节点目前为展示，全流程流转见 §4.14。

### 12.3 横切摆设的统一完善方案

- **夜间模式真正换肤（C 类，最该先做）**：当前 `ElysiaTheme` 是硬编码常量，开关只存值。方案：将颜色迁到**资源限定目录**（`resources/dark/element/color.json` 已存在）或改为响应式主题对象 + 顶层 `@Provide/@Consume` 注入，使全站随开关切换。`2d`
- **字体大小**：定义全局缩放因子 token，文本尺寸统一乘以因子。`0.5d`
- **图表组件化（A 类）**：抽 `BarChart`/`RingChart` 通用组件，参数化数据；Dashboard 趋势/分布、Eval 评分分布共用；Eval 需先补 `EvaluationStats.ratingDistribution` 数据字段。`1.5d`
- **占位入口（B 类）**：每个"建设中"入口二选一——**实现真实页面**（并入 §4.15/§4.7）或**从 UI 移除**，避免误导用户。
- **文件能力（E 类）**：统一 `common/services/FileService`（选图、裁剪、上传、下载、打开），供头像/附件/截图/文件卡复用。`1.5d`

### 12.4 优先级建议

1. **P0（误导性最强：页面叫"管理"却动不了）**：AdminCourses / AdminSelection / AdminGrades 的增删改与流程 → 见 §9 Sprint-1。
2. **P1（开关空转 + 假交互 + 占位入口）**：夜间换肤、文件/头像能力、Settings/AdminProfile 入口落地。
3. **P2（锦上添花）**：图表组件化、首页搜索增强、富文本通知。

### 12.5 与里程碑对齐

- 12.2「管理端只读页」P0 项 → 归入 **M3 管理端完备**（并已进 §9 Sprint-1 任务 4/5）。
- 12.3「换肤/文件/图表」+ 学生端 P1 → 归入 **M2 学生端完备**。
- 占位入口逐页落地 → 归入 **M3**，或按课程范围**精简移除**。

> 维护：每完成一项更新本文件勾选与里程碑进度；重大接口变更同步 `docs/API.md`。
