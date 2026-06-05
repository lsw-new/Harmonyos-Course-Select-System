# 教学管理系统 HarmonyOS App

## 项目介绍

本项目是“绷住了小组”的软件工程课程作业，目标是实现一个面向 HarmonyOS NEXT 的教学管理系统 App。

系统围绕学生端与管理端两类角色设计，覆盖登录注册、首页工作台、课程课表、选课中心、成绩考试、评教反馈、请假实践、学生管理、课程管理、成绩管理、通知发布和审批管理等教学管理核心场景。

## 项目定位

- **项目名称**：教学管理系统 HarmonyOS App
- **目标平台**：HarmonyOS NEXT
- **项目类型**：软件工程课程作业
- **设计风格**：Elysia 玫瑰学院风
- **视觉主题**：玫瑰粉 `#F2709C`、奶油白 `#FFFDFB`、浅紫 `#B589FF`、金色 `#D9B675`

## 软件架构

当前仓库为 HarmonyOS 工程结构，主要目录如下：

```text
.
├── AppScope/                 # 应用级配置与资源
├── entry/                    # HarmonyOS 主模块
│   ├── src/main/ets/         # 页面与 Ability 代码
│   ├── src/main/resources/   # 应用资源
│   ├── src/ohosTest/         # OHOS 测试
│   └── src/test/             # 本地单元测试
├── hvigor/                   # Hvigor 构建配置
├── server/                   # Track B 远程后端 API（Node + Express + pg）+ Jest 测试套件
├── docs/                     # 文档与实机运行截图（docs/screenshots/）
├── build-profile.json5       # 工程构建配置
├── hvigorfile.ts             # Hvigor 入口配置
└── oh-package.json5          # OpenHarmony 包配置
```

## 技术架构

应用采用分层架构，UI 与数据解耦，支持**本地优先 + 可选远程后端**双模式：

- **本地模式（默认，`AppConfig.useRemote = false`）**：数据来自本地 mock + Preferences 持久化 + 本地 RDB（RelationalStore，courses / selections 表），可完全离线演示；
- **远程模式（`AppConfig.useRemote = true`）**：认证 / 选课 / 成绩 / 通知 / 请假 / 反馈 / 评教 / 实践及管理端各域改走 **Track B 后端**（`AppConfig.baseUrl = https://lsw666.duckdns.org/api`，经 nginx 反代 + Let's Encrypt 的 **HTTPS**），读失败回退本地、写失败显式报错。

> 邮箱验证码（注册 / 找回密码）始终联网走后端真实发送，不受 `useRemote` 开关影响。详见下文「后端服务（Track B）」与「安全与鉴权」。

