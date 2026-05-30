// 今日课程 · Today
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { CourseRepository } from '../repositories/CourseRepository';
import { ScheduleItem } from '../models/Course';

// Convert JS getDay() (0=Sun..6=Sat) to mock weekday encoding (1=Mon..7=Sun)
function toWeekday(jsDay: number): number {
  return jsDay === 0 ? 7 : jsDay;
}

@Entry
@Component
struct TodayPage {
  @State courses: ScheduleItem[] = [];
  @State activeTab: number = 0;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  // 底部手势条避让（vp）：List 无 TabBar 兜底，需自行留出底部安全区。
  @StorageProp('safeBottom') safeBottom: number = 0;

  private todayWeekday: number = toWeekday(new Date().getDay());
  private tomorrowWeekday: number = toWeekday((new Date().getDay() + 1) % 7);

  aboutToAppear(): void {
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    let promise: Promise<ScheduleItem[]>;
    if (this.activeTab === 0) {
      promise = CourseRepository.get().getTodayCourses(this.todayWeekday);
    } else if (this.activeTab === 1) {
      promise = CourseRepository.get().getTodayCourses(this.tomorrowWeekday);
    } else {
      promise = CourseRepository.get().getSchedule(undefined, undefined);
    }
    promise
      .then((res: ScheduleItem[]) => {
        this.courses = res;
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: 'Today', subtitle: '今 日 课 程', onBack: () => AppRoute.back() })

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
            LoadingState({ tip: '正在加载课程...' })
          } else if (this.errorMsg.length > 0) {
            ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
          } else if (this.courses.length === 0) {
            EmptyState({ icon: 'petal', title: '今日无课' })
          } else {
            List({ space: 12 }) {
              ForEach(this.courses, (c: ScheduleItem) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(c.startTime).fontSize(14).fontStyle(FontStyle.Italic)
                        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                      Text(c.endTime).fontSize(9).fontColor(ElysiaTheme.INK_MUTE)
                    }
                    .width(50).alignItems(HorizontalAlign.End)

                    Stack().width(9).height(9).borderRadius(5)
                      .backgroundColor(ElysiaTheme.ROSE_500).margin({ left: 8, right: 8 })

                    Column() {
                      Text(c.courseName).fontSize(13).fontWeight(FontWeight.Bold)
                        .fontColor(ElysiaTheme.INK)
                      Row() {
                        AppIcon({ name: 'pin', iconSize: 12 })
                        Text(c.classroom + ' · ' + c.teacher).fontSize(11)
                          .fontColor(ElysiaTheme.INK_SOFT).margin({ left: 4 })
                      }.margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                    Pill({ text: c.courseType })
                  }
                  .width('100%').padding(12)
                  .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                  .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
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
    }
    .width('100%').height('100%')
  }
}
