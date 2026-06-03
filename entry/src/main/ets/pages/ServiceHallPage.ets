// 办事大厅 · 学生端服务入口聚合（需学生守卫）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

class ServiceTile {
  icon: string = '';
  label: string = '';
  route: string = '';
  constructor(icon: string, label: string, route: string) {
    this.icon = icon;
    this.label = label;
    this.route = route;
  }
}

@Component
struct ServiceHallPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  private tiles: ServiceTile[] = [
    new ServiceTile('leave', '请假申请', Routes.Leave),
    new ServiceTile('feedback', '意见反馈', Routes.Feedback),
    new ServiceTile('practice', '实践管理', Routes.Practice),
    new ServiceTile('grades', '成绩查询', Routes.Grades),
    new ServiceTile('exam', '考试安排', Routes.Exam),
    new ServiceTile('roster', '学籍信息', Routes.Roster),
    new ServiceTile('schedule', '我的课表', Routes.Schedule),
    new ServiceTile('selection', '选课中心', Routes.Selection),
    new ServiceTile('evaluation', '教学评价', Routes.Eval),
    new ServiceTile('notice', '通知公告', Routes.Notices),
    new ServiceTile('calendar', '今日待办', Routes.Today)
  ];

  aboutToAppear(): void {
    AppRoute.guard(Routes.ServiceHall);
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '办事大厅', subtitle: '办 事 大 厅', onBack: () => { AppRoute.back(); } })

        Scroll() {
          Column() {
            RoseDivider({ label: '常 用 服 务' })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.tiles, (it: ServiceTile) => {
                this.ServiceCard(it)
              }, (it: ServiceTile) => it.route + it.label)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })

            Text('更多线下事务请前往教务处办理')
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })

            SafeBottom()
          }
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }

  @Builder ServiceCard(it: ServiceTile) {
    Column() {
      Stack() {
        AppIcon({ name: it.icon, iconSize: 26 })
      }
      .width(52).height(52)
      .borderRadius(16)
      .linearGradient({ angle: 135, colors: [[ElysiaTheme.SURFACE, 0], [ElysiaTheme.ROSE_100, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairline() })

      Text(it.label)
        .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 8 })
    }
    .width('33%')
    .padding({ top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(it.label)
    .onClick(() => { AppRoute.go(it.route); })
  }
}

// 系统路由表构建函数
@Builder
export function ServiceHallPageBuilder() {
  NavDestination() {
    ServiceHallPage()
  }
  .hideTitleBar(true)
}
