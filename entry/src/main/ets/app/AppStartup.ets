// 应用启动：依赖注入 / 持久化加载 / 全局 token 桥接

import common from '@ohos.app.ability.common';
import { AppDatabase } from '../common/storage/AppDatabase';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { SessionStorage } from '../common/storage/SessionStorage';
import { apiClient } from '../common/http/ApiClient';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { FileService } from '../common/services/FileService';
import { AppRoute, Routes } from './AppRoute';

export class AppStartup {
  private static initialized = false;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (AppStartup.initialized) return;
    apiClient.setTokenProvider(() => SessionStorage.get().getToken());
    apiClient.setUnauthorizedHandler(() => {
      const loginRoute = SessionStorage.get().getRole() === 'admin' ? Routes.AdminLogin : Routes.Login;
      SessionStorage.get().clear()
        .catch(() => undefined)
        .then(() => {
          AppRoute.clearTo(loginRoute);
        });
    });
    FileService.configure(context);
    // 本地 RDB 初始化失败不应阻断启动：降级为 Preferences 回退，仓储层通过 isReady() 判断
    try {
      await AppDatabase.init(context);
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      console.error('[AppStartup] 本地数据库初始化失败，进入 Preferences 回退模式: ' + msg);
    }
    const preferences = PreferenceStorage.get();
    await preferences.init(context);
    const session = SessionStorage.get();
    await session.restore();
    // 用安全存储对齐 token（Asset Store Kit 为权威来源，旧会话回填迁移）
    await session.reconcileSecureToken();
    if (session.getRole() === 'student' && session.getStudent() === undefined) {
      const profile = await ProfileRepository.get().getProfile();
      await session.restoreProfileIfMissing(profile, undefined);
    } else if (session.getRole() === 'admin' && session.getAdmin() === undefined) {
      await session.clear();
    }
    AppStartup.initialized = true;
  }
}
