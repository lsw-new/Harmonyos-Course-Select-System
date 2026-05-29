// 系统设置 · Settings
import promptAction from '@ohos.promptAction';
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { SessionStorage } from '../common/storage/SessionStorage';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';

@Entry
@Component
struct SettingsPage {
  @State pushEnabled: boolean = true;
  @State evalReminder: boolean = true;
  @State dndMode: boolean = false;
  @State homeworkReminder: boolean = true;
  @State darkMode: boolean = false;
  @State biometric: boolean = false;
  @State showLogoutConfirm: boolean = false;

  aboutToAppear(): void {
    PreferenceStorage.get().getBoolean('push', true).then((v: boolean) => { this.pushEnabled = v; });
    PreferenceStorage.get().getBoolean('evalReminder', true).then((v: boolean) => { this.evalReminder = v; });
    PreferenceStorage.get().getBoolean('dndMode', false).then((v: boolean) => { this.dndMode = v; });
    PreferenceStorage.get().getBoolean('homeworkReminder', true).then((v: boolean) => { this.homeworkReminder = v; });
    PreferenceStorage.get().getBoolean('darkMode', false).then((v: boolean) => { this.darkMode = v; });
    PreferenceStorage.get().getBoolean('biometric', false).then((v: boolean) => { this.biometric = v; });
  }

  private togglePref(key: string, value: boolean): void {
    PreferenceStorage.get().putBoolean(key, value);
  }

  private setDarkModePreference(value: boolean): void {
    this.darkMode = value;
    ElysiaTheme.setDarkMode(value);
    PreferenceStorage.get().putBoolean('darkMode', value);
    promptAction.showToast({ message: value ? '深色模式已开启' : '深色模式已关闭' });
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
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], [ElysiaTheme.SURFACE_GLOW, 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Settings', subtitle: '系 统 设 置', onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            Column() {
              Text('通知').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
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
            .border({ width: 1, color: '#66FFB3CE' })

            Column() {
              Text('外观').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.LinkRow('主题', '玫瑰学院风', () => {
                promptAction.showToast({ message: '该功能正在建设中' });
              })
              this.LinkRow('字体大小', '标准', () => {
                promptAction.showToast({ message: '该功能正在建设中' });
              })
              this.ToggleRow('深色模式', '', this.darkMode, (v: boolean) => {
                this.setDarkModePreference(v);
              })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            Column() {
              Text('安全与存储').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.ToggleRow('生物识别登录', '指纹/面容', this.biometric, (v: boolean) => {
                this.biometric = v;
                this.togglePref('biometric', v);
              })
              this.LinkRow('清除缓存', '12.3 MB', () => {
                PreferenceStorage.get().putBoolean('cacheCleared', true);
                promptAction.showToast({ message: '缓存已清除' });
              })
              this.LinkRow('检查更新', 'V1.0.0', () => {
                promptAction.showToast({ message: '已是最新版本' });
              })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            Column() {
              this.LinkRow('用户协议', '', () => {
                promptAction.showToast({ message: '该功能正在建设中' });
              })
              this.LinkRow('隐私政策', '', () => {
                promptAction.showToast({ message: '该功能正在建设中' });
              })
              this.LinkRow('关于', 'Elysia · 教学管理系统', () => {
                promptAction.showToast({ message: '该功能正在建设中' });
              })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            Text('退出登录')
              .fontSize(14).fontColor('#D8546B').fontWeight(FontWeight.Medium)
              .width('100%').textAlign(TextAlign.Center)
              .padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#40D8546B' })
              .onClick(() => { this.showLogoutConfirm = true; })

            Blank().height(40)
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }

      if (this.showLogoutConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text('确认退出登录？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text('退出后需重新登录').fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text('取消').fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(999)
                .onClick(() => { this.showLogoutConfirm = false; })
              Text('退出').fontSize(14).fontColor(ElysiaTheme.SURFACE).fontWeight(FontWeight.Bold)
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
