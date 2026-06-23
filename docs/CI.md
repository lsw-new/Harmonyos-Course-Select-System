# 持续集成（CI）说明

本仓库托管在 Gitee，并镜像到 GitHub 运行 GitHub Actions。目前共有三条工作流：

| 工作流 | 文件 | 运行环境 | 触发方式 | 作用 |
|--------|------|----------|----------|------|
| backend-tests | `.github/workflows/backend-tests.yml` | 托管 runner（ubuntu-latest，Node 18/20） | push / PR，命中 `server/**` | 后端 API 自动化测试（Jest + supertest），覆盖率门禁 ≥80% 行 |
| frontend-checks | `.github/workflows/frontend-checks.yml` | 托管 runner（ubuntu-latest，Node 20） | push / PR，命中 `entry/**`、检查脚本或本工作流 | 前端 ArkTS 静态门禁（始终可用） |
| frontend-build | `.github/workflows/frontend-build.yml` | 自托管 runner（标签 `harmonyos`） | 仅手动 `workflow_dispatch` | 完整 HarmonyOS HAP 构建（hvigor assembleHap） |

## 为什么前端要拆成两条？

HarmonyOS HAP 的真实编译与 Hypium 测试依赖 **DevEco Studio SDK**（hvigor + ohos sdk）。
GitHub 托管 runner（ubuntu-latest 等）**没有该 SDK，无法在托管 runner 上构建 HAP**。

因此前端 CI 分两层：

- **A) 静态检查门禁（frontend-checks）**：纯 Node 脚本，托管 runner 上始终可跑，作为 push/PR 的常规门禁。
- **B) 完整 HAP 构建（frontend-build）**：放到装了 DevEco 的自托管 runner，**手动触发**，避免无 runner 时任务排队阻塞。

## frontend-checks 检查了什么

脚本 `scripts/ci/check-frontend.js`（纯 Node，无第三方依赖）递归扫描 `entry/src/main/ets`
下所有 `.ets` 文件，检测我们真实踩过的 ArkTS 破坏性写法：

**硬失败（命中即 exit 1）：**

1. 对象字面量展开 `{ ... }` —— ArkTS 禁止对象 spread（数组展开 `[...arr]` 不算）。
2. `VerticalAlign.Stretch` —— 不存在的枚举。

**仅警告（不失败，避免存量误杀）：** `console.log(`、`: any`、`as any`。

输出格式为 `file:line:rule`，结尾打印汇总；有硬失败则 `exit 1`，否则 `exit 0`。

## 本地等价命令

```bash
# 后端测试（在 server/ 目录下）
cd server && npm test

# 前端静态门禁（仓库根目录）
node scripts/ci/check-frontend.js

# 完整 HAP 构建（仅在装有 DevEco 的本机）
hvigorw assembleHap        # 等价于 frontend-build 的 assembleHap 步骤
hvigorw test               # 可选：Hypium 测试
```

## 如何注册自托管 runner 跑完整 HAP 构建

`frontend-build` 需要一台装有 DevEco Studio 的机器作为自托管 runner：

1. **注册 runner 并打标签 `harmonyos`**（在 GitHub 仓库 `Settings → Actions → Runners → New self-hosted runner` 获取 token）：

   ```bash
   # Linux / macOS
   ./config.sh --url <仓库地址> --token <token> --labels harmonyos
   ./run.sh

   # Windows
   ./config.cmd --url <仓库地址> --token <token> --labels harmonyos
   ./run.cmd
   ```

2. **设置环境变量 `DEVECO_SDK_HOME`** 指向 DevEco 的 sdk 目录，例如：

   - Windows：`D:\DevEco Studio\sdk`
   - macOS：`~/Library/Huawei/Sdk`

   工作流按 `"$DEVECO_SDK_HOME/../tools/hvigor/bin/hvigorw.js"` 推断 hvigor 入口；
   不同机器的 DevEco 安装布局可能不同，必要时按实际路径调整工作流中的命令。

3. **手动触发**：在 GitHub 仓库 `Actions → frontend-build → Run workflow` 启动。

> 没有自托管 runner 时无需担心：`frontend-build` 仅手动触发，不会因无 runner 而让 push/PR 排队阻塞；
> 日常门禁由 `frontend-checks` 在托管 runner 上保证。
