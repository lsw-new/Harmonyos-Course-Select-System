// 我的课表 · Schedule
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { CourseRepository } from '../repositories/CourseRepository';
import { ScheduleItem } from '../models/Course';

function generateWeekNumbers(): number[] {
  let weeks: number[] = [];
  for (let i = 1; i <= 18; i++) {
    weeks.push(i);
  }
  return weeks;
}

@Entry
@Component
struct SchedulePage {
  @State currentWeek: number = 9;
  @State schedule: ScheduleItem[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @StorageProp('darkMode') darkMode: boolean = false;

  private days: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  aboutToAppear(): void {
    this.loadSchedule();
  }

  private loadSchedule(): void {
    this.loading = true;
    this.errorMsg = '';
    CourseRepository.get().getSchedule(undefined, this.currentWeek)
      .then((res: ScheduleItem[]) => {
        this.schedule = res;
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
          colors: ElysiaTheme.pageGradient(this.darkMode)
        })

      Column() {
        SafeTop()
        TopBar({ title: 'Schedule', subtitle: '我 的 课 表', onBack: () => AppRoute.back() })

        // 周次切换
        Column() {
          Row() {
            Column() {
              Text(`Week ${this.romanize(this.currentWeek)}`)
                .fontSize(18)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
              Text(`2025–2026 秋季 · 第 ${this.currentWeek} 周`)
                .fontSize(10)
                .fontColor(ElysiaTheme.INK_SOFT)
                .letterSpacing(2)
            }
            .alignItems(HorizontalAlign.Start)

            Blank().layoutWeight(1)

            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'back', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor(ElysiaTheme.glassSoft(this.darkMode))
              .border({ width: 1, color: ElysiaTheme.hairline(this.darkMode) })
              .onClick(() => {
                if (this.currentWeek > 1) {
                  this.currentWeek--;
                  this.loadSchedule();
                }
              })
            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'forward', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor(ElysiaTheme.glassSoft(this.darkMode))
              .border({ width: 1, color: ElysiaTheme.hairline(this.darkMode) })
              .margin({ left: 6 })
              .onClick(() => {
                if (this.currentWeek < 18) {
                  this.currentWeek++;
                  this.loadSchedule();
                }
              })
          }

          // 周次滚动条
          Scroll() {
            Row({ space: 5 }) {
              ForEach(generateWeekNumbers(), (w: number) => {
                Button(`${w}`)
                  .height(28)
                  .padding({ left: 10, right: 10 })
                  .fontSize(10)
                  .fontStyle(FontStyle.Italic)
                  .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  .fontColor(w === this.currentWeek ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor(w === this.currentWeek ? '' : ElysiaTheme.glassSoft(this.darkMode))
                  .linearGradient(w === this.currentWeek ? {
                    angle: 135,
                    colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                  } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .borderRadius(999)
                  .border({ width: w === this.currentWeek ? 0 : 1, color: ElysiaTheme.hairline(this.darkMode) })
                  .onClick(() => {
                    this.currentWeek = w;
                    this.loadSchedule();
                  })
              }, (w: number) => `week-${w}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        if (this.loading) {
          LoadingState({ tip: '正在加载课表...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadSchedule() })
        } else {
          // 课表网格
          Scroll() {
            Column() {
              // 表头
              Row() {
                Blank().width(24)
                ForEach(this.days, (d: string, i?: number) => {
                  Column() {
                    Text(d)
                      .fontSize(9)
                      .fontColor(ElysiaTheme.INK_MUTE)
                    Text(`${20 + (i ?? 0)}`)
                      .fontSize(13)
                      .fontStyle(FontStyle.Italic)
                      .fontColor((i === 0) ? ElysiaTheme.ROSE_500 : ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }, (d: string) => d)
              }
              .width('100%')
              .margin({ bottom: 6 })

              // 6 行 × 7 列 (weekday 1=Mon..7=Sun → col index 0=Mon..6=Sun)
              ForEach([0, 1, 2, 3, 4, 5], (row: number) => {
                Row() {
                  // 节次列
                  Column() {
                    Text(`${row * 2 + 1}`)
                      .fontSize(10)
                      .fontStyle(FontStyle.Italic)
                      .fontColor(ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                    Text('·')
                      .fontSize(10)
                      .fontColor(ElysiaTheme.ROSE_300)
                    Text(`${row * 2 + 2}`)
                      .fontSize(10)
                      .fontStyle(FontStyle.Italic)
                      .fontColor(ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  }
                  .width(24)
                  .justifyContent(FlexAlign.Center)

                  // 7 列 (col 0=Mon..6=Sun → weekday = col+1)
                  ForEach([0, 1, 2, 3, 4, 5, 6], (col: number) => {
                    Stack() {
                      this.LessonCell(row * 2 + 1, col + 1)
                    }
                    .layoutWeight(1)
                    .height(64)
                    .margin({ left: 2, right: 2 })
                  }, (col: number) => `col-${row}-${col}`)
                }
                .width('100%')
                .margin({ bottom: 4 })
                .alignItems(VerticalAlign.Center)
              }, (row: number) => `row-${row}`)
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 8 })
        }

        SafeBottom()
      }
    }
    .width('100%').height('100%')
  }

  @Builder LessonCell(period: number, weekday: number) {
    if (this.findLesson(period, weekday) !== undefined) {
      Column() {
        Text(this.findLesson(period, weekday)!.courseName)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .maxLines(2)
        Text(this.findLesson(period, weekday)!.classroom)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .opacity(0.75)
          .margin({ top: 3 })
        Text(this.findLesson(period, weekday)!.teacher)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .opacity(0.6)
          .margin({ top: 1 })
      }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 6, right: 5, top: 6, bottom: 6 })
      .borderRadius(10)
      .linearGradient({
        angle: 160,
        colors: this.hueBg(this.findLesson(period, weekday)!.courseType)
      })
      .onClick(() => {
        const lesson: ScheduleItem | undefined = this.findLesson(period, weekday);
        if (lesson !== undefined) {
          let p: Record<string, Object> = { 'id': lesson.courseId };
          let opts: NavigateOptions = { params: p };
          AppRoute.go(Routes.CourseDetail, opts);
        }
      })
    } else {
      Column()
        .width('100%').height('100%')
        .borderRadius(10)
        .backgroundColor('#66FFFFFF')
        .border({ width: 1, color: '#4DFFB3CE', style: BorderStyle.Dashed })
    }
  }

  findLesson(period: number, weekday: number): ScheduleItem | undefined {
    return this.schedule.find(
      (s: ScheduleItem) => s.weekday === weekday && s.periodStart === period
    );
  }

  hueText(courseType: string): string {
    if (courseType === '选修') return '#6F47A8';
    if (courseType === '公选') return ElysiaTheme.GOLD_700;
    return ElysiaTheme.ROSE_700;
  }

  hueBg(courseType: string): Array<[string, number]> {
    if (courseType === '选修') return [[ElysiaTheme.LAV_200, 0], [ElysiaTheme.LAV_300, 1]];
    if (courseType === '公选') return [['#FFF1D6', 0], [ElysiaTheme.GOLD_300, 1]];
    return [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_300, 1]];
  }

  romanize(n: number): string {
    const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII'];
    return romans[n - 1] || `${n}`;
  }
}
