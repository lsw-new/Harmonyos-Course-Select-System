# HarmonyOS UI 路由覆盖与自然入口验证测试报告

- **测试日期**：2026-06-09
- **项目**：景德镇艺术职业大学教务 App（HarmonyOS ArkTS 客户端）
- **报告来源**：Dynamic workflow `Verify remaining HarmonyOS UI route coverage and safe natural-entry plan` 完成结果（任务输出 `w3ppq664e.output`）
- **测试性质**：源代码静态审计 + 安全点击路径规划
- **是否修改源码**：否
- **是否执行真机/模拟器点击**：否
- **总体结论**：**PARTIAL PASS / WARN**

## 1. 执行摘要

本轮 Dynamic workflow 聚焦 HarmonyOS UI 路由剩余覆盖项，目标是判断仍未完全确认的页面是否存在**自然入口**，以及后续在设备或人工 UI 审计中是否可以安全点击覆盖。

审计结果：候选的 5 个剩余路由中：

| 分类 | 数量 | 路由 |
|---|---:|---|
| 可自然进入且可安全点击 | 3 | `pages/LeaveDetailPage`、`pages/FeedbackDetailPage`、`pages/AttachmentPreviewPage` |
| 预置条件/合成 guard 覆盖 | 1 | `pages/NoPermissionPage` |
| 当前源码无自然入口 | 1 | `pages/ImportResultPage` |

核心结论：

1. `LeaveDetailPage`、`FeedbackDetailPage`、`AttachmentPreviewPage` 均可通过默认学生业务流进入，适合纳入下一轮真机/模拟器 UI 覆盖。
2. `NoPermissionPage` 默认 demo/mock 管理员不可自然触发；只有准备低权限管理员会话或测试 harness 后，才能验证真实权限守卫跳转。
3. `ImportResultPage` 已注册路由，但当前源码未发现可见 UI 调用 `AppRoute.go(Routes.ImportResult)` 的自然入口；如果需要覆盖，只能使用合成导航，或修改源码把导入结果页接入正常导入流程。
4. `FeedbackPage` 与 `GradeAppealPage` 不应继续计入剩余列表：workflow 认为它们已有可接受覆盖证据（如 `239_ServiceHallPage_from_mine`、`233_GradeAppealPage_attempt`）。

## 2. 测试范围与方法

### 2.1 覆盖范围

本次只验证 workflow 指定的剩余 HarmonyOS UI route coverage：

- `pages/LeaveDetailPage`
- `pages/FeedbackDetailPage`
- `pages/AttachmentPreviewPage`
- `pages/NoPermissionPage`
- `pages/ImportResultPage`

### 2.2 方法

workflow 采用源代码静态审计方式：

1. 检查 `route_map.json` 是否注册目标页面 builder。
2. 检查 `AppRoute.ets` 中的路由分类、权限守卫与角色可访问性。
3. 查找业务页面中是否存在自然的 `AppRoute.go(...)` 调用路径。
4. 判断自然路径是否安全：是否依赖写操作、是否会修改数据、是否需要特殊账号/权限、是否可能点击到下载/提交等副作用按钮。
5. 对每个目标路由给出后续人工或设备 UI 审计的点击步骤。

### 2.3 明确限制

- 未连接 HarmonyOS 真机或模拟器。
- 未执行 OHOS instrument 测试。
- 未运行点击自动化脚本。
- 未修改源码以制造入口。
- 结论依赖当前源码与 mock 数据；若切到 remote runtime，列表数据可用性可能受后端响应影响。

## 3. 总体判定矩阵

