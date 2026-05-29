// 我的课表 · Schedule
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseIcon, ElysiaTabBar } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';

function generateWeekNumbers(): number[] {
  let weeks: number[] = [];
  for (let i = 1; i <= 18; i++) {
    weeks.push(i);
  }
  return weeks;
}

interface Lesson {
  day: number;
  p1: number;
  p2: number;
  name: string;
  room: string;
  teacher: string;
  hue: string;
}

@Entry
@Component
struct SchedulePage {
  @State currentWeek: number = 9;

  private days: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  private lessons: Lesson[] = [
    { day: 0, p1: 1, p2: 2, name: '鸿蒙开发', room: '软305', teacher: '林', hue: 'rose' },
    { day: 0, p1: 3, p2: 4, name: '软件经济学', room: '一教207', teacher: '苏', hue: 'lav' },
    { day: 1, p1: 1, p2: 2, name: '数据库原理', room: '软208', teacher: '李', hue: 'gold' },
    { day: 1, p1: 5, p2: 6, name: '近代史纲要', room: '二教102', teacher: '周', hue: 'rose' },
    { day: 2, p1: 3, p2: 4, name: '操作系统', room: '软301', teacher: '王', hue: 'lav' },
    { day: 3, p1: 1, p2: 2, name: '鸿蒙开发', room: '软305', teacher: '林', hue: 'rose' },
    { day: 3, p1: 5, p2: 6, name: '体育·网球', room: '网球场', teacher: '陈', hue: 'gold' },
    { day: 4, p1: 3, p2: 4, name: '毛中特', room: '一教305', teacher: '郑', hue: 'rose' },
    { day: 5, p1: 1, p2: 2, name: '计网实验', room: '软实验室', teacher: '孙', hue: 'lav' }
  ];

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Schedule', subtitle: '我 的 课 表' })

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
              .backgroundColor('#A6FFFFFF')
              .border({ width: 1, color: '#99FFB3CE' })
              .onClick(() => { if (this.currentWeek > 1) this.currentWeek--; })
            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'forward', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor('#A6FFFFFF')
              .border({ width: 1, color: '#99FFB3CE' })
              .margin({ left: 6 })
              .onClick(() => { if (this.currentWeek < 18) this.currentWeek++; })
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
                  .backgroundColor(w === this.currentWeek ? '' : '#A6FFFFFF')
                  .linearGradient(w === this.currentWeek ? {
                    angle: 135,
                    colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                  } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .borderRadius(999)
                  .border({ width: w === this.currentWeek ? 0 : 1, color: '#80FFB3CE' })
                  .onClick(() => { this.currentWeek = w; })
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

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
                  Text(`${20 + (i || 0)}`)
                    .fontSize(13)
                    .fontStyle(FontStyle.Italic)
                    .fontColor((i === 0) ? ElysiaTheme.ROSE_500 : ElysiaTheme.ROSE_700)
                    .fontFamily(ElysiaTheme.FONT_DISPLAY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              })
            }
            .width('100%')
            .margin({ bottom: 6 })

            // 6 行 × 7 列
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

                // 7 列
                ForEach([0, 1, 2, 3, 4, 5, 6], (col: number) => {
                  Stack() {
                    this.LessonCell(row * 2 + 1, col)
                  }
                  .layoutWeight(1)
                  .height(64)
                  .margin({ left: 2, right: 2 })
                })
              }
              .width('100%')
              .margin({ bottom: 4 })
              .alignItems(VerticalAlign.Center)
            })
          }
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 8 })

        Blank().height(80)
      }

      ElysiaTabBar({ active: 'home' })
    }
    .width('100%').height('100%')
  }

  @Builder LessonCell(period: number, day: number) {
    if (this.findLesson(period, day) !== undefined) {
      Column() {
        Text(this.findLesson(period, day)!.name)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.hueText(this.findLesson(period, day)!.hue))
          .maxLines(2)
        Text(this.findLesson(period, day)!.room)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, day)!.hue))
          .opacity(0.75)
          .margin({ top: 3 })
        Text(this.findLesson(period, day)!.teacher)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, day)!.hue))
          .opacity(0.6)
          .margin({ top: 1 })
      }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 6, right: 5, top: 6, bottom: 6 })
      .borderRadius(10)
      .linearGradient({
        angle: 160,
        colors: this.hueBg(this.findLesson(period, day)!.hue)
      })
    } else {
      Column()
        .width('100%').height('100%')
        .borderRadius(10)
        .backgroundColor('#66FFFFFF')
        .border({ width: 1, color: '#4DFFB3CE', style: BorderStyle.Dashed })
    }
  }

  findLesson(period: number, day: number): Lesson | undefined {
    return this.lessons.find(l => l.day === day && l.p1 === period);
  }

  hueText(hue: string): string {
    if (hue === 'lav') return '#6F47A8';
    if (hue === 'gold') return ElysiaTheme.GOLD_700;
    return ElysiaTheme.ROSE_700;
  }

  hueBg(hue: string): Array<[string, number]> {
    if (hue === 'lav') return [[ElysiaTheme.LAV_200, 0], [ElysiaTheme.LAV_300, 1]];
    if (hue === 'gold') return [['#FFF1D6', 0], [ElysiaTheme.GOLD_300, 1]];
    return [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_300, 1]];
  }

  romanize(n: number): string {
    const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII'];
    return romans[n - 1] || `${n}`;
  }
}