```text
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets              # UIAbility 入口：建窗口、监听断点写 AppStorage、AppStartup.init() 后 loadContent('pages/Index')
├── entrybackupability/
│   └── EntryBackupAbility.ets        # 系统数据备份/恢复能力骨架（onBackup / onRestore）
├── app/                              # 应用编排
│   ├── AppConfig.ets                 # 运行配置：useRemote 远程开关 / baseUrl（默认本地 mock）
│   ├── AppRoute.ets                  # Navigation 系统路由表门面：go/back/clearTo/getParam + 角色 & 细粒度权限守卫
│   └── AppStartup.ets                # 启动注入：初始化本地 RDB / Preferences、恢复会话、安全 token 对齐
├── models/                           # 领域模型（纯 interface / type，无逻辑）
│   ├── User.ets                      # 学生资料、登录/注册/改密请求、账号信息
│   ├── Course.ets                    # 课程、课表项、选课课程、选课轮次
│   ├── Academic.ets                  # 成绩、考试、学籍
│   ├── Notice.ets                    # 通知
│   ├── Evaluation.ets                # 评教任务 / 问卷
│   ├── Home.ets                      # 首页摘要、教学周
│   ├── Misc.ets                      # 请假、反馈、实践等杂项
│   ├── Common.ets                    # 通用枚举 / 分页 / 响应等共享类型
│   ├── Admin.ets                     # 管理员资料、权限、审批、成绩审核
│   ├── PracticeModels.ets            # 实践项目 / 报名
│   ├── SelectionAdminModels.ets      # 管理端选课统计
│   ├── StudentDetailModels.ets       # 管理端学生详情
│   ├── EvalAdminModels.ets           # 管理端评教模板 / 统计
│   ├── AccessControlModels.ets       # 角色权限矩阵、审计日志
│   └── SysConfigModels.ets           # 系统配置项
├── repositories/                     # 仓储层（单例，统一返回 Promise；远程开启走 RemoteApi、失败回退本地）
│   ├── BaseRepository.ets            # 基类：delay / delayCopy / reject + scopedKey 用户数据隔离辅助
│   ├── AuthRepository.ets            # 登录 / 注册 / 找回密码 / 改密 / 登出 + 管理员登录
│   ├── ProfileRepository.ets         # 个人资料、首页摘要、请假 / 反馈 / 实践
│   ├── CourseRepository.ets          # 课表、选课中心、选课/退课事务、课程详情、课表导入合并
│   ├── AcademicRepository.ets        # 成绩、考试
│   ├── EvaluationRepository.ets      # 学生评教
│   ├── PracticeRepository.ets        # 实践项目 / 报名
│   ├── AdminRepository.ets           # 管理端：课程、审批、成绩审核、通知发布
│   ├── StudentAdminRepository.ets    # 管理端学生管理（学籍操作）
│   ├── SelectionAdminRepository.ets  # 管理端选课轮次 / 统计
│   ├── AccessControlRepository.ets   # 角色权限、审计日志
│   ├── EvalAdminRepository.ets       # 管理端评教模板 CRUD
│   └── SysConfigRepository.ets       # 系统配置
├── mock/                             # 各域 mock 数据（本地模式数据源，含测试账号凭据）
│   ├── mockUser.ets                  # 学生资料 + 测试学生账号
│   ├── mockAdmin.ets                 # 管理员资料 + 权限矩阵 + 测试管理员账号
│   ├── mockHome.ets                  # 首页摘要、今日课程
│   ├── mockCourses.ets               # 课程目录 / 课表
│   ├── mockAcademic.ets              # 成绩、考试、学籍
│   ├── mockNotices.ets               # 通知
│   ├── mockEvaluations.ets           # 学生评教任务
│   ├── mockPractice.ets              # 实践项目
│   ├── mockMisc.ets                  # 请假、反馈
│   ├── mockSelectionAdmin.ets        # 管理端选课统计
│   ├── mockStudentDetail.ets         # 管理端学生详情
│   ├── mockEvalAdmin.ets             # 管理端评教模板 / 统计
│   ├── mockAccessControl.ets         # 角色权限、审计日志
│   └── mockSysConfig.ets             # 系统配置
├── common/
│   ├── http/
│   │   ├── HttpClient.ets            # 封装 @ohos.net.http（GET/POST/PUT/DELETE + 超时）
│   │   ├── ApiClient.ets             # 拆 ApiResponse 信封 + 附带 Bearer token
│   │   └── HttpError.ets             # 带状态码的 HTTP 错误类型
│   ├── remote/
│   │   └── RemoteApi.ets             # Track B 后端各端点封装（认证 / 选课 / 成绩 / 通知 / … / 管理端）
│   ├── security/
│   │   ├── AssetTokenStore.ets       # Asset Store Kit 安全存储 token（不可用时降级进程内存）
│   │   └── AuthorizationService.ets  # 管理端细粒度权限判定（hasAdminPermission(code, action)）
│   ├── services/
│   │   ├── ScheduleImportService.ets # xlsx 课表解析 + 导入管线
│   │   ├── NoticeStore.ets           # 通知已读状态本地存储
│   │   └── FileService.ets           # 文件下载 / 附件（mock 路径 + 文件名安全校验）
│   ├── storage/
│   │   ├── PreferenceStorage.ets     # Preferences 键值封装
│   │   ├── SessionStorage.ets        # 会话：token / 角色 / profile（token 仅走安全存储）
│   │   ├── AccountStore.ets          # 账号密码本地持久层（bcrypt + 旧 SHA 双轨兜底）
│   │   ├── LocalDataStore.ets        # 通用本地数组持久化（Preferences 封装）
│   │   ├── AppDatabase.ets           # 本地 RDB（RelationalStore）封装
│   │   └── DatabaseSchema.ets        # 本地 RDB 建表 SQL + 版本
│   ├── utils/
│   │   ├── DateUtils.ets             # 日期格式化
│   │   ├── TermUtils.ets             # 学期 / 教学周推算
│   │   └── ValidatorUtils.ets        # 学号 / 邮箱 / 密码等输入校验
│   ├── widgets/
│   │   ├── AppIcon.ets               # 图标组件（基于 ic_*.svg 媒体注册表）
│   │   ├── TabBars.ets               # 学生 / 管理端底部导航
│   │   ├── StateViews.ets            # LoadingState / EmptyState / ErrorState
│   │   ├── Skeleton.ets              # 骨架屏（SkeletonList / Card / Block）
│   │   ├── Feedback.ets              # Toast 封装（替代已废弃 promptAction）
│   │   ├── Breakpoint.ets            # 断点自适应 BreakpointManager
│   │   ├── DataSource.ets            # ArrayDataSource（LazyForEach 长列表虚拟化）
│   │   ├── SafeArea.ets              # 安全区避让 SafeTop / SafeBottom
│   │   └── RouteLoadingOverlay.ets   # 路由加载遮罩（现 no-op，加载态交各页 Skeleton）
│   ├── constants/
│   │   ├── Colors.ets                # 颜色 token
│   │   ├── Dimensions.ets            # 尺寸 / 间距 / 圆角 token
│   │   └── TextStyles.ets            # 文字样式 token
│   ├── Components.ets                # 通用组件库（TopBar / 卡片 / 按钮 / 输入框 / Pill / Divider …）
│   └── Theme.ets                     # 主题聚合与玫瑰学院风设计 token
└── pages/                            # 59 个页面（逐页角色见下方「完整页面清单」表）
    ├── Index.ets                     # 唯一 @Entry：托管 Navigation(AppRoute.stack)，按会话 push 初始路由
    ├── 〔认证〕LoginPage(学生登录)·RegisterPage(注册)·ForgotPage(忘记密码)·AdminLoginPage(管理员登录)
    ├── 〔学生·首页/通知〕HomePage(首页工作台)·TodayPage(今日课程)·NoticesPage(通知列表)·NoticeDetailPage(通知详情)·MessageCenterPage(消息中心)
    ├── 〔学生·课程/选课〕SchedulePage(我的课表)·CourseDetailPage(课程详情)·SelectionPage(选课中心)·SelectionConfirmPage(选课确认)·SelectionResultPage(选课结果)
    ├── 〔学生·学业〕GradesPage(成绩查询)·GradeDetailPage(成绩详情)·GradeAppealPage(成绩申诉)·ExamPage(考试安排)·ExamDetailPage(考试详情)·RosterPage(学籍信息)
    ├── 〔学生·评教/杂项〕EvalPage(评教)·LeavePage(请假)·LeaveDetailPage(请假详情)·FeedbackPage(反馈)·FeedbackDetailPage(反馈详情)·PracticePage(实践公服)·PracticeDetailPage(实践详情)·PracticeSignupPage(实践报名)·MyPracticePage(我的实践)·ServiceHallPage(服务大厅)
    ├── 〔学生·个人中心〕MinePage(我的)·AccountPage(我的账户)·EditInfoPage(修改资料)·PasswordPage(修改密码)·SettingsPage(设置)·AboutPage(关于)
    ├── 〔管理端·主〕AdminDashboardPage(仪表盘)·AdminStudentsPage(学生管理)·AdminStudentDetailPage(学生详情)·AdminCoursesPage(课程管理)·AdminCourseDetailPage(课程详情)·AdminSelectionPage(选课管理)·AdminGradesPage(成绩管理)·AdminNoticePage(通知发布)·AdminEvalPage(评教管理)·AdminApprovalsPage(审批中心)·AdminApprovalDetailPage(审批详情)
    ├── 〔管理端·配置〕AdminCalendarPage(教学日历)·AdminRolePermPage(角色权限)·AdminAuditLogPage(审计日志)·AuditLogDetailPage(日志详情)·AdminSysConfigPage(系统配置)·AdminProfilePage(管理员中心)·AdminPasswordPage(管理员改密)
    └── 〔通用/工具页〕AttachmentPreviewPage(附件预览)·ImportResultPage(导入结果)·NoPermissionPage(无权限)·DocPage(协议/隐私文档)
```