| 路由 | 路由注册/权限分类 | 自然入口 | 安全点击 | 判定 | 说明 |
|---|---|---:|---:|---|---|
| `pages/LeaveDetailPage` | 学生路由 | 是 | 是 | PASS | 从请假历史列表点击记录进入，传入 `id`。 |
| `pages/FeedbackDetailPage` | 学生路由 | 是 | 是 | PASS | 从反馈历史列表点击记录进入，传入 `id`。 |
| `pages/AttachmentPreviewPage` | 学生可达路径 | 是 | 是 | PASS | 从通知详情附件行进入，传入附件名。需避开「下载」文字按钮。 |
| `pages/NoPermissionPage` | public 页面 + guard 替换目标 | 默认环境否；预置低权限会话后可验证 | 默认环境否；预置低权限会话后可安全验证 guard | PRECONDITIONED | 需要低权限管理员缺失目标权限；默认 mock 管理员不会触发。 |
| `pages/ImportResultPage` | 管理员路由 | 否 | 否 | FAIL/WARN | 路由已注册，但当前源码未发现自然 UI caller。 |

## 4. 逐路由验证结果

### 4.1 `pages/LeaveDetailPage`

- **状态**：PASS
- **自然入口**：有
- **安全性**：安全，只读详情页路径
- **前置条件**：学生会话；mock/local 模式下请假历史有默认数据

推荐覆盖步骤：

1. 使用学生身份进入 App。
2. 打开底部 Tab「我的」。
3. 在「我的事务」中点击「我的请假」，进入 `pages/LeavePage`。
4. 在「请假申请」页切换到「我的申请」Tab。
5. 点击任意历史请假记录，例如 mock 数据中的 `2026-05-15 ~ 2026-05-16` / `感冒发烧，需在宿舍休息。`。
6. 预期进入 `pages/LeaveDetailPage`，页面展示请假记录、状态指标、申请详情、审批进度、审批反馈和相关操作按钮。

判定依据：

- 入口链路：`MinePage` → `LeavePage` → `LeaveDetailPage`。
- `LeavePage` 在历史记录行点击时携带 `{ id: item.id }` 导航到详情页。
- mock 数据存在可用请假记录，适合自然覆盖。

### 4.2 `pages/FeedbackDetailPage`

- **状态**：PASS
- **自然入口**：有
- **安全性**：安全，只读详情页路径
- **前置条件**：学生会话；mock/local 模式下反馈历史有默认数据

推荐覆盖步骤：

1. 使用学生身份进入 App。
2. 从「我的」→「偏好」→「意见反馈」进入 `pages/FeedbackPage`；或从「办事大厅」点击「意见反馈」。
3. 在「意见反馈」页切换到「历史反馈」Tab。
4. 点击任意反馈历史记录，例如 mock 数据中的「课表页面在 iPad 横屏会错位」。
5. 预期进入 `pages/FeedbackDetailPage`，展示反馈标题、状态/类型/截图指标、详细字段、反馈内容、处理时间线和非破坏性操作按钮。

判定依据：

- 入口链路：`MinePage` 或 `ServiceHallPage` → `FeedbackPage` → `FeedbackDetailPage`。
- `FeedbackPage` 在历史反馈行点击时携带 `{ id: item.id }` 导航到详情页。
- workflow 认为该路径在默认 mock 数据下高置信可复现。

### 4.3 `pages/AttachmentPreviewPage`

- **状态**：PASS
- **自然入口**：有
- **安全性**：安全，但点击区域需注意
- **前置条件**：学生会话；通知列表中需要选择带附件的通知

推荐覆盖步骤：

1. 使用学生身份进入 App。
2. 从首页铃铛、消息中心、通知入口或办事大厅进入 `pages/NoticesPage`。
3. 保持通知筛选为「全部」。
4. 点击带附件的通知，例如 mock 数据中的「端午节放假安排通知」或「图书馆暑期开放时间调整」。
5. 在 `pages/NoticeDetailPage` 的附件区域，点击附件行或文件名区域，例如「端午放假调休安排.pdf」。
6. **不要点击行内小号「下载」文字**，该文字会触发下载逻辑，而不是预览导航。
7. 预期进入 `pages/AttachmentPreviewPage`，参数包含 `{ name: att.fileName }`；若未传 `type`，页面类型显示会回退为「文件」。

