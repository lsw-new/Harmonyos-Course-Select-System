// 我的中心 · Mine
import promptAction from '@ohos.promptAction';
import { ElysiaTheme } from '../common/Theme';
import { Monogram, RoseDivider } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { StudentTabBar } from '../common/widgets/TabBars';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { SessionStorage } from '../common/storage/SessionStorage';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { UserProfile } from '../models/User';
import { HomeSummary } from '../models/Home';

class QuickItem {
  icon: string = '';
  label: string = '';
  route: string = '';
  constructor(icon: string, label: string, route: string) {
    this.icon = icon;
    this.label = label;
    this.route = route;
  }
}

interface MineEntry {
  icon: string;
  title: string;
  subtitle: string;
  route?: string;
  badge?: string;
  toggle?: boolean;
  danger?: boolean;
}

@Entry
@Component
struct MinePage {
  @State darkMode: boolean = false;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State profile: UserProfile | null = null;
  @State unreadCount: number = 0;
  @State showLogoutConfirm: boolean = false;

  private quickItems: QuickItem[] = [
    new QuickItem('schedule', '课表', Routes.Schedule),
    new QuickItem('grades', '成绩', Routes.Grades),
    new QuickItem('selection', '选课', Routes.Selection),
    new QuickItem('roster', '学籍', Routes.Roster),
    new QuickItem('exam', '考试', Routes.Exam),
    new QuickItem('evaluation', '评教', Routes.Eval),
    new QuickItem('notice', '通知', Routes.Notices),
    new QuickItem('more', '更多', '')
  ];

  private affairs: MineEntry[] = [
    { icon: 'wallet', title: '我的账户', subtitle: '账号信息 · 状态 · 有效期', route: Routes.Account },
    { icon: 'edit', title: '修改个人信息', subtitle: '手机 · 邮箱 · 头像 · 联系人', route: Routes.EditInfo },
    { icon: 'lock', title: '修改密码', subtitle: '强度建议 · 8 位以上', route: Routes.Password },
    { icon: 'leave', title: '我的请假', subtitle: '3 条记录', badge: '1', route: Routes.Leave },
    { icon: 'public', title: '办事大厅', subtitle: '课程替代 · 缓考 · 转专业…' }
  ];

  @State prefs: MineEntry[] = [
    { icon: 'settings', title: '系统设置', subtitle: '消息 · 缓存 · 深色模式', route: Routes.Settings },
    { icon: 'feedback', title: '意见反馈', subtitle: '帮我们变得更好', route: Routes.Feedback },
    { icon: 'star', title: '夜间模式', subtitle: '减少屏幕灼伤', toggle: true },
    { icon: 'info', title: '关于', subtitle: 'v1.1.0 · 协议 · 隐私政策' },
    { icon: 'close', title: '退出登录', subtitle: '清除本地凭据', danger: true }
  ];

  aboutToAppear(): void {
    PreferenceStorage.get().getBoolean('darkMode', false).then((v: boolean) => {
      this.darkMode = v;
      ElysiaTheme.setDarkMode(v);
    });
    this.loadData();
  }

  private setDarkModePreference(value: boolean): void {
    this.darkMode = value;
    ElysiaTheme.setDarkMode(value);
    PreferenceStorage.get().putBoolean('darkMode', value);
    promptAction.showToast({ message: value ? '深色模式已开启' : '深色模式已关闭' });
  }

  loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = ProfileRepository.get();
    Promise.all([repo.getProfile(), repo.getHomeSummary()])
      .then((res: [UserProfile, HomeSummary]) => {
        this.profile = res[0];
        this.unreadCount = res[1].unreadNoticeCount;
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => {
      AppRoute.clearTo(Routes.Login);
    });
  }

