// 轻提示统一封装：用 UIContext.getPromptAction()（替代已废弃的全局 promptAction.showToast）。
// 页面调用：Toast.show(this.getUIContext(), '已保存')。
import { UIContext } from '@kit.ArkUI';

export class Toast {
  static show(ctx: UIContext, message: string, durationMs: number = 2000): void {
    ctx.getPromptAction().showToast({
      message: message,
      duration: durationMs
    });
  }
}