判定依据：

- 入口链路：`NoticesPage` → `NoticeDetailPage` → `AttachmentPreviewPage`。
- 带附件通知存在于 mock 数据中。
- `NoticeDetailPage` 的附件行容器用于预览跳转，行内「下载」文本用于下载动作，两者需要在测试步骤中明确区分。

### 4.4 `pages/NoPermissionPage`

- **状态**：PRECONDITIONED / 默认 demo 不可自然触发
- **自然入口**：默认 mock/demo 环境无；准备低权限管理员会话或测试 harness 后可验证 guard 重定向
- **默认 mock 管理员**：不能触发
- **安全性**：默认环境不可安全自然触发；低权限测试会话准备完成后，可安全验证权限守卫跳转

推荐覆盖步骤（低权限管理员条件）：

1. 准备一个管理员会话，但权限矩阵中缺少某个受保护管理路由权限。
2. 优先使用缺少 `roles.manage:view` 的管理员，因为 `Routes.AdminRolePerm` 映射到该权限。
3. 打开管理员底部 Tab「我的」，进入 `AdminProfilePage`。
4. 在「系统管理」中点击「角色管理」「权限矩阵」或「我的权限」。
5. 如果权限缺失，`AppRoute.guard` 应失败，并通过 `replacePathByName(Routes.NoPermission)` 显示 `pages/NoPermissionPage`。

注意事项：

- 默认 `mockAdminProfile` 具备相关管理端权限，因此点击同一路径会正常进入 `AdminRolePermPage`，不能作为 NoPermission 覆盖证据。
- `AdminDashboard` 会过滤不可见模块，因此低权限账号下更可靠的触发点是 `AdminProfilePage` 中未完全按模块过滤的系统管理入口。
- 直接打开 `pages/NoPermissionPage` 只能证明页面可渲染，不能证明权限守卫路径有效。

判定依据：

- `NoPermissionPage` 是真实的权限守卫落点。
- 是否自然触发取决于会话权限，不是默认环境稳定可达路径。

### 4.5 `pages/ImportResultPage`

- **状态**：FAIL/WARN
- **自然入口**：无
- **安全性**：自然点击不可测；合成导航可测页面渲染
- **前置条件**：若合成覆盖，需要管理员会话与参数 `{ success, failed, rate }`

workflow 的负向结论：

1. `Routes.ImportResult` 在 `AppRoute.ets` 中存在，并被列入 admin route。
2. `route_map.json` 注册了 `ImportResultPageBuilder`。
3. `ImportResultPage.ets` 会读取 `success`、`failed`、`rate` 等参数。
4. 但当前源码没有发现可见学生或管理员页面调用 `AppRoute.go(Routes.ImportResult)`。
5. 课表导入流程当前表现为 Toast + 重新加载课表，而不是导航到导入结果页。

建议处理方式：

- 如果坚持「自然入口覆盖」标准：把 `ImportResultPage` 标记为当前版本不可自然覆盖，并保留为开放问题。
- 如果只要求页面渲染覆盖：使用测试 harness 或直接路由方式，在管理员会话下带参数打开该页。
- 如果产品希望用户看到导入结果页：修改导入流程，在导入完成后增加跳转到 `Routes.ImportResult` 的正常 CTA 或自动跳转，并补对应测试。

## 5. 后续 UI 审计执行清单

下一轮真机/模拟器或人工 UI 覆盖建议按以下顺序执行：

