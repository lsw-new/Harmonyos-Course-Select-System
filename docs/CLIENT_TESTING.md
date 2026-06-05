# 客户端测试指南（HarmonyOS / ArkTS）

> 后端 API 已有 Jest + supertest 自动化门禁（见 [`server/test/`](../server/test) 与 CI）。
> 本文档针对 **HarmonyOS App 端**（ArkTS / @ohos/hypium）测试——这部分目前**没有无头 CI**
> （HarmonyOS SDK + 测试运行器依赖 DevEco / 设备），故以本文档充当**人工门禁清单**：
> 每次答辩 / 发布前在 DevEco 跑一遍本地单测，并在文末「最后一次通过」登记。

---

## 1. 两类测试（务必分清）

| 层级 | 目录 | 是否需设备 | 适合 | 入口 |
|---|---|---|---|---|
| **本地单元测试** | `entry/src/test/` | 否（DevEco 本地运行器） | 纯逻辑：仓储、解析器、校验、安全、状态机 | `entry/src/test/List.test.ets` → `localUnitTest()` |
| **设备测试（Instrument）** | `entry/src/ohosTest/` | **是**（模拟器 / 真机） | Ability 启动、UI、页面流程冒烟 | `entry/src/ohosTest/ets/test/List.test.ets` → `abilityTest()` |

测试框架：`@ohos/hypium`（`describe / it / expect / beforeEach / afterEach`）。

---

## 2. 测试环境

- **DevEco Studio**（与构建同版本）+ HarmonyOS SDK **API 19**。
- 环境变量 `DEVECO_SDK_HOME=D:\DevEco Studio\sdk`（与 `assembleHap` 一致）。
- 设备测试额外需要：已启动的**模拟器**或已连接的**真机**（`hdc list targets` 可见）。
- 本地单元测试**不需要**设备。

---

## 3. 执行方式

### 3.1 DevEco Studio（推荐 / 可靠路径）

1. **本地单元测试**：打开 `entry/src/test/LocalUnit.test.ets`，点 `localUnitTest` / 单个 `it` 行号旁的 ▶ 运行；
   或 `Run > Edit Configurations… > + > OpenHarmony Test`，Test kind 选 **Local Test**，运行。
2. **设备测试**：先启动模拟器 / 连真机，再运行 `entry/src/ohosTest/`（Test kind = **Instrument Test**）。

测试结果在 DevEco 的 **Run / Test** 面板查看（通过数 / 失败数 / 失败堆栈）。

### 3.2 命令行（现状与局限）

- `assembleHap` **只编译**（含测试源参与类型检查），**不执行**用例：
  ```powershell
  $env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
  & "D:\DevEco Studio\tools\node\node.exe" "D:\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --no-daemon
  ```
- HarmonyOS 暂**无简洁的无头 CLI** 跑 ArkTS 本地单测（不像后端 `npm test`）。设备测试可经 DevEco 触发的 `onDeviceTest` 流程，但依赖设备。
- **因此**：App 端测试**未接入 CI**；本文档即人工门禁。若后续 DevEco / 工具链提供稳定 CLI，再补 `.github/workflows/` 客户端流水线。

---

## 4. 本地单测覆盖清单（`LocalUnit.test.ets`，16 例）

| 领域 | 用例数 | 覆盖点 |
|---|---|---|
| 课表导入 | 2 | xlsx 网格解析周次 / 开课信息；单双周展开 |
| 本地存储兜底 | 1 | Preferences 不可用时 `LocalDataStore` 回退 |
| 数据库 schema | 1 | RDB 定义核心业务表 |
| 文件服务安全 | 2 | 稳定 mock 路径 + 拒绝不安全文件名 / 空 URL / 非法协议 / 路径分隔符 |
| 会话存储 | 1 | 管理员会话鉴权 + 清会话 |
| 管理端课程 CRUD | 5 | 建课 / 查得；拒重复课程号；拒非法 selectedCount/capacity；有选课学生拒删；零选课可删 |
| 管理端鉴权 + 业务流 | 4 | 无管理员会话拒建课/拒驳回成绩；成绩录入→驳回→审核状态机；通知发布落学生列表；请假建审批且审批联动请假态 |

> 这些用例已随各功能迭代维护，并通过 `assembleHap` 类型检查；**实际运行结果以 DevEco 测试面板为准**。

---

## 5. 预期结果

- `describe('localUnitTest')` 下全部 `it` **通过**，失败数 0。
- 设备测试：Ability 正常拉起，冒烟 `it` 通过。

---

## 6. 常见失败原因排查

| 现象 | 可能原因 | 处理 |
|---|---|---|
| 编译期就报错 | ArkTS 严格模式（禁 `delete` / 隐式 any / 未类型化字面量等） | 先 `assembleHap` 定位，按报错行修 |
| 设备测试卡住 / 找不到设备 | 模拟器未启动 / 真机未连 | `hdc list targets` 确认，再运行 Instrument Test |
| `LocalDataStore` / RDB 相关失败 | 本地运行器无 Preferences / RDB 上下文 | 该路径已有「不可用回退」用例覆盖；确认 `beforeEach` 的 `clearLocalUnitState()` 生效 |
| SDK 报版本不符 | `DEVECO_SDK_HOME` 指向 SDK 与工程 API 版本不一致 | 对齐 API 19 SDK |
| 偶发顺序相关失败 | 用例间状态泄漏 | 本套件 `beforeEach/afterEach` 已 `clearLocalUnitState()`；新增用例须保持隔离 |

---

## 7. 后续应补的客户端测试（建议优先级）

1. 登录态恢复：学生 / 管理员 / token 失效后的会话恢复。
2. 选课成功后：按钮态、课表合并、容量变化同步。
3. 通知详情已读后：首页角标 + 列表态同步。
4. 实践报名 / 取消：详情页、列表页、我的实践三处同步。
5. 管理端权限：无权限入口不可见、强行跳转落「无权限」页。
6. **remote 模式失败即报错**：验证 `runtimeMode='remote'` 且后端不可用时各仓储读取**抛错而非回退 mock**（对应 `AppConfig.allowMockFallbackInRemote=false` 网关）。

---

## 8. 运行登记（每次答辩 / 发布前更新）

| 日期 | 运行人 | 范围 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-06-05 | — | 本地单测源 `assembleHap` 类型检查 | 编译通过 | 用例**实跑**待 DevEco 测试面板执行后登记 |
| （待填） | | 本地单测（DevEco Local Test） | | 答辩前在 DevEco 跑一遍并登记通过数 |

> **最后一次「实跑」通过时间**：____（在 DevEco 跑通本地单测后填写，例如「2026-06-XX，16/16 通过」）。