> **导航**：已从已废弃的 Page Router 迁移到 **Navigation + NavPathStack（系统路由表懒加载）**；`pages/Index.ets` 为唯一 `@Entry` 根容器，其余页面经 `route_map.json` 注册、由 `AppRoute` 门面统一驱动。
> **国际化**：UI 静态中文文案已外置到 `resources/base/element/string.json`（约 534 条），代码经 `$r(...)` 引用。

**数据流**：`页面 (@Component)` → `XxxRepository.get().method()` → `本地 mock / RDB / Preferences`，或开启远程后经 `RemoteApi` → `Track B 后端`（读失败回退本地）。

**工程约定**：

- 页面在 `aboutToAppear()` 经仓储加载数据，并用 `LoadingState / ErrorState / EmptyState` 处理加载 / 失败 / 空态；
- 导航统一走 `AppRoute.go / back / clearTo / getParam`（内部为 `NavPathStack` 系统路由表门面），内置按**角色（学生 / 管理员）+ 管理端细粒度权限**的守卫，不直接使用 `router`；
- 登录经 `AuthRepository` 校验 → `SessionStorage` 写入会话 → `AppRoute.clearTo` 进入主页；退出登录清理会话并返回登录页；
- 图标统一使用 `AppIcon`（基于 `ic_*.svg` 媒体注册表），不使用 emoji 占位。

