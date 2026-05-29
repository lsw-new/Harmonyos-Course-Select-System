import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppStartup } from '../app/AppStartup';

const DOMAIN = 0x0000;
const TAG = 'Elysia';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    AppStartup.init(this.context).then(() => {
      const session = SessionStorage.get();
      let startPage = 'pages/LoginPage';
      if (session.isAuthenticated()) {
        startPage = session.getRole() === 'admin' ? 'pages/AdminDashboardPage' : 'pages/HomePage';
      }

      windowStage.loadContent(startPage, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Loaded: %{public}s', startPage);
      });
    }).catch(() => {
      windowStage.loadContent('pages/LoginPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Fallback load failed: %{public}s', JSON.stringify(err));
        }
      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
