// 请假详情 · Leave Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { LeaveRequest } from '../models/Misc';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct LeaveDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State leave: LeaveRequest | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.LeaveDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少请假 ID';
      this.loading = false;
      return;
    }
    ProfileRepository.get().getLeaveRequests().then((list: LeaveRequest[]) => {
      const found: LeaveRequest | undefined = list.find((r: LeaveRequest) => r.id === id);
      if (found === undefined) {
        this.errorMsg = '请假记录不存在';
      } else {
        this.leave = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private typeLabel(type: string): string {
    if (type === 'sick') return '病假';
    if (type === 'personal') return '事假';
    if (type === 'public') return '公假';
    return '其他';
  }

  private stateLabel(state: string): string {
    if (state === 'approved') return '已通过';
    if (state === 'rejected') return '已驳回';
    if (state === 'pending') return '审批中';
    return '已撤回';
  }

  private stateColor(state: string): string {
    if (state === 'approved') return ElysiaTheme.SUCCESS;
    if (state === 'rejected') return ElysiaTheme.ROSE_ACCENT;
    if (state === 'pending') return '#D9B675';
    return ElysiaTheme.INK_MUTE;
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder StepItem(stepTitle: string, stepDesc: string, tag: string, active: boolean) {
    Row({ space: 10 }) {
      Column()
        .width(10)
        .height(38)
        .borderRadius(6)
        .linearGradient({
          angle: 180,
          colors: active
            ? [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]]
            : [['#E0E0E0', 0], ['#C8C8C8', 1]]
        })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(stepTitle).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Pill({ text: tag })
        }
        Text(stepDesc).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.leavedetail_title'), subtitle: $r('app.string.leavedetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.leave !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区：申请摘要
              Column({ space: 10 }) {
                Pill({ text: this.typeLabel(this.leave!.type) })
                Text(`${this.leave!.startDate} ~ ${this.leave!.endDate}`)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(this.leave!.reason || '—')
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                Column() {
                  Text(this.stateLabel(this.leave!.state))
                    .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(this.stateColor(this.leave!.state)).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.leavedetail_metric_state')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(this.typeLabel(this.leave!.type))
                    .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.leavedetail_metric_type')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(`${this.leave!.attachments.length}`)
                    .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.leavedetail_metric_attachment')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
              }.width('100%')

              // 申请详情
              Column() {
                Text($r('app.string.leavedetail_section_content')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('假别', this.typeLabel(this.leave!.type))
                this.InfoRow('开始日期', this.leave!.startDate)
                this.InfoRow('结束日期', this.leave!.endDate)
                this.InfoRow('提交时间', this.leave!.submittedAt)
                this.InfoRow('请假事由', this.leave!.reason || '—')
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 审批进度时间线
              Column({ space: 10 }) {
                Text($r('app.string.leavedetail_section_progress')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.StepItem('申请提交', `${this.leave!.submittedAt} · 已提交`, '完成', true)
                this.StepItem(
                  '审批处理',
                  this.leave!.state === 'pending' ? '等待审批中' :
                    (this.leave!.state === 'approved' ? '已通过' :
                      (this.leave!.state === 'rejected' ? '已驳回' : '已撤回')),
                  this.stateLabel(this.leave!.state),
                  this.leave!.state !== 'pending'
                )
              }.width('100%')

              // 审批反馈（若有）
              if (this.leave!.feedback !== undefined && this.leave!.feedback!.length > 0) {
                Column() {
                  Text($r('app.string.leavedetail_section_feedback')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
                  Text(this.leave!.feedback!)
                    .fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({
                  text: $r('app.string.leavedetail_btn_withdraw'),
                  onTap: () => Toast.show(this.getUIContext(), '撤回功能暂未开放')
                })
                PrimaryButton({
                  text: $r('app.string.leavedetail_btn_supplement'),
                  onTap: () => Toast.show(this.getUIContext(), '补充材料功能暂未开放')
                })
              }.width('100%')

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function LeaveDetailPageBuilder() {
  NavDestination() {
    LeaveDetailPage()
  }
  .hideTitleBar(true)
}