## 功能模块

### 学生端

> 默认本地模式为 mock + 本地持久化原型；课程目录与选课关系落本地 RDB（courses / selections 表）。开启 `useRemote` 后，认证 / 选课 / 成绩 / 通知 / 请假 / 反馈 / 评教 / 实践改走 Track B 后端真实数据。

- 用户认证：登录、注册、忘记密码
- 首页工作台：教学周信息、快捷入口、今日课程、通知摘要
- 课程模块：我的课表、课程详情、选课中心（含选课事务校验：轮次、容量、学分上限、时间冲突）
- 学业信息：成绩查询、考试安排、学籍信息（mock 数据展示）
- 评教与杂项：评教问卷、请假申请、意见反馈、实践公服（mock 演示）
- 个人中心：个人信息、账户安全、资料修改、密码修改、系统设置

### 管理端

> 默认本地模式数据存于本地 RDB / Preferences；开启 `useRemote` 后，学生管理 / 成绩审核 / 审批 / 通知发布 / 角色权限 / 评教模板 / 审计日志等改走 Track B 后端，并受后端**细粒度权限**校验。

- 管理员认证：工号密码登录、图形验证码（任意 4 位即可）
- 管理仪表盘：统计卡片、选课趋势、课程类型分布（mock 数据）
- 学生管理：学生列表、搜索筛选、学籍操作（mock 数据）
- 课程管理：课程新增、编辑、删除（落本地 RDB courses 表）
- 选课管理：选课数据统计、人工调整（落本地 RDB selections 表）
- 成绩管理：成绩录入、成绩审核（mock 演示）
- 通知发布：通知编辑、发布范围选择（mock 演示）
- 审批管理：审批中心、审批详情、通过与驳回操作（mock 演示）

## 后端服务（Track B）

`server/` 目录为 App 的远程后端 API，仅在 `AppConfig.useRemote = true` 时被调用。

- **技术栈**：Node.js 18 + Express + `pg`（CommonJS 免构建），直连 Postgres（`dtest2` schema），统一返回 `ApiResponse` 信封 `{ success, data, error }`。
- **部署**：服务器 `138.2.47.185`，pm2 进程 `dtest2-api` 监听 `:8090`；前置 **nginx 反向代理**终止 TLS（Let's Encrypt 证书），对外为 `https://lsw666.duckdns.org/api`。
- **覆盖域**：认证（登录 / 注册 / 找回密码 / 邮箱验证码）、课程、选课（事务校验）、成绩、通知、请假、反馈、评教、实践，以及管理端的学生管理、成绩审核、审批、通知发布、角色权限、评教模板、审计日志。
- **数据库迁移**：`server/migrations/` 权威建表脚本 + `npm run migrate` 幂等 runner。

详见 [`server/README.md`](server/README.md)（端点与部署）与 [`server/deploy/nginx-https-setup.md`](server/deploy/nginx-https-setup.md)（HTTPS 反代配置）。

## 安全与鉴权

经一轮全项目安全审计加固，主要措施：

