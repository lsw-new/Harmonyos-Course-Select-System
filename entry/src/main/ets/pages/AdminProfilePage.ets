// 管理员中心 · Madame
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider, Monogram } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AdminProfile } from '../models/Admin';

@Entry
@Component
struct AdminProfilePage {
  @State profile: AdminProfile | null = null;
  @State darkMode: boolean = false;
  @State pushEnabled: boolean = true;
  @State showLogoutConfirm: boolean = false;

  aboutToAppear(): void {
    const p = SessionStorage.get().getAdmin();
    if (p) { this.profile = p; }
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => { AppRoute.clearTo(Routes.AdminLogin); });
  }

  @Builder StatMini(label: string, value: string) {
    Column() {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder EntryRow(icon: string, label: string, hint: string) {
    Row() {
      AppIcon({ name: icon, iconSize: 18, mRight: 10 })
      Text(label).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
      Text(hint).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      AppIcon({ name: 'forward', iconSize: 14, dim: true, mLeft: 6 })
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder ToggleRow(icon: string, label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      AppIcon({ name: icon, iconSize: 18, mRight: 10 })
      Text(label).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(ElysiaTheme.ROSE_500)
        .onChange((on: boolean) => { onChange(on); })
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Madame', subtitle: '管 理 员 中 心', showBack: false })

        Scroll() {
          Column({ space: 14 }) {
            // 头像卡片
            Column({ space: 6 }) {
              Monogram({ iconSize: 56 })
              Text(this.profile?.name ?? '管理员').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 8 })
              Text(`${this.profile?.department ?? ''} · ${this.profile?.roleName ?? ''}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              Pill({ text: this.profile?.onlineStatus === 'online' ? '在线' : '离线',
                color: this.profile?.onlineStatus === 'online' ? '#7BB07B' : ElysiaTheme.INK_MUTE, bg: '#FFF6FA' })
            }.width('100%').alignItems(HorizontalAlign.Center).padding(20)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            // 效率统计
            Row({ space: 0 }) {
              this.StatMini('今日审批', '8')
              this.StatMini('平均时长', '12min')
              this.StatMini('待办', '3')
              this.StatMini('通过率', '87%')
            }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
            .border({ width: 1, color: '#66FFB3CE' })

            // 系统管理
            Column() {
              Text('系统管理').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.EntryRow('students', '角色管理', '')
              this.EntryRow('dashboard', '权限矩阵', '')
              this.EntryRow('star', '我的权限', `${this.profile?.permissions.length ?? 0} 项`)
              this.EntryRow('file', '操作日志', '')
              this.EntryRow('calendar', '校历管理', '')
              this.EntryRow('approve', '审批流配置', '')
              this.EntryRow('mail', '消息模板', '')
              this.EntryRow('lock', '安全策略', '')
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            // 偏好
            Column() {
              Text('偏好').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.ToggleRow('star', '夜间模式', this.darkMode, (v: boolean) => { this.darkMode = v; })
              this.ToggleRow('bell', '消息推送', this.pushEnabled, (v: boolean) => { this.pushEnabled = v; })
              this.EntryRow('info', '关于系统', 'V1.0.0')
              this.EntryRow('unlock', '修改密码', '')
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: '#66FFB3CE' })

            // 退出
            Text('退出登录')
              .fontSize(14).fontColor('#D8546B').fontWeight(FontWeight.Medium)
              .width('100%').textAlign(TextAlign.Center)
              .padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#40D8546B' })
              .onClick(() => { this.showLogoutConfirm = true; })

            Blank().height(80)
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)

        AdminTabBar({ active: 'mine', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }

      if (this.showLogoutConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text('确认退出？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text('退出后需重新登录管理控制台').fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text('取消').fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor('#E0FFFFFF').borderRadius(999)
                .onClick(() => { this.showLogoutConfirm = false; })
              Text('退出').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                .onClick(() => { this.logout(); })
            }.margin({ top: 8 })
          }.padding(24).backgroundColor(Color.White).borderRadius(22)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#66000000')
        .onClick(() => { this.showLogoutConfirm = false; })
      }
    }.width('100%').height('100%')
  }
}
