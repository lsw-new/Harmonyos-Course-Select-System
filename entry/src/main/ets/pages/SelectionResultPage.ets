// 我的选课 · Selection Result
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { SelectionCourse, SelectionRoundInfo } from '../models/Course';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct SelectionResultPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State courses: SelectionCourse[] = [];
  @State round: SelectionRoundInfo | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.SelectionResult)) {
      return;
    }
    const repo = CourseRepository.get();
    Promise.all([
      repo.getMySelectedCourses(),
      repo.getSelectionRound()
    ]).then((res: [SelectionCourse[], SelectionRoundInfo]) => {
      this.courses = res[0];
      this.round = res[1];
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private statusColor(status: string): string {
    if (status === 'selected') {
      return '#3E8E5E';
    }
    if (status === 'full') {
      return ElysiaTheme.INK_MUTE;
    }
    if (status === 'conflict') {
      return ElysiaTheme.ROSE_700;
    }
    return ElysiaTheme.ROSE_500;
  }

  private statusBg(status: string): string {
    if (status === 'selected') {
      return '#E6F5EC';
    }
    if (status === 'full') {
      return '#F0F0F0';
    }
    if (status === 'conflict') {
      return '#FFEBEE';
    }
    return '#FFF0F4';
  }

  private statusLabel(status: string): string {
    if (status === 'selected') {
      return '已选';
    }
    if (status === 'full') {
      return '已满';
    }
    if (status === 'conflict') {
      return '冲突';
    }
    return status;
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.selresult_title'), subtitle: $r('app.string.selresult_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // Hero：轮次信息
              if (this.round !== null) {
                Column({ space: 10 }) {
                  Pill({ text: this.round!.inProgress ? $r('app.string.selresult_round_active') : $r('app.string.selresult_round_closed') })
                  Text(this.round!.roundName)
                    .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                    .lineHeight(26)
                  Text(`${this.round!.startTime} — ${this.round!.endTime}`)
                    .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
                }
                .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
                .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

                // 指标卡：已选学分 / 学分上限 / 已选门数
                Row({ space: 10 }) {
                  this.MetricCard(`${this.round!.selectedCredits}`, '已选学分', ElysiaTheme.ROSE_500)
                  this.MetricCard(`${this.round!.creditLimit}`, '学分上限', ElysiaTheme.GOLD_700)
                  this.MetricCard(`${this.courses.length}`, '已选门数', ElysiaTheme.LAV_500)
                }.width('100%')
              }

              // 课程列表
              if (this.courses.length === 0) {
                EmptyState({ title: $r('app.string.selresult_empty') })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.courses, (sc: SelectionCourse) => {
                    this.CourseCard(sc)
                  }, (sc: SelectionCourse) => sc.course.id)
                }.width('100%')
              }

              // 底部操作按钮
              if (this.courses.length > 0) {
                Row({ space: 12 }) {
                  GhostButton({
                    text: $r('app.string.selresult_btn_export'),
                    onTap: () => { Toast.show(this.getUIContext(), '导出功能即将上线'); }
                  })
                  PrimaryButton({
                    text: $r('app.string.selresult_btn_detail'),
                    onTap: () => {
                      const first = this.courses[0];
                      const p: Record<string, Object> = { 'id': first.course.id };
                      AppRoute.go(Routes.CourseDetail, { params: p });
                    }
                  })
                }.width('100%')
              }

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }

  @Builder MetricCard(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label)
        .fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
    }
    .layoutWeight(1).height(70)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() })
    .borderRadius(18)
  }

  @Builder CourseCard(sc: SelectionCourse) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(38).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(sc.course.name)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Pill({ text: this.statusLabel(sc.status), bg: this.statusBg(sc.status), color: this.statusColor(sc.status) })
        }
        Text(`${sc.course.code} · ${sc.course.teacher} · ${sc.course.credit} 学分`)
          .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
        if (sc.conflictWith !== undefined && sc.conflictWith!.length > 0) {
          Text(sc.conflictWith!)
            .fontSize(11).fontColor(ElysiaTheme.ROSE_700).lineHeight(16)
        }
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
  }
}

@Builder
export function SelectionResultPageBuilder() {
  NavDestination() {
    SelectionResultPage()
  }
  .hideTitleBar(true)
}