- **身份从 JWT 派生**：学生端接口一律以 `token.sub` 作为当前学号，不接受客户端传入 `studentId`，杜绝水平越权（IDOR）。
- **管理端细粒度鉴权**：后端 `permissionRequired(code:action)` 中间件按 `admin_profiles.role_id → role_permissions` 校验权限（权限只读数据库、不写 token）；前端 dashboard 入口与路由守卫同步按权限收敛。
- **密码哈希 bcrypt**：新口令 bcrypt，旧 SHA-256 账号登录成功后惰性升级；存量账号不中断。
- **JWT 强制密钥**：缺失或过短的 `JWT_SECRET` 拒绝启动（移除弱默认）。
- **限流与 CORS**：内存级限流（全局 / 登录与验证码分级，超限 429）；CORS 默认关闭跨域。
- **本地数据隔离**：实践 / 评教 / 反馈 / 课表等本地缓存按用户 `scopedKey` 隔离，换账号不串数据；**会话 token 仅存 Asset 安全存储，不再明文写入 Preferences**（旧版明文一次性迁移后清除）。
- **个人资料同源**：登录后首页 / 我的 / 编辑资料优先读会话真实 profile（远程登录下发），未登录才回退本地 mock，避免真实账号被显示或覆盖为 mock 资料。
- **选课规则后端兜底 + 并发安全**：选课的学分上限与时间冲突由后端在事务内权威校验（前端提示仅作辅助）；选课 / 实践报名对课程 / 项目行加 `SELECT … FOR UPDATE` 行锁，杜绝「先 count 再 insert」竞态导致的超容量 / 超名额。
- **账号闭环**：注册真正落库（账号 + 学生资料）、找回密码校验账号存在且邮箱匹配（不再自动建号）、远程登录返回真实 profile（管理员含真实权限矩阵）。

## 测试

后端 API 配套 **Jest + supertest** 自动化测试套件（`server/test/`）：

- **108 个用例 / 11 个套件**，覆盖登录与鉴权中间件、越权（IDOR）防护、管理端细粒度权限、限流、选课事务（轮次 / 容量 / 学分上限 / 时间冲突 + `FOR UPDATE` 行锁 + 失败回滚）、实践报名、注册与找回密码闭环、各读写端点，以及选课规则纯函数。
- **并发压力测试**：有状态 mock 忠实复刻 `FOR UPDATE` 行锁对临界区的序列化，跑真正的 `Promise.all` 并发——20 人同抢 1/5 个名额恰好 1/5 人成功、落库数不超容量；另设「去锁对照」证明该断言非恒真（锁缺失即超卖）。
- **行覆盖率 80.9%**（语句 79.9% / 函数 80.2%）；数据库连接池与 SMTP 等基础设施按约定排除统计。
- 持久层经 mock 注入，无需真实数据库即可运行：`cd server && npm test`（或 `npm run test:coverage`）。
- **CI**：[`.github/workflows/backend-tests.yml`](.github/workflows/backend-tests.yml) 在 push / PR 时于 Node 18 / 20 跑 `npm ci` → JS 语法检查 → 带**覆盖率门禁**（行 ≥ 80%）的测试（仓库托管 Gitee，镜像到 GitHub 即自动运行）。

> 前端 ArkTS 页面另有 hypium 单元测试（`entry/src/ohosTest/`、`entry/src/test/`），需在 DevEco Studio + 模拟器 / 真机内运行，不纳入无头 CI。

## UI 实机运行截图

> 以下为 **HarmonyOS 模拟器实机运行截图**（UI 验证轮采集，位于 [`docs/screenshots/`](docs/screenshots)）。设计风格：Elysia 玫瑰学院风 · 玫瑰粉 `#F2709C` / 奶油白 `#FFFDFB` / 浅紫 `#B589FF` / 金色 `#D9B675`。

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/01-login.jpeg" alt="学生登录" width="210" /><br/><sub>学生登录</sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/02-home.jpeg" alt="首页工作台" width="210" /><br/><sub>首页工作台</sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/03-schedule.jpeg" alt="我的课表" width="210" /><br/><sub>我的课表</sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/04-selection.jpeg" alt="选课中心" width="210" /><br/><sub>选课中心</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/05-notices.jpeg" alt="通知列表" width="210" /><br/><sub>通知列表</sub></td>
    <td align="center"><img src="docs/screenshots/06-notice-detail.jpeg" alt="通知详情" width="210" /><br/><sub>通知详情</sub></td>
    <td align="center"><img src="docs/screenshots/07-practice.jpeg" alt="实践公服" width="210" /><br/><sub>实践公服</sub></td>
    <td align="center"><img src="docs/screenshots/08-practice-detail.jpeg" alt="实践详情" width="210" /><br/><sub>实践详情</sub></td>
  </tr>
