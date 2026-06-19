# 功能完善计划书 · 2026-06-19

> **执行状态（2026-06-19 更新，agent team 实施）**
> - ✅ **后端全部完成并部署上线**（迁移 010 grade_appeals、011 exams 已应用；申诉/考试/学籍·record/登录历史
>   共 9 个新端点 401 鉴权就位；smoke 36/36；全套 324 测试通过）。提交 `769ccce`/`ed6d2f4`。
> - ✅ **学生侧前端全部接通**（HAP 构建通过）：成绩申诉真正落库（原空壳）、考试安排接 /api/exams、
>   学籍页真实 GPA/已修学分/门数、登录历史接 /api/profile/login-history。提交 `ed6d2f4`/`5079473`。
> - ✅ 阶段 0 评教统计：核实为**已经是真实数据**（AdminEvalPage 走 EvalAdminRepository→adminEvalStats），
>   原报告点名的 AdminRepository.getEvaluationStats 实为无调用方的死代码，无需接线。
> - ⏳ **待办：两个管理端专用 UI**——申诉受理/驳回页、考试 CRUD 页。后端均已上线；
>   过渡期管理员可经 Web 控制台「数据库管理」直接维护 grade_appeals / exams 两张表。
> - ⏳ 阶段 4 消息中心服务端化：维持原判（可选、最低优先），未做。

---


对 HarmonyOS（ArkTS）+ Node/Express/Postgres 教学管理系统做了一次端到端功能盘点
（61 个页面、17 个仓储、14 个后端路由域），按「数据是否真实联通」给每个功能定级，
并给出分期完善路线。盘点方法：交叉比对 前端仓储是否走 `AppConfig.useRemote`、
`RemoteApi` 是否有对应端点、后端是否有对应路由与表，三者齐全才算「真实闭环」。

---

## 一、功能现状矩阵

### A. 完全联通（真实闭环，线上 smoke 36/36 已验证）

学生端：登录 / 注册（名册白名单 + 邮箱验证码）/ 找回密码、选课（选课/退课/冲突校验/容量行锁）、
成绩查询（已发布）、班级课表、通知（列表/详情/已读落 `notice_reads`）、请假（提交/撤回/审批闭环）、
反馈（提交 + 管理端处理回复）、评教（任务随课程同步/提交）、实践（列表/详情/报名/取消，行锁防超额）。

管理端：仪表盘、学生管理、成绩录入/审核/打分/发布、审批流、通知发布、角色权限、审计日志、
课程目录 CRUD、选课统计与轮次管理、校历、数据库管理（全表 CRUD）、验证码监控。

> 这部分是系统主体，已是真实数据闭环，无需「完善」，只需持续回归。

### B. 后端已就绪、前端漏接（纯接线缺口 — 最高性价比）

| 功能 | 现状 | 缺口 |
|---|---|---|
| **管理端·评教统计** | 后端 `/api/admin/eval/stats` 真实聚合已存在；`RemoteApi.adminEvalStats()` 客户端方法已存在 | `AdminRepository.getEvaluationStats()` 直接 `return mockEvaluationStats`，**从未调用** RemoteApi。AdminEvalPage 统计页展示的是假数字 |

> 这是「管道两头都通了，中间一根线没接」。补一个方法分支即可让评教统计变真实，成本最低。

### C. UI 存在但是空壳（点了无效果 / 不持久）

| 功能 | 现状 |
|---|---|
| **成绩申诉 GradeAppeal** | `submitAppeal()` 仅弹 Toast「申诉已提交」，**无任何持久化、无远程调用**。后端无学生申诉端点（`grade_tasks` 虽有 `appealed` 状态但无学生侧入口）。学生以为提交成功，实际什么都没发生 |

### D. 无后端，纯 mock（数据看着真，其实是演示数据）

| 功能 | 涉及 | 说明 |
|---|---|---|
| **考试安排** | ExamPage / ExamDetailPage / `AcademicRepository.getExams` | 无 `exams` 表、无路由、无 RemoteApi，返回 `mockExams` |
| **学籍详情扩展字段** | `AcademicRepository.getStudentRecord` | 基础字段（姓名/学号/学院/专业/班级/年级）已与会话真实资料同源；GPA/学制/培养类别/导师/宿舍等仍 mock |
| **登录历史** | `AuthRepository.getLoginHistory` | 后端无登录审计统计，返回 mock |

### E. 设计性本地（合理，但有局限，非缺陷）

| 功能 | 说明 |
|---|---|
| **消息中心 MessageCenter** | 客户端把请假结果/成绩发布/选课结果/评教任务聚合成「消息」，无独立后端消息表；已读态本地存储，不跨设备、无服务端推送 |

---

## 二、完善路线（按性价比与依赖排序）

