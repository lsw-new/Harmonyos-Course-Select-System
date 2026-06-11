// 今日课程 · Today
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { CourseRepository } from '../repositories/CourseRepository';
import { CourseLogic } from '../repositories/CourseLogic';
import { ScheduleItem } from '../models/Course';
import { TermUtils } from '../common/utils/TermUtils';

// Convert JS getDay() (0=Sun..6=Sat) to mock weekday encoding (1=Mon..7=Sun)
function toWeekday(jsDay: number): number {
  return jsDay === 0 ? 7 : jsDay;
}

// 当前教学周：按真实日期动态计算，与 CourseRepository 默认周 / 首页 term.weekIndex 同口径，
// 使“今天/明天/本周”三个 tab 取自同一合并课表（导入课表 + 已选课程）。
const CURRENT_TEACHING_WEEK: number = TermUtils.teachingWeek();

@Component
struct TodayPage {
  @State courses: ScheduleItem[] = [];
  @State activeTab: number = 0;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  // 底部手势条避让（vp）：List 无 TabBar 兜底，需自行留出底部安全区。
  @StorageProp('safeBottom') safeBottom: number = 0;
  @StorageProp('breakpoint') bp: string = 'sm';

  // 当前时刻（当日分钟数）：「今天」tab 判定已上完/进行中用，加载时刷新
  @State nowMinutes: number = 0;

  private todayWeekday: number = toWeekday(new Date().getDay());
  private tomorrowWeekday: number = toWeekday((new Date().getDay() + 1) % 7);

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Today)) {
      return;
    }
    this.loadData();
  }

  // 课程进行状态：仅「今天」tab 按真实时刻判定；明天/本周一律按未开始展示
  private lessonStatusOf(c: ScheduleItem): string {
    if (this.activeTab !== 0) {
      return 'upcoming';
    }
    return CourseLogic.lessonStatus(c, this.nowMinutes);
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    const d = new Date();
    this.nowMinutes = d.getHours() * 60 + d.getMinutes();
    this.errorMsg = '';
    let promise: Promise<ScheduleItem[]>;
    if (this.activeTab === 0) {
      promise = CourseRepository.get().getTodayCourses(this.todayWeekday, CURRENT_TEACHING_WEEK);
    } else if (this.activeTab === 1) {
      promise = CourseRepository.get().getTodayCourses(this.tomorrowWeekday, CURRENT_TEACHING_WEEK);
    } else {
      // 本周：合并后的整周课表，按当前教学周过滤，与今天/明天 tab 同源同周。
      promise = CourseRepository.get().getSchedule(undefined, CURRENT_TEACHING_WEEK);
    }
    promise
      .then((res: ScheduleItem[]) => {
        // 今天/明天按真实上课时间升序；本周保持课表原序（跨星期混排无意义）
        this.courses = this.activeTab === 2 ? res : CourseLogic.sortByLessonTime(res);
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
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
        TopBar({ title: $r('app.string.today_title'), subtitle: $r('app.string.today_subtitle'), onBack: () => AppRoute.back() })

        Column() {
          Scroll() {
            Row({ space: 6 }) {
              ForEach(['今天', '明天', '本周'], (t: string, i?: number) => {
                Button(t).height(28).fontSize(11).padding({ left: 14, right: 14 })
                  .borderRadius(999)
                  .fontColor((i ?? 0) === this.activeTab ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor((i ?? 0) === this.activeTab ? '' : ElysiaTheme.glass())
                  .linearGradient((i ?? 0) === this.activeTab
                    ? { angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]] }
                    : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .border({ width: (i ?? 0) === this.activeTab ? 0 : 1, color: ElysiaTheme.hairline() })
                  .onClick(() => {
                    this.activeTab = i ?? 0;
                    this.loadData();
                  })
              }, (t: string) => t)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, bottom: 14 })

          if (this.loading) {
            LoadingState({ tip: $r('app.string.today_loading') })
          } else if (this.errorMsg.length > 0) {
            ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
          } else if (this.courses.length === 0) {
            EmptyState({ icon: 'petal', title: $r('app.string.today_empty') })
          } else {
            List({ space: 12 }) {
              ForEach(this.courses, (c: ScheduleItem) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(CourseLogic.realStartTime(c.periodStart, c.classroom) || c.startTime)
                        .fontSize(14).fontStyle(FontStyle.Italic)
                        .fontColor(this.lessonStatusOf(c) === 'finished' ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_700)
                        .fontFamily(ElysiaTheme.FONT_DISPLAY)
                      Text(CourseLogic.realEndTime(c.periodEnd, c.classroom) || c.endTime)
                        .fontSize(9).fontColor(ElysiaTheme.INK_MUTE)
                    }
                    .width(50).alignItems(HorizontalAlign.End)

                    Stack().width(9).height(9).borderRadius(5)
                      .backgroundColor(this.lessonStatusOf(c) === 'finished' ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                      .margin({ left: 8, right: 8 })

                    Column() {
                      Text(c.courseName).fontSize(13).fontWeight(FontWeight.Bold)
                        .fontColor(this.lessonStatusOf(c) === 'finished' ? ElysiaTheme.INK_MUTE : ElysiaTheme.INK)
                      Row() {
                        AppIcon({ name: 'pin', iconSize: 12, dim: this.lessonStatusOf(c) === 'finished' })
                        Text(c.classroom + ' · ' + c.teacher).fontSize(11)
                          .fontColor(this.lessonStatusOf(c) === 'finished' ? ElysiaTheme.INK_MUTE : ElysiaTheme.INK_SOFT)
                          .margin({ left: 4 })
                      }.margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                    if (this.lessonStatusOf(c) === 'finished') {
                      Pill({ text: $r('app.string.home_lesson_done'), bg: '#EFECEE', color: ElysiaTheme.INK_MUTE })
                    } else if (this.lessonStatusOf(c) === 'ongoing') {
                      Pill({ text: $r('app.string.home_lesson_ongoing'), bg: '#FFE4EE', color: ElysiaTheme.ROSE_700 })
                    } else {
                      Pill({ text: c.courseType })
                    }
                  }
                  .width('100%').padding(12)
                  .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                  .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
                  .opacity(this.lessonStatusOf(c) === 'finished' ? 0.62 : 1)
                  .onClick(() => {
                    let p: Record<string, Object> = { 'id': c.courseId };
                    let opts: NavigateOptions = { params: p };
                    AppRoute.go(Routes.CourseDetail, opts);
                  })
                }
              }, (c: ScheduleItem) => c.id)
            }
            .scrollBar(BarState.Off)
            .padding({ left: 16, right: 16, bottom: this.safeBottom + 24 })
            .layoutWeight(1)
          }
        }.layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TodayPageBuilder() {
  NavDestination() {
    TodayPage()
  }
  .hideTitleBar(true)
}
