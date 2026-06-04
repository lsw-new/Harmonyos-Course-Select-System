// 考试详情 · Exam Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { ExamArrangement } from '../models/Academic';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct ExamDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State exam: ExamArrangement | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.ExamDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少考试 ID';
      this.loading = false;
      return;
    }
    AcademicRepository.get().getExams().then((items: ExamArrangement[]) => {
      const found: ExamArrangement | undefined = items.find((e: ExamArrangement) => e.id === id);
      if (found === undefined) {
        this.errorMsg = '考试安排不存在';
      } else {
        this.exam = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(84)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder MetricCard(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontStyle(FontStyle.Italic)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label)
        .fontSize(10)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .height(70)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() })
    .borderRadius(18)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.examdetail_title'), subtitle: $r('app.string.examdetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.exam !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 渐变卡
              Column({ space: 8 }) {
                Pill({ text: this.exam!.examType })
                Text(`${this.exam!.courseName} · ${this.exam!.examType}`)
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.INK)
                  .lineHeight(26)
                Text(this.exam!.term)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(18)
              .borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡（日期 / 时间 / 座位）
              Row({ space: 10 }) {
                this.MetricCard('日期', this.exam!.date, ElysiaTheme.ROSE_500)
                this.MetricCard('时间', `${this.exam!.startTime}–${this.exam!.endTime}`, ElysiaTheme.LAV_500)
                this.MetricCard('座位', this.exam!.seatNo ?? '—', ElysiaTheme.GOLD_500)
              }.width('100%')

              // 详细信息卡
              Column() {
                Text($r('app.string.examdetail_section_info'))
                  .fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('考试日期', this.exam!.date)
                this.InfoRow('开始时间', this.exam!.startTime)
                this.InfoRow('结束时间', this.exam!.endTime)
                this.InfoRow('考场', this.exam!.classroom)
                this.InfoRow('座位号', this.exam!.seatNo ?? '—')
                this.InfoRow('学期', this.exam!.term)
                this.InfoRow('考试类型', this.exam!.examType)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 考试须知（若存在）
              if (this.exam!.notice !== undefined && this.exam!.notice!.length > 0) {
                Column() {
                  Row({ space: 6 }) {
                    Text($r('app.string.examdetail_section_notice'))
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                    Pill({ text: $r('app.string.examdetail_pill_important') })
                  }.margin({ bottom: 8 })
                  Text(this.exam!.notice!)
                    .fontSize(13)
                    .fontColor(ElysiaTheme.INK_SOFT)
                    .lineHeight(20)
                    .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(ElysiaTheme.SURFACE)
                .borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.examdetail_btn_add_schedule'), onTap: () => Toast.show(this.getUIContext(), '已加入日程') })
                PrimaryButton({ text: $r('app.string.examdetail_btn_admission'), onTap: () => Toast.show(this.getUIContext(), '准考证功能即将上线') })
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
export function ExamDetailPageBuilder() {
  NavDestination() {
    ExamDetailPage()
  }
  .hideTitleBar(true)
}
