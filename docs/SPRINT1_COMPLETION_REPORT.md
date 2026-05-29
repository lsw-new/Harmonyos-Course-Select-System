# Sprint 1 完成情况说明

日期：2026-05-29  
工作目录：`D:\test2\.claude\worktrees\project-plan-sprint1`  
分支：`worktree-project-plan-sprint1`

## 1. 概述

本次根据 `PROJECT_PLAN.md` 的 Sprint 1 目标，对教学管理系统进行了第一阶段完善。重点从“页面展示型原型”推进到“具备本地可写数据、会话恢复、管理端关键操作闭环、主题切换、文件能力与基础测试”的可演示版本。

本阶段已完成除真实 release 签名出包以外的主要功能。release 出包部分已补齐文档与安全配置模板，但实际生成可安装 HAP 仍依赖本地 Hvigor/DevEco 环境和真实 HarmonyOS 签名材料。

## 2. 已完成事项

### 2.1 管理员登录入口

- 在学生登录页新增管理员登录入口。
- 管理员登录页新增返回学生登录入口。
- 修复管理员登录页存在但首屏不可达的问题。

相关文件：

- `entry/src/main/ets/pages/LoginPage.ets`
- `entry/src/main/ets/pages/AdminLoginPage.ets`

### 2.2 会话恢复与 401 处理

- 扩展 `SessionStorage`，持久化 token、角色、学生资料和管理员资料。
- 冷启动时恢复会话和角色资料。
- `isAuthenticated()` 不再只检查 token 和 role，而是要求角色资料也有效。
- 管理员资料缺失或损坏时清理会话，避免本地伪造 admin session。
- 增加统一 `ApiClient`，集中配置 token provider 和 401 回调。
- 401 时自动清理会话并按角色跳转登录页。
- 应用启动流程调整为先配置网络与文件服务，再恢复本地存储和会话。

相关文件：

