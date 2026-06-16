// 反馈详情 · Feedback Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { FeedbackItem } from '../models/Misc';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct FeedbackDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State feedback: FeedbackItem | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.FeedbackDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少反馈 ID';
      this.loading = false;
      return;
    }
    ProfileRepository.get().getFeedback().then((list: FeedbackItem[]) => {
      const found: FeedbackItem | undefined = list.find((f: FeedbackItem) => f.id === id);
      if (found === undefined) {
        this.errorMsg = '反馈记录不存在';
      } else {
        this.feedback = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private catLabel(category: string): string {
    if (category === 'bug') return 'Bug';
    if (category === 'suggestion') return '建议';
    if (category === 'service') return '服务';
    return '其他';
  }

  private stateLabel(state: string): string {
    if (state === 'submitted') return '已提交';
    if (state === 'processing') return '处理中';
    return '已关闭';
  }

  private stateColor(state: string): string {
    if (state === 'submitted') return ElysiaTheme.ROSE_500;
    if (state === 'processing') return '#D9B675';
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
        TopBar({ title: $r('app.string.feedbackdetail_title'), subtitle: $r('app.string.feedbackdetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.feedback !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区：反馈标题与类型
              Column({ space: 10 }) {
                Pill({ text: this.catLabel(this.feedback!.category) })
                Text(this.feedback!.title)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(this.feedback!.submittedAt)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                Column() {
                  Text(this.stateLabel(this.feedback!.state))
                    .fontSize(15).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(this.stateColor(this.feedback!.state)).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.feedbackdetail_metric_state')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(this.catLabel(this.feedback!.category))
                    .fontSize(15).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.feedbackdetail_metric_type')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(`${this.feedback!.screenshots.length}`)
                    .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text($r('app.string.feedbackdetail_metric_screenshot')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
              }.width('100%')

              // 反馈详情
              Column() {
                Text($r('app.string.feedbackdetail_section_content')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('类型', this.catLabel(this.feedback!.category))
                this.InfoRow('标题', this.feedback!.title)
                this.InfoRow('联系方式', this.feedback!.contact || '—')
                this.InfoRow('提交时间', this.feedback!.submittedAt)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 反馈正文
              Column() {
                Text($r('app.string.feedbackdetail_section_desc')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
                Text(this.feedback!.content)
                  .fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 受理进度时间线
              Column({ space: 10 }) {
                Text($r('app.string.feedbackdetail_section_progress')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.StepItem('反馈提交', `${this.feedback!.submittedAt} · 已提交`, '已提交', true)
                this.StepItem(
                  '服务台受理',
                  this.feedback!.state === 'submitted' ? '等待受理' : '已分派处理',
                  this.feedback!.state === 'submitted' ? '待受理' : '处理中',
                  this.feedback!.state !== 'submitted'
                )
                this.StepItem(
                  '处理完结',
                  this.feedback!.state === 'closed' ? '反馈已关闭' : '等待处理回复',
                  this.feedback!.state === 'closed' ? '已关闭' : '待完结',
                  this.feedback!.state === 'closed'
                )
              }.width('100%')

              // 管理员回复（有回复时展示）
              if ((this.feedback!.reply ?? '').length > 0) {
                Column({ space: 6 }) {
                  Text('管理员回复').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                  Text(`${this.feedback!.repliedByName ?? '管理员'} · ${this.feedback!.repliedAt ?? ''}`)
                    .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  Text(this.feedback!.reply!)
                    .fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20).margin({ top: 4 })
                }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
                .backgroundColor('#FFF7FA').borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({
                  text: $r('app.string.feedbackdetail_btn_close'),
                  onTap: () => Toast.show(this.getUIContext(), '关闭反馈功能暂未开放')
                })
                PrimaryButton({
                  text: $r('app.string.feedbackdetail_btn_append'),
                  onTap: () => Toast.show(this.getUIContext(), '追加说明功能暂未开放')
                })
              }.width('100%')

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function FeedbackDetailPageBuilder() {
  NavDestination() {
    FeedbackDetailPage()
  }
  .hideTitleBar(true)
}
