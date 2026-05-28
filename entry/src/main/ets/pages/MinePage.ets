// 我的中心 · Mine
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { Monogram, RoseDivider, Pill, ElysiaTabBar } from '../common/Components';

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
  @State darkMode: boolean = true;

  private quickItems: QuickItem[] = [
    new QuickItem('◰', '课表', 'pages/SchedulePage'),
    new QuickItem('✓', '成绩', 'pages/GradesPage'),
    new QuickItem('☰', '选课', 'pages/SelectionPage'),
    new QuickItem('◔', '学籍', 'pages/RosterPage'),
    new QuickItem('◧', '考试', 'pages/ExamPage'),
    new QuickItem('✦', '评教', 'pages/EvalPage'),
    new QuickItem('◐', '通知', 'pages/NoticesPage'),
    new QuickItem('＋', '更多', '')
  ];

  private affairs: MineEntry[] = [
    { icon: '👤', title: '我的账户', subtitle: '账号信息 · 状态 · 有效期', route: 'pages/AccountPage' },
    { icon: '✎', title: '修改个人信息', subtitle: '手机 · 邮箱 · 头像 · 联系人' },
    { icon: '⌘', title: '修改密码', subtitle: '强度建议 · 8 位以上' },
    { icon: '🌸', title: '我的请假', subtitle: '3 条记录', badge: '1' },
    { icon: '📜', title: '办事大厅', subtitle: '课程替代 · 缓考 · 转专业…' }
  ];

  @State prefs: MineEntry[] = [
    { icon: '⚙', title: '系统设置', subtitle: '消息 · 缓存 · 深色模式' },
    { icon: '💌', title: '意见反馈', subtitle: '帮我们变得更好' },
    { icon: '☾', title: '夜间模式', subtitle: '减少屏幕灼伤', toggle: true },
    { icon: 'ⓘ', title: '关于', subtitle: 'v1.1.0 · 协议 · 隐私政策' },
    { icon: '⏏', title: '退出登录', subtitle: '清除本地凭据', danger: true }
  ];

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
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
              Text('⚙').fontSize(14).fontColor(ElysiaTheme.ROSE_700)
            }
            .width(34).height(34)
            .backgroundColor('#A6FFFFFF')
            .border({ width: 1, color: '#99FFB3CE' })
          }
          .width('100%')
          .margin({ bottom: 18 })

          // 头像 + 信息
          Row() {
            Monogram({ iconSize: 72 })
            Column() {
              Text('Elysia · 同学')
                .fontSize(24)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
              Text('软件学院 · 软件工程 2304')
                .fontSize(11)
                .fontColor(ElysiaTheme.INK_SOFT)
                .margin({ top: 2 })
              Text('SID · 20231104')
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
            this.StatBlock('06', '待评教')
            this.StatBlock('02', '待办')
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .backgroundColor('#A6FFFFFF')
          .borderRadius(16)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 22 })
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_200, 0], ['#FFE4EE', 0.6], ['#00FFFFFF', 1]]
        })

        Scroll() {
          Column() {
            // 八宫格
            Grid() {
              ForEach(this.quickItems, (it: QuickItem) => {
                GridItem() {
                  Column() {
                    Stack() {
                      Text(it.icon).fontSize(18).fontColor(ElysiaTheme.ROSE_700)
                    }
                    .width(46).height(46)
                    .borderRadius(14)
                    .linearGradient({
                      angle: 135,
                      colors: [[Color.White, 0], [ElysiaTheme.ROSE_100, 1]]
                    })
                    .border({ width: 1, color: '#80FFB3CE' })
                    Text(it.label)
                      .fontSize(10)
                      .fontColor(ElysiaTheme.INK_SOFT)
                      .margin({ top: 6 })
                  }
                  .onClick(() => {
                    if (it.route) router.pushUrl({ url: it.route });
                  })
                }
              })
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

      ElysiaTabBar({ active: 'mine' })
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
            Text(it.icon)
              .fontSize(14)
              .fontColor(it.danger ? ElysiaTheme.ROSE_700 : ElysiaTheme.ROSE_700)
          }
          .width(34).height(34)
          .borderRadius(11)
          .linearGradient({
            angle: 135,
            colors: it.danger
              ? [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.ROSE_200, 1]]
              : [[Color.White, 0], [ElysiaTheme.LAV_200, 1]]
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
              .onChange((v: boolean) => { this.darkMode = v; })
          } else {
            Text('›').fontSize(14).fontColor(ElysiaTheme.INK_MUTE)
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        if (idx !== undefined && idx < items.length - 1) {
          Divider().strokeWidth(1).color('#80FFB3CE')
        }
      })
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
