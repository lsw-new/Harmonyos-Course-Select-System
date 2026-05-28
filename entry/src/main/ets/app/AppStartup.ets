// 应用启动：依赖注入 / 持久化加载 / 全局 token 桥接

import common from '@ohos.app.ability.common';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { SessionStorage } from '../common/storage/SessionStorage';

export class AppStartup {
  private static initialized = false;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (AppStartup.initialized) return;
    AppStartup.initialized = true;
    await PreferenceStorage.get().init(context);
    await SessionStorage.get().restore();
  }
}
