// 系统设置 · Settings
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { SessionStorage } from '../common/storage/SessionStorage';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

// 字体档位定义
class FontScaleOption {
  key: string = '';
  label: string = '';
  size: number = 14;
  constructor(key: string, label: string, size: number) {
    this.key = key;
    this.label = label;
    this.size = size;
  }
}

@Component
struct SettingsPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State pushEnabled: boolean = true;
  @State evalReminder: boolean = true;
  @State dndMode: boolean = false;
  @State homeworkReminder: boolean = true;
  @State biometric: boolean = false;
  @State fontScale: string = 'normal';
  @State showLogoutConfirm: boolean = false;
  @State showFontSheet: boolean = false;

  private fontOptions: FontScaleOption[] = [
    new FontScaleOption('small', '小', 13),
    new FontScaleOption('normal', '标准', 15),
    new FontScaleOption('large', '大', 18)
  ];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Settings)) {
      return;
    }
    PreferenceStorage.get().getBoolean('push', true).then((v: boolean) => { this.pushEnabled = v; });
    PreferenceStorage.get().getBoolean('evalReminder', true).then((v: boolean) => { this.evalReminder = v; });
    PreferenceStorage.get().getBoolean('dndMode', false).then((v: boolean) => { this.dndMode = v; });
    PreferenceStorage.get().getBoolean('homeworkReminder', true).then((v: boolean) => { this.homeworkReminder = v; });
    PreferenceStorage.get().getBoolean('biometric', false).then((v: boolean) => { this.biometric = v; });
    PreferenceStorage.get().getString('fontScale', 'normal').then((v: string) => { this.fontScale = v; });
  }

  private togglePref(key: string, value: boolean): void {
    PreferenceStorage.get().putBoolean(key, value);
  }

  private selectFontScale(key: string): void {
    this.fontScale = key;
    PreferenceStorage.get().putString('fontScale', key);
    this.showFontSheet = false;
    Toast.show(this.getUIContext(), '字体大小已保存，重新进入页面后全局生效');
  }

  private fontScaleLabel(): string {
    for (let i = 0; i < this.fontOptions.length; i++) {
      if (this.fontOptions[i].key === this.fontScale) {
        return this.fontOptions[i].label;
      }
    }
    return '标准';
  }

  private fontSampleSize(): number {
    for (let i = 0; i < this.fontOptions.length; i++) {
      if (this.fontOptions[i].key === this.fontScale) {
        return this.fontOptions[i].size;
      }
    }
    return 15;
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
            Column() {
              Text($r('app.string.settings_sec_notify')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
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
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            Column() {
              Text($r('app.string.settings_sec_appearance')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.LinkRow('字体大小', this.fontScaleLabel(), () => {
                this.showFontSheet = true;
              })
              // 字体大小实时预览（本页即时生效）
              Text(`预览：景德镇艺术职业大学 · 字号 ${this.fontSampleSize()}`)
                .fontSize(this.fontSampleSize())
                .fontColor(ElysiaTheme.INK_SOFT)
                .width('100%')
                .padding({ top: 10, bottom: 4 })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            Column() {
              Text($r('app.string.settings_sec_security')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.ToggleRow('生物识别登录', '指纹/面容', this.biometric, (v: boolean) => {
                this.biometric = v;
                this.togglePref('biometric', v);
              })
              this.LinkRow('清除缓存', '12.3 MB', () => {
                PreferenceStorage.get().putBoolean('cacheCleared', true);
                Toast.show(this.getUIContext(), '缓存已清除');
              })
              this.LinkRow('检查更新', 'V1.0.0', () => {
                Toast.show(this.getUIContext(), '已是最新版本');
              })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            Column() {
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

      if (this.showFontSheet) {
        Column() {
          Column({ space: 6 }) {
            Text($r('app.string.settings_font_title')).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              .width('100%').textAlign(TextAlign.Start).margin({ bottom: 6 })
            ForEach(this.fontOptions, (opt: FontScaleOption) => {
              this.FontOptionRow(opt)
            }, (opt: FontScaleOption) => opt.key)
          }.padding(20).width('100%')
          .backgroundColor(ElysiaTheme.SURFACE)
          .borderRadius({ topLeft: 22, topRight: 22 })
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: -6 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.End)
        .backgroundColor('#66000000')
        .onClick(() => { this.showFontSheet = false; })
      }
    }.width('100%').height('100%')
  }

  @Builder FontOptionRow(opt: FontScaleOption) {
    Row() {
      Text(opt.label).fontSize(opt.size).fontColor(ElysiaTheme.INK).layoutWeight(1)
      if (opt.key === this.fontScale) {
        AppIcon({ name: 'check', iconSize: 16 })
      }
    }
    .width('100%').padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .borderRadius(12)
    .backgroundColor(opt.key === this.fontScale ? ElysiaTheme.SURFACE_GLOW : Color.Transparent)
    .onClick(() => { this.selectFontScale(opt.key); })
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