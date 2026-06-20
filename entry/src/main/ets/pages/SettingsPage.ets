// 系统设置 · Settings
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { SessionStorage } from '../common/storage/SessionStorage';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { CacheManager } from '../common/storage/CacheManager';
import { FileService } from '../common/services/FileService';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { AppConfig } from '../app/AppConfig';
import { AuthRepository } from '../repositories/AuthRepository';

@Component
struct SettingsPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State pushEnabled: boolean = true;
  @State evalReminder: boolean = true;
  @State dndMode: boolean = false;
  @State homeworkReminder: boolean = true;
  @State biometric: boolean = false;
  // #12 登录二次验证开关（仅联机，服务器为唯一事实来源）
  @State twoFactorEnabled: boolean = false;
  @State twoFactorBusy: boolean = false;
  @State showLogoutConfirm: boolean = false;
  @State cacheText: string = '点击清除';
  @State clearing: boolean = false;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Settings)) {
      return;
    }
    PreferenceStorage.get().getBoolean('push', true).then((v: boolean) => { this.pushEnabled = v; });
    PreferenceStorage.get().getBoolean('evalReminder', true).then((v: boolean) => { this.evalReminder = v; });
    PreferenceStorage.get().getBoolean('dndMode', false).then((v: boolean) => { this.dndMode = v; });
    PreferenceStorage.get().getBoolean('homeworkReminder', true).then((v: boolean) => { this.homeworkReminder = v; });
    PreferenceStorage.get().getBoolean('biometric', false).then((v: boolean) => { this.biometric = v; });
    // #12 登录二次验证开关：仅联机时读后端真实状态（mock 模式保持关闭且不可操作）
    if (AppConfig.useRemote) {
      AuthRepository.get().getTwoFactor()
        .then((on: boolean) => { this.twoFactorEnabled = on; })
        .catch(() => { /* 读取失败保持默认关闭，不打断设置页 */ });
    }
    this.refreshCacheSize();
  }

  // #12 翻转登录二次验证开关：联机调后端，失败回滚并提示
  private toggleTwoFactor(next: boolean): void {
    if (this.twoFactorBusy) {
      return;
    }
    if (!AppConfig.useRemote) {
      // mock 模式离线，无法配置；回滚 UI 并提示需联网
      this.twoFactorEnabled = false;
      Toast.show(this.getUIContext(), '需联网');
      return;
    }
    this.twoFactorBusy = true;
    this.twoFactorEnabled = next;
    AuthRepository.get().setTwoFactor(next)
      .then((confirmed: boolean) => {
        this.twoFactorBusy = false;
        this.twoFactorEnabled = confirmed;
      })
      .catch(() => {
        this.twoFactorBusy = false;
        this.twoFactorEnabled = !next;
        Toast.show(this.getUIContext(), '设置失败，请稍后重试');
      });
  }

  private togglePref(key: string, value: boolean): void {
    PreferenceStorage.get().putBoolean(key, value);
  }

  // 缓存大小：后台静默统计，绝不长期停留在「统计中」。算出来就显示真实大小，
  // 否则保持「点击清除」这个可操作占位（扫描慢/异常都不卡 UI）。
  private refreshCacheSize(): void {
    CacheManager.getSizeBytes()
      .then((bytes: number) => { this.cacheText = bytes > 0 ? CacheManager.formatBytes(bytes) : '点击清除'; })
      .catch(() => { this.cacheText = '点击清除'; });
  }

  private clearCache(): void {
    if (this.clearing) {
      return;
    }
    this.clearing = true;
    this.cacheText = '清理中…';
    CacheManager.clear()
      .then((freed: number) => {
        // 附件已从 cacheDir 删除，下载历史一并清空（本地、快，不阻塞反馈）
        FileService.clearDownloadHistory();
        this.clearing = false;
        const msg = freed > 0
          ? `缓存已清除，释放 ${CacheManager.formatBytes(freed)}`
          : '缓存已清理，当前无可清理内容';
        Toast.show(this.getUIContext(), msg);
        this.refreshCacheSize();
      })
      .catch((e: Object) => {
        this.clearing = false;
        const msg = (e instanceof Error) ? e.message : String(e);
        Toast.show(this.getUIContext(), `清除失败：${msg}`);
        this.refreshCacheSize();
      });
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => { AppRoute.clearTo(Routes.Login); });
  }

  @Builder ToggleRow(label: string, desc: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(label).fontSize(14).fontColor(ElysiaTheme.INK)
        if (desc.length > 0) {
          Text(desc).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(ElysiaTheme.ROSE_500)
        .onChange((on: boolean) => { onChange(on); })
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  // #12 登录二次验证行：联机可切换；mock 模式置灰并显示「需联网」
  @Builder TwoFactorRow() {
    Row() {
      Column() {
        Text('登录二次验证').fontSize(14).fontColor(ElysiaTheme.INK)
        Text(AppConfig.useRemote ? '登录时邮箱验证码校验' : '需联网')
          .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.twoFactorEnabled })
        .selectedColor(ElysiaTheme.ROSE_500)
        .enabled(AppConfig.useRemote && !this.twoFactorBusy)
        .opacity(AppConfig.useRemote ? 1 : 0.4)
        .onChange((on: boolean) => { this.toggleTwoFactor(on); })
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder LinkRow(label: string, hint: string, onTap?: () => void) {
    Row() {
      Text(label).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
      Text(hint).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      AppIcon({ name: 'forward', iconSize: 14, dim: true, mLeft: 6 })
    }.width('100%').padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
    .onClick(() => { if (onTap !== undefined) onTap(); })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.settings_title'), subtitle: $r('app.string.settings_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            // 所有设置项并为一整段，不再分块
            Column() {
              this.ToggleRow('消息推送', '接收系统通知', this.pushEnabled, (v: boolean) => {
                this.pushEnabled = v;
                this.togglePref('push', v);
              })
              this.ToggleRow('评教提醒', '评教开放时提醒', this.evalReminder, (v: boolean) => {
                this.evalReminder = v;
                this.togglePref('evalReminder', v);
              })
              this.ToggleRow('勿扰模式', '22:00-08:00 不推送', this.dndMode, (v: boolean) => {
                this.dndMode = v;
                this.togglePref('dndMode', v);
              })
              this.ToggleRow('作业截止提醒', '截止前 24h 提醒', this.homeworkReminder, (v: boolean) => {
                this.homeworkReminder = v;
                this.togglePref('homeworkReminder', v);
              })
              this.ToggleRow('生物识别登录', '指纹/面容', this.biometric, (v: boolean) => {
                this.biometric = v;
                this.togglePref('biometric', v);
              })
              this.TwoFactorRow()
              this.LinkRow('清除缓存', this.cacheText, () => { this.clearCache(); })
              this.LinkRow('检查更新', 'V1.0.0', () => {
                Toast.show(this.getUIContext(), '已是最新版本');
              })
              this.LinkRow('用户协议', '', () => {
                const p: Record<string, Object> = { 'type': 'agreement' };
                AppRoute.go(Routes.Doc, { params: p });
              })
              this.LinkRow('隐私政策', '', () => {
                const p: Record<string, Object> = { 'type': 'privacy' };
                AppRoute.go(Routes.Doc, { params: p });
              })
              this.LinkRow('关于', '景德镇艺术职业大学', () => {
                AppRoute.go(Routes.About);
              })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            Text($r('app.string.account_logout'))
              .fontSize(14).fontColor(ElysiaTheme.ROSE_ACCENT).fontWeight(FontWeight.Medium)
              .width('100%').textAlign(TextAlign.Center)
              .padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#40D8546B' })
              .onClick(() => { this.showLogoutConfirm = true; })

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })

      if (this.showLogoutConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text($r('app.string.mine_logout_confirm')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text($r('app.string.mine_logout_hint')).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text($r('app.string.common_cancel')).fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(999)
                .onClick(() => { this.showLogoutConfirm = false; })
              Text($r('app.string.mine_logout')).fontSize(14).fontColor(ElysiaTheme.SURFACE).fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                .onClick(() => { this.logout(); })
            }.margin({ top: 8 })
          }.padding(24).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#66000000')
        .onClick(() => { this.showLogoutConfirm = false; })
      }
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function SettingsPageBuilder() {
  NavDestination() {
    SettingsPage()
  }
  .hideTitleBar(true)
}
