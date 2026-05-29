# Release 打包说明

本项目当前不提交真实签名材料。生成可安装 HAP 前，需要由项目维护者在本机 DevEco Studio / HarmonyOS SDK 环境中配置真实 release 签名。

## 前置条件

- 已安装 DevEco Studio，并可使用项目匹配的 HarmonyOS SDK / Hvigor 版本。
- 项目根目录存在可执行的 `hvigorw` / `hvigorw.bat`，或本机 PATH 中可用 `hvigor`。
- 已从 AppGallery Connect / HarmonyOS 开发者后台获取 release 签名材料。

## 需要准备的私密材料

请将签名材料放在本机安全位置，或临时放入项目根目录的 `signing/` 目录。`signing/` 已配置忽略私钥、证书、profile 和密码文件，禁止提交到 Git。

通常需要：

- 应用签名证书，例如 `.p12`。
- 证书链或发布证书，例如 `.cer` / `.p7b`。
- 发布 profile / provisioning profile。
- keystore / p12 密码、key alias、key 密码。

不要把密码、证书路径或私钥硬编码进仓库文件。优先使用 DevEco Studio 本机签名配置，或使用本机环境变量 / 未跟踪的本地配置文件。

## 推荐操作：DevEco Studio 出包

1. 使用 DevEco Studio 打开项目根目录。
2. 在 `File > Project Structure > Signing Configs` 中新增 release 签名配置。
3. 选择真实 `.p12`、证书和发布 profile，并填写 alias / 密码。
4. 将 product 的 `signingConfig` 指向该 release 配置。
5. 执行 `Build > Build Hap(s)/APP(s) > Build Hap(s)`，选择 release 构建。
6. 在 `entry/build/default/outputs/default/` 或 DevEco Studio 构建输出面板提示的位置获取 `.hap` 产物。

## 命令行出包

如果项目根目录存在 `hvigorw.bat`：

```powershell
.\hvigorw.bat --mode module -p module=entry@default -p product=default -p buildMode=release assembleHap
```

如果使用全局 `hvigor`：

```powershell
hvigor --mode module -p module=entry@default -p product=default -p buildMode=release assembleHap
```

命令参数可能随 DevEco/Hvigor 版本变化。如命令失败，请以当前 DevEco Studio 版本生成的 Hvigor 任务名为准。

## 产物检查

生成后至少检查：

- 存在 `.hap` 文件。
- HAP 使用 release 签名配置签名。
- 能安装到目标设备或模拟器。
- 未将 `.p12`、`.p7b`、`.cer`、profile、密码文件加入 Git。

## 当前仓库状态说明

当前仓库只提供安全发布流程说明和签名材料忽略规则，不包含真实签名配置。缺少开发者证书、profile、p12/p7b 等私有材料时，不能生成可安装 release HAP。
