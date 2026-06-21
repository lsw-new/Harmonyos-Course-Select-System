// 推送 Token 服务（roadmap #8）：尝试从 HarmonyOS Push Kit 获取设备 token 并注册到后端。
//
// 设计原则：
//   - 完全 best-effort：任何异常（AGC 未配置、模拟器无 Push Kit、网络失败）均被吞掉，
//     登录流程不受影响，push 简单不工作直到 AGC 配置就绪。
//   - 仅在 AppConfig.useRemote=true 且存在学生会话时才尝试，避免 mock 模式无效注册。
//
// 上线步骤（AGC 配置）：
//   1. 在华为 AGC 控制台启用 Push Kit，将 agconnect-services.json 放入项目。
//   2. 在 AppGallery Connect 配置推送证书（HMS Core → Push Kit）。
//   3. 授予设备推送权限后调用 pushService.getToken() 即可获得真实 token。
//   4. tryRegister() 会自动将 token 上报给后端 POST /api/push/tokens。
//
// 模拟器 / 未配置 AGC 时：pushService.getToken() 会抛出 ServiceException，
//   catch 块直接 return，不输出任何错误，不影响登录。

import { AppConfig } from '../../app/AppConfig';
import { RemoteApi } from '../remote/RemoteApi';
import { SessionStorage } from '../storage/SessionStorage';

// 尝试 import Push Kit；在未配置 AGC 的 SDK 环境或模拟器中，
// getToken() 调用时会抛 ServiceException（不在 import 时崩溃），
// catch 块统一处理，无需条件编译。
import { pushService } from '@kit.PushKit';

export class PushTokenService {
  // 尝试注册推送 token：获取设备 token 并上报后端。
  // 全流程 best-effort：任何步骤失败均静默 return，不抛出，不阻断调用方。
  static async tryRegister(): Promise<void> {
    // 仅联机模式 + 学生会话存在时才尝试
    if (!AppConfig.useRemote) {
      return;
    }
    const session = SessionStorage.get();
    if (!session.getStudent()) {
      return;
    }
    try {
      // 向 HMS Core 申请推送 token（需要设备已安装 HMS Core 且 AGC 已配置）
      const token: string = await pushService.getToken();
      if (!token || token.length === 0) {
        return;
      }
      // 上报到后端（后端从 JWT 取学号，UPSERT 防重复）
      await RemoteApi.registerPushToken(token, 'android');
    } catch (_e) {
      // 正常：模拟器 / AGC 未配置时 getToken() 抛 ServiceException；静默忽略。
    }
  }

  // 注销推送 token（登出时调用）。同样 best-effort。
  static async tryUnregister(): Promise<void> {
    if (!AppConfig.useRemote) {
      return;
    }
    try {
      const token: string = await pushService.getToken();
      if (!token || token.length === 0) {
        return;
      }
      await RemoteApi.unregisterPushToken(token);
    } catch (_e) {
      // 静默忽略
    }
  }
}