</table>

> 上图为学生端核心流程（登录 → 首页 → 课表 / 选课 → 通知 → 实践）的实机截图；管理端与其余页面见下方「页面分组说明」与「完整页面清单」。

## 页面分组说明

文档版本：V1.1  
设计风格：Elysia 玫瑰学院风  
目标平台：HarmonyOS NEXT  
色彩主题：玫瑰粉 `#F2709C` · 奶油白 `#FFFDFB` · 浅紫 `#B589FF` · 金色 `#D9B675`

### 一、认证页面

学生端与管理端均采用玫瑰学院风视觉语言。学生端使用学号密码登录，管理端增加图形验证码。

**包含页面：**

- 学生登录 LoginScreen：品牌 Logo + 欢迎语 + 学号/密码输入 + 登录按钮（玫瑰渐变胶囊）
- 注册 RegisterScreen：新用户注册表单
- 忘记密码 ForgotScreen：密码找回流程

### 二、学生端首页

首页以教学周卡片、快捷入口网格、今日课程列表和通知摘要组织高频信息。

**包含页面：**

- 首页工作台 HomeScreen：欢迎区 + Hero 教学周卡片 + 快捷入口 + 今日课程 + 通知摘要
- 今日课程 TodayScreen：时间线形式展示当天全部课程
- 通知列表 NotificationsScreen：分类标签 + 通知卡片列表
- 通知详情 NoticeDetailScreen：通知正文展示

### 三、课程模块

课表以周视图呈现，选课中心支持分类筛选与搜索。

**包含页面：**

- 我的课表 ScheduleScreen：周视图课程表，颜色区分课程类型
- 课程详情 CourseDetailScreen：课程信息 + 教师 + 学分 + 考核方式
- 选课中心 SelectionScreen：分类筛选 + 课程卡片 + 选课操作

### 四、学业信息

成绩查询、考试安排与学籍信息集中展示。

**包含页面：**

- 成绩查询 GradesScreen：学期筛选 + 课程成绩列表 + GPA 统计
- 考试安排 ExamScreen：考试时间线 + 考场信息
- 学籍信息 RosterScreen：个人学籍档案展示

### 五、评教与杂项功能

评教、请假、反馈、实践等辅助功能。

**包含页面：**

- 评教列表 EvalListScreen：待评教课程列表
- 评教问卷 EvalFormScreen：评分滑块 + 文字评价
- 请假申请 LeaveScreen：请假类型 + 时间选择 + 原因填写
- 意见反馈 FeedbackScreen：反馈类型 + 内容输入
- 实践公服 PracticeScreen：实践活动列表与报名

### 六、个人中心

个人信息管理、账户安全与应用设置。

**包含页面：**

- 我的 MineScreen：头像 + 基本信息 + 功能入口列表
- 我的账户 AccountScreen：账户详细信息
- 修改资料 EditInfoScreen：个人信息编辑表单
- 修改密码 PasswordScreen：旧密码验证 + 新密码设置
- 设置 SettingsScreen：主题切换 + 通知开关 + 关于

### 七、管理端 — 登录与仪表盘

管理端保留同一套玫瑰主题，信息密度更高，突出统计数据、图表和审批操作。

**包含页面：**

- 管理员登录 AdminLogin：`ADMIN · 教务` 标识 + 工号/密码 + 图形验证码
- 管理仪表盘 AdminDashboard：四宫格统计卡 + 选课趋势图 + 课程类型分布
- 学生管理 AdminStudents：学生列表 + 搜索筛选 + 学籍操作

### 八、管理端 — 课程与成绩管理

课程、选课、成绩、通知的集中管理。

**包含页面：**

- 课程管理 AdminCourses：课程列表 + 新增/编辑/删除
- 选课管理 AdminSelection：选课数据统计 + 人工调整
- 成绩管理 AdminGrades：批量录入 + 成绩审核
- 通知发布 AdminNotice：通知编辑器 + 发布范围选择

### 九、管理端 — 评教与审批

评教数据管理与审批流程处理。

**包含页面：**

- 评教管理 AdminEval：评教数据汇总 + 统计分析
- 审批中心 AdminApprovals：待审批/已通过/已驳回/已撤回筛选 + 审批卡片列表
- 审批详情 AdminApprovalDetail：申请详情 + 审批操作（通过/驳回）
- 管理员中心 AdminProfile：管理员个人信息与系统设置