### 阶段 0 · 接线快赢（约 0.5 天，纯前端，无 schema 变更）

1. **评教统计接真**：`AdminRepository.getEvaluationStats()` 仿照 `getApprovals` 加 `useRemote` 分支，
   调 `RemoteApi.adminEvalStats()`，按 `RemoteEvalStats → EvaluationStats` 做一个 `AdminLogic.remoteToEvalStats` 映射，
   remote 失败按 `allowMockFallbackInRemote` 决定抛错或回退。**收益最高、风险最低**。
2. **成绩申诉决策**：二选一——
   - 暂时**隐藏入口**（GradeDetail 里去掉「申诉」按钮），避免「假成功」误导；或
   - 排入阶段 2 做成真功能（见下）。

### 阶段 1 · 学籍详情补真（约 1–1.5 天，后端小改 + 前端接线）

- 后端：`student_profiles` 增补或新建 `student_records` 视图，补 GPA（可由 `grades` 聚合）、学制、培养类别等；
  新增 `GET /api/profile/record`。GPA/已修学分可直接从 `grades` 实时聚合，无需新存储。
- 前端：`getStudentRecord` 加 remote 分支，扩展字段取真值；后端确无的字段（导师/宿舍）明确标注「暂无」而非假值。
- 风险：低。GPA 聚合口径需与成绩页 `gradePointOf` 一致。

### 阶段 2 · 成绩申诉闭环（约 2–3 天，全栈新功能）

- 后端：新建 `grade_appeals` 表（appeal_id/student_id/task_id/course_id/reason/status/submitted_at/handled_by/reply）
  + 迁移；学生端 `POST /api/grades/:taskId/appeal`（校验成绩归属本人、防重复）；
  管理端 `GET /api/admin/grade-appeals` + 处理端点（受理/驳回，联动 `grade_tasks.status='appealed'`）。
- 前端：`submitAppeal()` 真正落库；管理端新增「申诉处理」栏目（或并入成绩管理）。
- 风险：中。涉及与现有成绩审核状态机的衔接，需 TDD 覆盖状态流转。

### 阶段 3 · 考试安排（约 3–4 天，全栈新模块）

- 后端：新建 `exams` 表（exam_id/course_id/term/exam_date/start/end/location/seat/type）+ 迁移 + 导入脚本；
  学生端 `GET /api/exams`（按班级/已选课程匹配，复用评教同步的「本班课表∪已选」口径）；
  管理端 CRUD（可挂在 admin-courses 或新建 admin-exams 路由）。
- 前端：`getExams` 加 remote 分支；ExamDetail 取真值；首页/课表可加「近期考试」入口。
- 风险：中。数据来源（教务考试编排）需确认；座位/缺考等字段视需要裁剪。

### 阶段 4 · 消息中心服务端化（可选，约 3–5 天）

- 现状客户端聚合已能用；若要跨设备已读 + 服务端推送，需 `messages` 表 + 已读表 + 生成触发点
  （成绩发布/审批结果/选课结果时写一条消息）+ 拉取端点。
- 优先级最低：当前体验可接受，仅在有多设备/推送需求时再做。

### 阶段 5 · 登录历史（约 1 天，后端小改）

- 复用既有 `audit_logs`（已记录认证事件）派生「最近登录」：新增 `GET /api/profile/login-history`
  按当前账号查 `audit_logs` 登录类记录；前端 `getLoginHistory` 接真。低优先。

---

## 三、与功能并行的工程债（来自 2026-06-19 审查，见 REVIEW_2026-06-19.md）

这些不属于「功能缺失」，但影响健壮性，建议穿插处理：

- nodemailer ≤9.0.0 升级（当前代码路径不触发 CVE，breaking 且动邮箱链路，需单独评估）。
- `admin.routes.js` 上帝文件（~660 行）按子域拆分；`syncAllStudents` N+1 事务批量化；
  权限中间件每请求查库改请求级缓存；评教统计应用层 1000 行 JSON 聚合下推 SQL。
- 暗色模式（既有长期延后项）。

---

## 四、建议执行顺序

1. **阶段 0**（半天，立即做）：评教统计接线 + 成绩申诉入口决策。投入最小、最快消除「假数据」观感。
2. **阶段 1**（学籍补真）+ **阶段 2**（申诉闭环）：补齐学生最常触达的两个半成品。
3. **阶段 3**（考试安排）：取决于是否有真实考试编排数据源。
4. **阶段 4/5**：按需，低优先。

> 总体判断：系统主干已是真实闭环且线上稳定，剩余「完善」集中在 1 个接线缺口（评教统计）、
> 1 个 UI 空壳（成绩申诉）、3 个纯演示模块（考试/学籍扩展/登录历史）。先做半天的阶段 0，
> 收益与观感提升最明显。