  private handleEntryTap(it: MineEntry): void {
    if (it.danger) {
      this.showLogoutConfirm = true;
      return;
    }
    if (it.toggle) {
      return;
    }
    if (it.route && it.route.length > 0) {
      AppRoute.go(it.route);
    } else {
      promptAction.showToast({ message: '该功能正在建设中' });
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], [ElysiaTheme.SURFACE_GLOW, 1]]
        })

      Column() {
        Blank().height(40)

        // Hero
        Column() {
          // 顶部标题
          Row() {
            Text('Salon de Elysia')
              .fontSize(14)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
            Blank().layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              AppIcon({ name: 'settings', iconSize: 16 })
            }
            .width(34).height(34)
            .backgroundColor(ElysiaTheme.SURFACE_GLOW)
            .border({ width: 1, color: '#99FFB3CE' })
            .accessibilityText('打开系统设置')
            .onClick(() => { AppRoute.go(Routes.Settings); })
          }
          .width('100%')
          .margin({ bottom: 18 })

          // 头像 + 信息
          Row() {
            Monogram({ iconSize: 72 })
            Column() {
              Text(this.profile !== null ? `${this.profile.name} · 同学` : 'Elysia · 同学')
                .fontSize(24)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
              Text(this.profile !== null
                ? `${this.profile.college} · ${this.profile.major} ${this.profile.className}`
                : '软件学院 · 软件工程 2304')
                .fontSize(11)
                .fontColor(ElysiaTheme.INK_SOFT)
                .margin({ top: 2 })
              Text(this.profile !== null
                ? `SID · ${this.profile.studentId}`
                : 'SID · 20231104')
                .fontSize(10)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.INK_MUTE)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 14 })
            .layoutWeight(1)
          }

          // Quick stats
          Row({ space: 6 }) {
            this.StatBlock('3.86', 'GPA')
            this.StatBlock('21.5', '学分')
            this.StatBlock(this.unreadCount > 0 ? `${this.unreadCount}` : '00', '通知')
            this.StatBlock('02', '待办')
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(ElysiaTheme.SURFACE_GLOW)
          .borderRadius(16)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 22 })
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_100, 0.6], [ElysiaTheme.SURFACE_GLOW, 1]]
        })

        if (this.loading) {
          LoadingState({ tip: '正在加载...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else {
          Scroll() {
            Column() {
              // 八宫格
              Grid() {
                ForEach(this.quickItems, (it: QuickItem) => {
                  GridItem() {
                    Column() {
                      Stack() {
                        AppIcon({ name: it.icon, iconSize: 22 })
                      }
                      .width(46).height(46)
                      .borderRadius(14)
                      .linearGradient({
                        angle: 135,
                        colors: [[ElysiaTheme.SURFACE, 0], [ElysiaTheme.ROSE_100, 1]]
                      })
                      .border({ width: 1, color: '#80FFB3CE' })
                      Text(it.label)
                        .fontSize(10)
                        .fontColor(ElysiaTheme.INK_SOFT)
                        .margin({ top: 6 })
                    }
                    .onClick(() => {
                      if (it.route.length > 0) AppRoute.go(it.route);
                      else promptAction.showToast({ message: '该功能正在建设中' });
                    })
                    .accessibilityText(it.label)
                  }
                }, (it: QuickItem) => it.label)
              }
              .columnsTemplate('1fr 1fr 1fr 1fr')
              .columnsGap(10)
              .rowsGap(10)
              .margin({ top: 4, bottom: 6 })
              .padding({ left: 16, right: 16 })

              RoseDivider({ label: '我 的 事 务' })
              this.EntryGroup(this.affairs)

              RoseDivider({ label: '偏好与系统' })
              this.EntryGroup(this.prefs)

              Blank().height(120)
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }

      // Logout confirm dialog
      if (this.showLogoutConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text('确认退出登录？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text('退出后需重新登录').fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text('取消').fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 14, bottom: 14 })
                .backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(999)
                .accessibilityText('取消退出登录')
                .onClick(() => { this.showLogoutConfirm = false; })
              Text('退出').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 14, bottom: 14 })
                .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                .accessibilityText('确认退出登录')
                .onClick(() => { this.logout(); })
            }.margin({ top: 8 })
          }.padding(24).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#66000000')
      }

      // Bottom tab bar
      Column() {
        Blank().layoutWeight(1)
        StudentTabBar({
          active: 'mine',
          onTap: (id: string, route: string) => {
            if (id !== 'mine') AppRoute.go(route, { replace: true });
          }
        })
      }.width('100%').height('100%')
    }
    .width('100%').height('100%')
  }

  @Builder StatBlock(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label)
        .fontSize(9)
        .fontColor(ElysiaTheme.INK_SOFT)
        .letterSpacing(2)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder EntryGroup(items: MineEntry[]) {
    Column() {
      ForEach(items, (it: MineEntry, idx?: number) => {
        Row() {
          Stack() {
            AppIcon({ name: it.icon, iconSize: 18 })
          }
          .width(34).height(34)
          .borderRadius(11)
          .linearGradient({
            angle: 135,
            colors: it.danger
              ? [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.ROSE_200, 1]]
              : [[ElysiaTheme.SURFACE, 0], [ElysiaTheme.LAV_200, 1]]
          })

          Column() {
            Text(it.title)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(it.danger ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK)
            Text(it.subtitle)
              .fontSize(10)
              .fontColor(ElysiaTheme.INK_SOFT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12, right: 12 })
          .layoutWeight(1)

          if (it.badge) {
            Text(it.badge)
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .borderRadius(999)
              .linearGradient({
                angle: 135,
                colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]]
              })
          } else if (it.toggle) {
            Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
              .selectedColor(ElysiaTheme.ROSE_500)
              .onChange((v: boolean) => {
                this.setDarkModePreference(v);
              })
          } else {
            AppIcon({ name: 'forward', iconSize: 14, dim: true })
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .accessibilityText(it.title)
        .onClick(() => { this.handleEntryTap(it); })
        if (idx !== undefined && idx < items.length - 1) {
          Divider().strokeWidth(1).color('#80FFB3CE')
        }
      }, (it: MineEntry) => it.title)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
    .margin({ left: 16, right: 16 })
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(22)
    .border({ width: 1, color: '#66FFB3CE' })
    .shadow({ radius: 16, color: '#1FD85487', offsetX: 0, offsetY: 4 })
  }
}
