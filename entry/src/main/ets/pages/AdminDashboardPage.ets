// 仪表盘 · Tableau
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider, GlowCard } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminDashboardSummary, DashboardStatCard, TrendPoint, DistributionItem, ApprovalItem } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct AdminDashboardPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State dashboard: AdminDashboardSummary | null = null;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminDashboard)) return;
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
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

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: 'Tableau', subtitle: '管 理 仪 表 盘', showBack: false })

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
                        Text(`${card.delta! > 0 ? '+' : ''}${card.delta}`).fontSize(10).fontColor(card.delta! > 0 ? '#7BB07B' : '#D8546B')
                      }
                    }.width('100%').padding(12).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).alignItems(HorizontalAlign.Center)
                  }
                }, (card: DashboardStatCard) => card.key)
              }
              .columnsTemplate('1fr 1fr').rowsGap(10).columnsGap(10).width('100%')

              // 选课趋势
              Column() {
                Text('选课趋势').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
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
                Text('课程类型分布').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
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
                  Text('待办审批').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                  Text('查看全部 ›').fontSize(11).fontColor(ElysiaTheme.ROSE_500)
                    .onClick(() => { AppRoute.go(Routes.AdminApprovals); })
                }.width('100%').margin({ bottom: 8 })
                ForEach(this.dashboard!.pendingApprovals, (a: ApprovalItem) => {
                  Row() {
                    Column() {
                      Text(a.title).fontSize(13).fontColor(ElysiaTheme.INK)
                      Text(`${a.applicantName} · ${a.submittedAt}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    if (a.isUrgent) { Pill({ text: '紧急', color: '#D8546B', bg: '#FFF0F0' }) }
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
      }
    }.width('100%').height('100%')
  }
}