## 设计 Token 速查

### 色彩

| 名称 | 色值 | 用途 |
| --- | --- | --- |
| rose-500 | `#F2709C` | 主按钮、激活态、重点文字 |
| rose-700 | `#A93C68` | 标题、强调 |
| rose-100 | `#FFE9F1` | 卡片背景、标签底色 |
| cream-50 | `#FFFBF6` | 页面主背景 |
| surface | `#FFFDFB` | 卡片、输入框 |
| lav-500 | `#B589FF` | 辅助渐变、选修标识 |
| gold-500 | `#D9B675` | 高分、公选标识 |
| ink | `#4B2A38` | 正文主文字 |
| ink-soft | `#7A5266` | 说明文字 |
| ink-mute | `#B294A4` | 时间、辅助 |

### 圆角

| 组件 | 圆角值 |
| --- | --- |
| 手机壳 | 36px |
| Hero 卡片 | 24px |
| 普通卡片 | 18px |
| 输入框 | 14px |
| 按钮 | 999px（胶囊） |
| 快捷入口图标 | 12-15px |
| 标签 | 999px（胶囊） |

### 底部导航

| 角色 | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Tab 5 |
| --- | --- | --- | --- | --- | --- |
| 学生端 | Home 首页 | Mine 我的 | Eval 评教 | Practice 实践 | Public 公共 |
| 管理端 | Tableau 仪表 | Students 学生 | Cours 课程 | Approve 审批 | Madame 我的 |

## 完整页面清单

> 共 **59 个页面**（含 Navigation 迁移后新增的 `Index` 根容器与各详情 / 二级页），位于 `entry/src/main/ets/pages/`。「ArkTS 文件」列为实际工程文件名。

| 序号 | 页面 | 角色 | ArkTS 文件 |
| --- | --- | --- | --- |
| 1 | 学生登录 | 学生 | LoginPage.ets |
| 2 | 注册 | 学生 | RegisterPage.ets |
| 3 | 忘记密码 | 学生 | ForgotPage.ets |
| 4 | 首页工作台 | 学生 | HomePage.ets |
| 5 | 今日课程 | 学生 | TodayPage.ets |
| 6 | 通知列表 | 学生 | NoticesPage.ets |
| 7 | 通知详情 | 学生 | NoticeDetailPage.ets |
| 8 | 我的课表 | 学生 | SchedulePage.ets |
| 9 | 课程详情 | 学生 | CourseDetailPage.ets |
| 10 | 选课中心 | 学生 | SelectionPage.ets |
| 11 | 成绩查询 | 学生 | GradesPage.ets |
| 12 | 考试安排 | 学生 | ExamPage.ets |
| 13 | 学籍信息 | 学生 | RosterPage.ets |
| 14 | 评教列表/问卷 | 学生 | EvalPage.ets |
| 15 | 请假申请 | 学生 | LeavePage.ets |
| 16 | 意见反馈 | 学生 | FeedbackPage.ets |
| 17 | 实践公服 | 学生 | PracticePage.ets |
| 18 | 实践详情 | 学生 | PracticeDetailPage.ets |
| 19 | 我的 | 学生 | MinePage.ets |
| 20 | 我的账户 | 学生 | AccountPage.ets |
| 21 | 修改资料 | 学生 | EditInfoPage.ets |
| 22 | 修改密码 | 学生 | PasswordPage.ets |
| 23 | 设置 | 学生 | SettingsPage.ets |
| 24 | 关于 | 学生 | AboutPage.ets |
| 25 | 管理员登录 | 管理员 | AdminLoginPage.ets |
| 26 | 管理仪表盘 | 管理员 | AdminDashboardPage.ets |
| 27 | 学生管理 | 管理员 | AdminStudentsPage.ets |
| 28 | 学生详情 | 管理员 | AdminStudentDetailPage.ets |
| 29 | 课程管理 | 管理员 | AdminCoursesPage.ets |
| 30 | 选课管理 | 管理员 | AdminSelectionPage.ets |
| 31 | 成绩管理 | 管理员 | AdminGradesPage.ets |
| 32 | 通知发布 | 管理员 | AdminNoticePage.ets |
| 33 | 评教管理 | 管理员 | AdminEvalPage.ets |
| 34 | 审批中心 | 管理员 | AdminApprovalsPage.ets |
| 35 | 管理员中心 | 管理员 | AdminProfilePage.ets |
| 36 | 管理员修改密码 | 管理员 | AdminPasswordPage.ets |
| 37 | 审计日志 | 管理员 | AdminAuditLogPage.ets |
| 38 | 教学日历 | 管理员 | AdminCalendarPage.ets |
| 39 | 角色权限 | 管理员 | AdminRolePermPage.ets |
| 40 | 系统配置 | 管理员 | AdminSysConfigPage.ets |
| 41 | 服务大厅 | 学生 | ServiceHallPage.ets |
| 42 | 文档页 | 通用 | DocPage.ets |
| 43 | 应用根容器（Navigation） | 通用 | Index.ets |
| 44 | 选课结果 | 学生 | SelectionResultPage.ets |
| 45 | 选课确认 | 学生 | SelectionConfirmPage.ets |
| 46 | 成绩详情 | 学生 | GradeDetailPage.ets |
| 47 | 成绩申诉 | 学生 | GradeAppealPage.ets |
| 48 | 考试详情 | 学生 | ExamDetailPage.ets |
| 49 | 请假详情 | 学生 | LeaveDetailPage.ets |
| 50 | 反馈详情 | 学生 | FeedbackDetailPage.ets |
| 51 | 实践报名 | 学生 | PracticeSignupPage.ets |
| 52 | 我的实践 | 学生 | MyPracticePage.ets |
| 53 | 消息中心 | 学生 | MessageCenterPage.ets |
| 54 | 附件预览 | 学生 | AttachmentPreviewPage.ets |
| 55 | 无权限提示 | 通用 | NoPermissionPage.ets |
| 56 | 审批详情 | 管理员 | AdminApprovalDetailPage.ets |
| 57 | 课程详情（管理） | 管理员 | AdminCourseDetailPage.ets |
| 58 | 导入结果 | 管理员 | ImportResultPage.ets |
| 59 | 审计日志详情 | 管理员 | AuditLogDetailPage.ets |

