// 仪表盘 · Tableau
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider, GlowCard } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminDashboardSummary, DashboardStatCard, TrendPoint, DistributionItem, ApprovalItem } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { AuthorizationService } from '../common/security/AuthorizationService';

class AdminModule {
  icon: string = '';
  label: string = '';
  route: string = '';
  permCode: string = '';
  constructor(icon: string, label: string, route: string, permCode: string) {
    this.icon = icon;
    this.label = label;
    this.route = route;
    this.permCode = permCode;
  }
}

@Component
struct AdminDashboardPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State dashboard: AdminDashboardSummary | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  private modules: AdminModule[] = [
    new AdminModule('selection', '选课管理', Routes.AdminSelection, 'selection.manage'),
    new AdminModule('grades', '成绩审核', Routes.AdminGrades, 'grades.approve'),
    new AdminModule('evaluation', '评教管理', Routes.AdminEval, 'evaluation.manage'),
    new AdminModule('notice', '通知发布', Routes.AdminNotice, 'notices.publish')
  ];

  // P2-03：仅展示当前管理员有 view 权限的功能入口（低权限管理员看不到无权模块）
  private visibleModules(): AdminModule[] {
    return this.modules.filter((m: AdminModule) => AuthorizationService.hasAdminPermission(m.permCode, 'view'));
  }

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminDashboard)) return;
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    AdminRepository.get().getDashboard().then((d: AdminDashboardSummary) => {
      this.dashboard = d;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private trendBarHeight(value: number): number {
    if (this.dashboard === null) return 0;
    const trend: TrendPoint[] = this.dashboard!.selectionTrend;
    if (trend.length === 0) return 0;
    const maxV: number = Math.max(...trend.map((pt: TrendPoint) => pt.value));
    if (maxV <= 0) return 0;
    return value / maxV * 80;
  }

  @Builder ModuleCard(m: AdminModule) {
    Column() {
      Stack() {
        AppIcon({ name: m.icon, iconSize: 24 })
      }
      .width(46).height(46).borderRadius(14)
      .linearGradient({ angle: 135, colors: [[ElysiaTheme.SURFACE, 0], [ElysiaTheme.ROSE_100, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairline() })
      Text(m.label).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 6 })
    }
    .width('25%').padding({ top: 6, bottom: 6 }).alignItems(HorizontalAlign.Center)
    .onClick(() => { AppRoute.go(m.route); })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.admindash_title'), subtitle: $r('app.string.admindash_subtitle'), showBack: false })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.dashboard !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // 统计卡片
              Grid() {
                ForEach(this.dashboard!.statCards, (card: DashboardStatCard) => {
                  GridItem() {
                    Column({ space: 4 }) {
                      Text(String(card.value)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(card.color ?? ElysiaTheme.ROSE_500)
                      Text(card.label).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                      if (card.delta !== undefined && card.delta !== 0) {
                        Text(`${card.delta! > 0 ? '+' : ''}${card.delta}`).fontSize(10).fontColor(card.delta! > 0 ? ElysiaTheme.SUCCESS : ElysiaTheme.ROSE_ACCENT)
                      }
                    }.width('100%').padding(12).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).alignItems(HorizontalAlign.Center)
                  }
                }, (card: DashboardStatCard) => card.key)
              }
              .columnsTemplate('1fr 1fr').rowsGap(10).columnsGap(10).width('100%')

              // 管理功能入口
              Column() {
                Text($r('app.string.admindash_modules')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 }).width('100%')
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  ForEach(this.visibleModules(), (m: AdminModule) => {
                    this.ModuleCard(m)
                  }, (m: AdminModule) => m.route)
                }.width('100%')
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 选课趋势
              Column() {
                Text($r('app.string.admindash_trend')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
                Row({ space: 4 }) {
                  ForEach(this.dashboard!.selectionTrend, (p: TrendPoint) => {
                    Column() {
                      Column().width(24).height(this.trendBarHeight(p.value)).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(4)
                      Text(p.label).fontSize(9).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Center)
                  }, (p: TrendPoint) => p.label)
                }.width('100%').height(100).alignItems(VerticalAlign.Bottom)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 课程类型分布
              Column() {
                Text($r('app.string.admindash_dist')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
                ForEach(this.dashboard!.courseTypeDistribution, (item: DistributionItem) => {
                  Row() {
                    Column().width(12).height(12).backgroundColor(item.color ?? ElysiaTheme.ROSE_500).borderRadius(3)
                    Text(item.name).fontSize(12).fontColor(ElysiaTheme.INK).margin({ left: 8 }).layoutWeight(1)
                    Text(String(item.value)).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
                  }.width('100%').padding({ top: 6, bottom: 6 })
                }, (item: DistributionItem) => item.name)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 待办审批
              Column() {
                Row() {
                  Text($r('app.string.admindash_pending')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                  Text($r('app.string.home_view_all')).fontSize(11).fontColor(ElysiaTheme.ROSE_500)
                    .onClick(() => { AppRoute.go(Routes.AdminApprovals); })
                }.width('100%').margin({ bottom: 8 })
                ForEach(this.dashboard!.pendingApprovals, (a: ApprovalItem) => {
                  Row() {
                    Column() {
                      Text(a.title).fontSize(13).fontColor(ElysiaTheme.INK)
                      Text(`${a.applicantName} · ${a.submittedAt}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    if (a.isUrgent) { Pill({ text: $r('app.string.admindash_urgent'), color: ElysiaTheme.ROSE_ACCENT, bg: '#FFF0F0' }) }
                  }.width('100%').padding({ top: 8, bottom: 8 })
                  .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
                  .onClick(() => AppRoute.go(Routes.AdminApprovals))
                }, (a: ApprovalItem) => a.id)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }

        AdminTabBar({ active: 'dashboard', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }.width('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminDashboardPageBuilder() {
  NavDestination() {
    AdminDashboardPage()
  }
  .hideTitleBar(true)
}
