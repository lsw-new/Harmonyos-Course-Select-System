// 应用启动：依赖注入 / 持久化加载 / 全局 token 桥接

import common from '@ohos.app.ability.common';
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
    const preferences = PreferenceStorage.get();
    await preferences.init(context);
    const session = SessionStorage.get();
    await session.restore();
    if (session.getRole() === 'student' && session.getStudent() === undefined) {
      const profile = await ProfileRepository.get().getProfile();
      await session.restoreProfileIfMissing(profile, undefined);
    } else if (session.getRole() === 'admin' && session.getAdmin() === undefined) {
      await session.clear();
    }
    AppStartup.initialized = true;
  }
}