## 安装与运行

1. 使用 DevEco Studio 打开本项目根目录。
2. 等待工程依赖同步完成。
3. 选择 `entry` 模块。
4. 连接 HarmonyOS 设备或启动模拟器。
5. 点击运行按钮进行构建与安装。

### 命令行构建

项目未提交 `hvigorw` 包装脚本，`local.properties` 也不含 `sdk.dir`，命令行构建需先指定 HarmonyOS SDK（路径替换为本机实际安装位置）：

```bash
# Windows PowerShell 示例（路径替换为本机实际安装位置）
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
& 'D:\DevEco Studio\tools\node\node.exe' 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.js' assembleHap --no-daemon
```

构建产物（HAP）输出至 `entry/build/` 目录。后端（`server/`）的本地运行 / 部署 / 数据库迁移见 [`server/README.md`](server/README.md)。

## 测试账号

内置以下测试账号（本地 mock 定义于 `mock/mockUser.ets` / `mock/mockAdmin.ets`，并已在 Track B 后端 `accounts` 表种子化，本地 / 远程模式均可登录）：

| 角色 | 账号 | 密码 | 登录后身份 |
| --- | --- | --- | --- |
| 学生端 | `2023307020941` | `Elysia@2024` | 李仕炜 |
| 管理端 | `A20251001` | `Admin@2024` | 爱莉希雅 · 教务管理员（远程模式返回后端真实 profile 与权限矩阵） |

- 管理端登录需额外输入**任意 4 位**图形验证码（如 `1234`）。
- **注册 / 找回密码的邮箱验证码为真实发送**：由后端经 QQ 邮箱 SMTP 发送到所填邮箱（5 分钟有效、60 秒重发节流），不再有固定万能码；找回密码要求账号已存在且邮箱与账号绑定邮箱一致（不再自动建号）。
- 修改密码时原密码即登录密码，新密码需 8–32 位且至少包含字母、数字、符号中的两种。

## 使用说明

- 学生端用于完成课程查看、选课、成绩考试查询、评教反馈、请假实践和个人信息管理。
- 管理端用于完成学生、课程、选课、成绩、通知和审批流程管理。
- README 中的 UI 实机截图位于 `docs/screenshots/` 目录下，查看仓库首页或使用 Markdown 预览时会自动引用这些图片。

## 参与贡献

**绷住了小组成员：**

- 绷住了-李仕炜
- 绷住了-郑力辉
- 绷住了-毛坤强
- 绷住了-邵长烨
