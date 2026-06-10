// 考试安排 · Exams
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { ExamArrangement } from '../models/Academic';
import { DateUtils } from '../common/utils/DateUtils';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { SysConfigRepository } from '../repositories/SysConfigRepository';
import { CalendarEvent } from '../models/SysConfigModels';

@Component
struct ExamPage {
  @State exams: ExamArrangement[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  // 校历节点（真实校历：期末考试/假期/实践周等，取今天起的前 4 条）
  @State calEvents: CalendarEvent[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Exam)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    AcademicRepository.get().getExams()
      .then((res: ExamArrangement[]) => {
        this.exams = res;
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
    // 校历节点独立加载，失败静默（不影响考试列表）
    SysConfigRepository.get().getCalendarEvents().then((events: CalendarEvent[]) => {
      const today = DateUtils.today();
      this.calEvents = events
        .filter((ev) => ev.date >= today)
        .sort((a, b) => a.date < b.date ? -1 : 1)
        .slice(0, 4);
    }).catch(() => undefined);
  }

  private calTypeColor(type: string): string {
    if (type === 'exam') {
      return '#D9B675';
    }
    if (type === 'holiday') {
      return '#3FAE7A';
    }
    if (type === 'term') {
      return '#F2709C';
    }
    return '#B589FF';
  }

  // Pick the soonest upcoming exam (date >= today), fallback to exams[0]
  private heroExam(): ExamArrangement {
    const today = DateUtils.today();
    const sorted = this.exams.slice().sort((a: ExamArrangement, b: ExamArrangement) => {
      return a.date < b.date ? -1 : a.date > b.date ? 1 : 0;
    });
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].date >= today) {
        return sorted[i];
      }
    }
    return sorted[0];
  }

  // Extract month number from 'yyyy-MM-dd'
  private examMonth(date: string): string {
    const MONTHS = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    const parts = date.split('-');
    if (parts.length >= 2) {
      const m = parseInt(parts[1], 10);
      if (m >= 1 && m <= 12) {
        return MONTHS[m - 1];
      }
    }
    return '—';
  }

  // Extract day-of-month from 'yyyy-MM-dd'
  private examDay(date: string): string {
    const parts = date.split('-');
    if (parts.length >= 3) {
      return parts[2];
    }
    return '—';
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.exam_title'), subtitle: $r('app.string.exam_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: $r('app.string.exam_loading') })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.exams.length === 0) {
          EmptyState({ title: $r('app.string.exam_empty') })
        } else {
          Scroll() {
            Column() {
              // 校历 · 学期节点（真实校历横滑卡：期末考试/假期/实践周）
              if (this.calEvents.length > 0) {
                Column() {
                  Text($r('app.string.exam_calendar_section'))
                    .fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                    .width('100%').margin({ bottom: 8 })
                  Scroll() {
                    Row({ space: 10 }) {
                      ForEach(this.calEvents, (ev: CalendarEvent) => {
                        Column() {
                          Text(ev.date.substring(5))
                            .fontSize(15).fontWeight(FontWeight.Bold)
                            .fontColor(this.calTypeColor(ev.type))
                          Text(ev.title)
                            .fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
                            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                            .margin({ top: 4 })
                        }
                        .width(132).padding(12)
                        .alignItems(HorizontalAlign.Start)
                        .backgroundColor(ElysiaTheme.SURFACE)
                        .borderRadius(14)
                        .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                      }, (ev: CalendarEvent) => ev.id)
                    }
                  }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
                }.width('100%').margin({ bottom: 14 })
              }

              // Hero 卡片：最近即将到来的考试
              Column() {
                Pill({ text: `距下场 · ${DateUtils.daysBetween(DateUtils.today(), this.heroExam().date)} 天` })
                Text(`${this.heroExam().courseName} · ${this.heroExam().examType}`)
                  .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 6 })
                Row({ space: 12 }) {
                  Column() {
                    Text($r('app.string.exam_label_date')).fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    Text(this.heroExam().date)
                      .fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 3 })
                  }
                  Column() {
                    Text($r('app.string.exam_label_time')).fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    Text(`${this.heroExam().startTime}–${this.heroExam().endTime}`)
                      .fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 3 })
                  }
                }.margin({ top: 14 }).alignItems(VerticalAlign.Top)
                Row({ space: 12 }) {
                  Column() {
                    Text($r('app.string.exam_label_room')).fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    Text(this.heroExam().classroom)
                      .fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 3 })
                  }
                  Column() {
                    Text($r('app.string.exam_label_seat')).fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    Text(`${this.heroExam().seatNo ?? '—'}`)
                      .fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 3 })
                  }
                }.margin({ top: 10 }).alignItems(VerticalAlign.Top)
              }
              .width('100%').alignItems(HorizontalAlign.Start)
              .padding(16).borderRadius(22)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })

              // 列表
              Column({ space: 10 }) {
                ForEach(this.exams, (e: ExamArrangement) => {
                  Row() {
                    Column() {
                      Text(this.examMonth(e.date))
                        .fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                      Text(this.examDay(e.date))
                        .fontSize(22).fontStyle(FontStyle.Italic)
                        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                      Text(e.examType)
                        .fontSize(9).fontColor(ElysiaTheme.ROSE_700).margin({ top: 3 })
                    }
                    .width(60).padding({ top: 8, bottom: 8 }).borderRadius(14)
                    .alignItems(HorizontalAlign.Center)
                    .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_100, 0], ['#F1E2FF', 1]] })

                    Column() {
                      Row() {
                        Text(e.courseName)
                          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
                        Pill({ text: e.examType })
                      }
                      Row() {
                        AppIcon({ name: 'time', iconSize: 12 })
                        Text(`${e.startTime}–${e.endTime}`)
                          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ left: 4 })
                      }.margin({ top: 6 })
                      Row() {
                        AppIcon({ name: 'pin', iconSize: 12 })
                        Text(e.classroom).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ left: 4 })
                        AppIcon({ name: 'tag', iconSize: 12, mLeft: 8 })
                        Text(`座位 ${e.seatNo ?? '—'}`)
                          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ left: 4 })
                      }.margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
                  }
                  .width('100%').padding(14)
                  .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                  .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
                  .onClick(() => { const p: Record<string, Object> = { 'id': e.id }; AppRoute.go(Routes.ExamDetail, { params: p }); })
                }, (e: ExamArrangement) => e.id)
              }
              .margin({ top: 14 })
              SafeBottom()
            }
            .padding({ left: 16, right: 16 })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function ExamPageBuilder() {
  NavDestination() {
    ExamPage()
  }
  .hideTitleBar(true)
}