- `entry/src/main/ets/common/storage/SessionStorage.ets`
- `entry/src/main/ets/common/http/ApiClient.ets`
- `entry/src/main/ets/app/AppStartup.ets`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/repositories/BaseRepository.ets`

### 2.3 本地可写数据持久化

新增基于 Preferences 的轻量本地 JSON 数组存储封装 `LocalDataStore`，用于在无后端环境下保存关键业务操作结果。

已接入本地持久化的数据包括：

- 选课状态
- 请假申请
- 意见反馈
- 管理端审批记录
- 管理端成绩审核记录
- 管理端课程列表
- 评教任务提交状态
- mock 文件下载记录

同时为选课、课程、成绩、评教等持久化数据增加了基础校验与清洗逻辑，避免损坏或异常 Preferences JSON 直接污染业务状态。

相关文件：

- `entry/src/main/ets/common/storage/LocalDataStore.ets`
- `entry/src/main/ets/repositories/CourseRepository.ets`
- `entry/src/main/ets/repositories/ProfileRepository.ets`
- `entry/src/main/ets/repositories/AdminRepository.ets`
- `entry/src/main/ets/repositories/EvaluationRepository.ets`
- `entry/src/main/ets/common/services/FileService.ets`

### 2.4 管理端课程 CRUD

新增管理端课程创建、编辑、删除能力，并接入本地持久化。

主要能力：

- 新增课程。
- 编辑课程。
- 删除未被选课的课程。
- 查询本地持久化后的课程数据。
- 页面级表单输入与基础校验。
- 删除前二次确认。
- 权限校验：要求管理员具备 `courses.manage` 对应操作权限。

主要校验：

- 课程代码格式与重复检查。
- 课程名称、教师、时间文本长度与非法字符检查。
- 学分、容量、已选人数必须为有限数字。
- 容量必须为正整数。
- 已选人数不能超过容量。
- 同一教师同一时间不能冲突。
- 已有学生选课时禁止删除。

相关文件：

- `entry/src/main/ets/repositories/AdminRepository.ets`
- `entry/src/main/ets/models/Admin.ets`
- `entry/src/main/ets/pages/AdminCoursesPage.ets`
- `entry/src/main/ets/mock/mockAdmin.ets`

### 2.5 成绩录入、审核、驳回

新增成绩录入与审核流转能力，并接入本地持久化。

主要能力：

- 管理端录入成绩进度。
- 录入进度达到 100% 后进入待审核。
- 审核通过后发布成绩。
- 审核驳回时记录驳回原因。
- 驳回后允许重新录入并再次提交审核。
- 已发布成绩不可继续编辑、驳回或重复审核。
- 页面展示驳回状态和驳回原因。
- 权限校验：要求管理员具备 `grades.approve` 对应操作权限。

相关文件：

- `entry/src/main/ets/repositories/AdminRepository.ets`
- `entry/src/main/ets/models/Admin.ets`
- `entry/src/main/ets/pages/AdminGradesPage.ets`
- `entry/src/main/ets/mock/mockAdmin.ets`

### 2.6 审批权限补强

- 管理端审批通过、驳回操作增加权限校验。
- 要求管理员具备 `approvals.handle` 的 `approve` 权限。
- 避免仅凭管理员登录态即可修改审批结果。

相关文件：

- `entry/src/main/ets/repositories/AdminRepository.ets`
- `entry/src/main/ets/mock/mockAdmin.ets`

### 2.7 管理端页面路由守卫

为管理端关键页面补充统一路由守卫，防止非管理员或未认证用户直接进入管理页面。

已补充守卫页面包括：

- 管理首页
- 学生管理
- 审批管理
- 管理员资料
- 选课管理
- 发布通知
- 评教管理
- 课程管理
- 成绩管理

相关文件：

- `entry/src/main/ets/pages/AdminDashboardPage.ets`
- `entry/src/main/ets/pages/AdminStudentsPage.ets`
- `entry/src/main/ets/pages/AdminApprovalsPage.ets`
- `entry/src/main/ets/pages/AdminProfilePage.ets`
- `entry/src/main/ets/pages/AdminSelectionPage.ets`
- `entry/src/main/ets/pages/AdminNoticePage.ets`
- `entry/src/main/ets/pages/AdminEvalPage.ets`
- `entry/src/main/ets/pages/AdminCoursesPage.ets`
- `entry/src/main/ets/pages/AdminGradesPage.ets`

### 2.8 头像选择与文件下载

新增统一 `FileService`：

- 支持通过系统图片选择器选择头像。
- 支持远程 `http://` / `https://` 文件下载到应用缓存或文件目录。
- 支持 `mock://files/` 模拟文件下载，并记录本地 mock 下载历史。
- 下载地址和文件名增加安全校验。
- 文件名禁止包含路径片段、控制字符、`..`、`/`、`\`。
- 远程下载使用真实返回的保存路径，不再猜测下载落点。
- 新增网络权限 `ohos.permission.INTERNET`。

已接入页面：

- 编辑资料页头像选择。
- 首页资料文件下载。
- 通知详情附件下载。

相关文件：

- `entry/src/main/ets/common/services/FileService.ets`
- `entry/src/main/ets/pages/EditInfoPage.ets`
- `entry/src/main/ets/pages/HomePage.ets`
- `entry/src/main/ets/pages/NoticeDetailPage.ets`
- `entry/src/main/module.json5`

### 2.9 全局深色模式

将主题从固定静态颜色扩展为可切换的 light/dark token 系统。

主要能力：

- `ElysiaTheme` 通过静态 getter 返回当前主题 token。
- 新增 `setDarkMode()` 与 `isDarkMode()`。
- 设置页、我的页面、管理员资料页的深色模式开关统一写入 `darkMode`。
- 应用启动时恢复深色模式设置。
- 调整 MinePage 等页面中的硬编码浅色背景，使其使用主题 token。
- 补充部分交互元素的无障碍标签与更合理的点击区域。

相关文件：

- `entry/src/main/ets/common/Theme.ets`
- `entry/src/main/ets/pages/SettingsPage.ets`
- `entry/src/main/ets/pages/AdminProfilePage.ets`
- `entry/src/main/ets/pages/MinePage.ets`
- `entry/src/main/ets/app/AppStartup.ets`

### 2.10 测试补齐

扩展本地 Hypium 单测，覆盖核心新增逻辑。

已覆盖内容包括：

- 深色模式切换与重置。
- `LocalDataStore` 在未初始化 Preferences 时的 fallback 行为。
- `FileService` mock 下载路径。
- 文件下载 URL 和文件名安全校验。
- `SessionStorage` 管理员登录态与清理。
- 管理端课程创建、查询、重复代码校验。
- 课程容量、已选人数、非有限数字、非整数校验。
- 已有选课课程禁止删除。
- 未被选课课程允许删除。
- 未授权课程创建与成绩驳回失败。
- 成绩录入、待审核、驳回、重新录入、发布完整流转。

相关文件：

- `entry/src/test/LocalUnit.test.ets`

### 2.11 release 签名与出包准备

已补齐 release 出包说明和签名材料保护，但未生成真实 release HAP。

已完成：

- 新增 release 文档。
- 新增本地签名材料目录说明。
- `.gitignore` 忽略证书、profile、keystore、密码、密钥等敏感文件。
- `build-profile.json5` 保留安全模板说明，不启用缺失文件的签名配置。

未完成原因：

- 当前环境缺少 `hvigor` / `hvigorw` / `hvigorw.bat`。
- 当前环境缺少真实 HarmonyOS release 签名材料。
- 不应伪造证书、提交密码或硬编码签名配置。

相关文件：

- `docs/RELEASE.md`
- `signing/README.md`
- `signing/.gitignore`
- `.gitignore`
- `build-profile.json5`

## 3. 安全与质量处理

本次重点修复和避免的问题：

- 避免管理员 session 缺少 profile 时被当作已认证。
- 避免损坏 Preferences JSON 污染业务数据。
- 避免课程容量、成绩进度等数字字段被 `Infinity`、`NaN` 或非整数污染。
- 避免文件下载文件名路径穿越。
- 避免远程下载返回猜测路径。
- 避免审批、课程、成绩写操作缺少管理员权限校验。
- 避免把签名证书、profile、密码或私钥提交到仓库。

## 4. 验证情况

已完成的验证：

- 已运行 `git diff --check`。
- 结果无 whitespace error，仅有 LF/CRLF warning。
- 已完成代码审查，最终结果为 `APPROVED`。

未完成的验证：

- 未能运行 HarmonyOS 构建。
- 未能运行真实 Hypium 测试。
- 未能生成 release HAP。

原因：当前环境缺少可用的 `hvigor` / `hvigorw` / DevEco 构建链路。

## 5. 当前遗留事项

### 5.1 release HAP 出包

需要用户补充以下内容后才能继续完成：

1. 可用的 DevEco/HarmonyOS SDK/Hvigor 环境。
2. 项目可执行的 `hvigorw` 或全局可用的 `hvigor`。
3. 真实 release 签名材料：
   - `.p12`
   - `.p7b` / profile
   - `.cer`
   - key alias
   - store password
   - key password

补齐后可按 `docs/RELEASE.md` 完成签名配置和 release HAP 生成。

## 6. 建议下一步

1. 如果要交付当前 Sprint 1：先提交当前 worktree 改动。
2. 如果要完成 release：补齐 Hvigor/DevEco 与签名材料后继续 #8。
3. 如果继续开发：进入 `PROJECT_PLAN.md` 后续 Sprint。

## 7. 总结

Sprint 1 的核心业务闭环已完成：登录入口、会话恢复、本地可写数据、管理端课程 CRUD、成绩审核、文件能力、深色模式和基础测试均已落地。唯一未完成的是依赖外部材料和工具链的真实 release 签名出包。