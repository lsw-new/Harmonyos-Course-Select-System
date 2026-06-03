import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import display from '@ohos.display';
import { AppStartup } from '../app/AppStartup';
import { BreakpointManager } from '../common/widgets/Breakpoint';

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

    this.setupWindow(windowStage);

    AppStartup.init(this.context).then(() => {
      // 初始页由 pages/Index 的 Navigation 按会话角色决定，这里只加载根容器。
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Loaded: %{public}s', 'pages/Index');
      });
    }).catch(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Fallback load failed: %{public}s', JSON.stringify(err));
        }
      });
    });
  }

  // 开启 edge-to-edge 全屏布局，并把状态栏 / 底部手势条的真实避让高度（vp）
  // 写入 AppStorage，供页面里的 SafeTop / SafeBottom 组件订阅。失败时回退到
  // 与旧版一致的固定值（顶 40 / 底 0），保证最坏情况不劣于改造前。
  private setupWindow(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000'
      });

      const density: number = display.getDefaultDisplaySync().densityPixels;
      const toVp = (px: number): number => density > 0 ? Math.round(px / density) : px;
      const publish = (): void => {
        try {
          const sys: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          const indicator: window.AvoidArea =
            win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          const top: number = toVp(sys.topRect.height);
          const bottom: number = toVp(indicator.bottomRect.height);
          AppStorage.setOrCreate<number>('safeTop', top > 0 ? top : 40);
          AppStorage.setOrCreate<number>('safeBottom', bottom > 0 ? bottom : 0);
        } catch (err) {
          AppStorage.setOrCreate<number>('safeTop', 40);
          AppStorage.setOrCreate<number>('safeBottom', 0);
        }
      };

      // 响应式断点：按窗口宽度(vp)归类 sm/md/lg，写入 AppStorage 供页面订阅。
      const publishBreakpoint = (): void => {
        try {
          const widthVp: number = toVp(win.getWindowProperties().windowRect.width);
          AppStorage.setOrCreate<string>('breakpoint', BreakpointManager.classify(widthVp));
        } catch (err) {
          AppStorage.setOrCreate<string>('breakpoint', 'sm');
        }
      };

      publish();
      publishBreakpoint();
      win.on('avoidAreaChange', () => { publish(); });
      win.on('windowSizeChange', (_size: window.Size) => { publishBreakpoint(); });
    } catch (err) {
      AppStorage.setOrCreate<number>('safeTop', 40);
      AppStorage.setOrCreate<number>('safeBottom', 0);
      AppStorage.setOrCreate<string>('breakpoint', 'sm');
    }
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