| 顺序 | 页面 | 推荐会话 | 推荐动作 | 预期产物 |
|---:|---|---|---|---|
| 1 | `LeaveDetailPage` | 学生 | 我的 → 我的请假 → 我的申请 → 历史记录 | 截图 + layout dump + 返回验证 |
| 2 | `FeedbackDetailPage` | 学生 | 我的/办事大厅 → 意见反馈 → 历史反馈 → 记录 | 截图 + layout dump + 返回验证 |
| 3 | `AttachmentPreviewPage` | 学生 | 通知 → 带附件通知 → 附件行/文件名 | 截图 + layout dump + 返回验证 |
| 4 | `NoPermissionPage` | 预置低权限管理员/测试 harness | 管理员我的 → 系统管理 → 缺权路由 | 截图 + guard 重定向证据 |
| 5 | `ImportResultPage` | 管理员 | 合成路由或改造后自然导入结果入口 | 截图 + 参数渲染证据 |

每个页面建议记录：

- 页面标题/核心内容是否可见。
- 是否有空白页或未捕获异常。
- 返回按钮是否能回到上一页。
- 滚动区域是否正常，无明显截断或遮挡。
- 点击动作是否只读或可取消。
- 截图与布局 JSON 是否成对保存。

## 6. 风险与阻塞项

| 编号 | 严重级别 | 状态 | 问题 | 影响 | 建议 |
|---|---|---|---|---|---|
| UI-ROUTE-01 | MEDIUM | OPEN | `NoPermissionPage` 需要低权限管理员会话 | 默认 mock admin 无法自然触发，容易误判为已覆盖 | 准备低权限账号/会话，或写专门 guard 测试。 |
| UI-ROUTE-02 | MEDIUM | OPEN | `ImportResultPage` 无自然 UI caller | 路由注册但业务流不可达，真实用户无法进入 | 决定是否接入导入流程；否则标为 synthetic-only。 |
| UI-ROUTE-03 | LOW | OPEN | `AttachmentPreviewPage` 附件行与「下载」文字点击行为不同 | 人工测试可能点错区域，导致未覆盖预览页 | 测试步骤明确点击附件行/文件名，不点下载文本。 |
| UI-ROUTE-04 | LOW | OPEN | remote 模式下详情列表数据不一定存在 | 自然入口依赖后端返回记录 | UI 覆盖前确认 mock/local 数据或准备远程测试数据。 |

## 7. 发布/验收建议

### 7.1 可接受为已规划覆盖的页面

以下 3 个页面可以进入下一轮设备 UI 审计的「自然入口待截图」清单：

- `pages/LeaveDetailPage`
- `pages/FeedbackDetailPage`
- `pages/AttachmentPreviewPage`

只要按本报告步骤取得截图与布局证据，即可将它们从剩余 route coverage 中移除。

### 7.2 需要特殊验收条件的页面

`pages/NoPermissionPage` 不应使用默认 mock admin 验收。验收必须满足：

1. 当前会话为管理员。
2. 目标路由所需权限缺失。
3. 不是直接打开 NoPermission 页面，而是从受保护管理路由触发 `AppRoute.guard`。
4. 观察到自动替换到 `Routes.NoPermission`。

### 7.3 不建议按自然入口强行验收的页面

`pages/ImportResultPage` 当前不满足自然入口覆盖条件。推荐二选一：

- **产品修复路线**：把导入结果页接入真实导入流程，再按自然入口验收。
- **测试豁免路线**：明确标注为 synthetic-only 页面，用直接路由/测试 harness 覆盖渲染，不再要求自然点击路径。

## 8. 最终结论

本次 Dynamic workflow 已完成剩余 HarmonyOS UI 路由覆盖的源代码级验证与安全自然入口规划。总体结论为：**PARTIAL PASS / WARN**。

- 3 个页面具备高置信、低风险的自然覆盖路径。
- 1 个页面需要预置低权限管理员或测试 harness 才能验证真实 guard 重定向，默认 demo/mock 环境不可自然覆盖。
- 1 个页面当前源码无自然入口，属于路由注册与业务接线不一致问题。

因此，下一轮不应再盲目搜索所有剩余页面入口，而应直接按本报告执行：先采集 3 个学生自然路径证据，再单独准备低权限管理员验证 `NoPermissionPage`，最后对 `ImportResultPage` 做产品接线决策或测试豁免。