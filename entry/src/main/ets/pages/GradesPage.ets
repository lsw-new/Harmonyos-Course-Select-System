// 我的成绩 · Grades
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, Pill, RoseIcon, Sparkle } from '../common/Components';

interface GradeRecord {
  name: string;
  code: string;
  cls: string;
  cred: number;
  mid: string;
  fin: string;
  total: number | string;
  gpa: string;
}

@Entry
@Component
struct GradesPage {
  @State activeTerm: number = 0;
  private terms: string[] = ['2025-1 当前', '2024-2', '2024-1', '2023-2', '2023-1', '所有学期'];

  private grades: GradeRecord[] = [
    { name: '鸿蒙应用开发综合实践', code: 'SE-4023', cls: '专业拓展', cred: 4.0, mid: '88', fin: '92', total: 91, gpa: '4.0' },
    { name: '软件工程经济学', code: 'SE-3041', cls: '专业选修', cred: 2.0, mid: '85', fin: '90', total: 88, gpa: '3.7' },
    { name: '操作系统', code: 'CS-3022', cls: '专业必修', cred: 3.5, mid: '82', fin: '88', total: 86, gpa: '3.5' },
    { name: '近代史纲要', code: 'GE-1003', cls: '通识必修', cred: 2.0, mid: '90', fin: '91', total: 91, gpa: '4.0' },
    { name: '体育 · 网球', code: 'PE-2011', cls: '集中实践', cred: 1.0, mid: '—', fin: '合格', total: '优秀', gpa: '—' },
    { name: '宋词鉴赏与吟诵', code: 'GE-2031', cls: '通识选修', cred: 1.5, mid: '92', fin: '94', total: 93, gpa: '4.0' }
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
        TopBar({ title: 'Grades', subtitle: '我 的 成 绩' })

        Scroll() {
          Column() {
            // 学期切换
            Scroll() {
              Row({ space: 6 }) {
                ForEach(this.terms, (t: string, i?: number) => {
                  Button(t)
                    .height(28)
                    .padding({ left: 14, right: 14 })
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(i === this.activeTerm ? Color.White : ElysiaTheme.ROSE_700)
                    .backgroundColor(i === this.activeTerm ? '' : '#B3FFFFFF')
                    .linearGradient(i === this.activeTerm ? {
                      angle: 135,
                      colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                    } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                    .borderRadius(999)
                    .border({ width: i === this.activeTerm ? 0 : 1, color: '#80FFB3CE' })
                    .onClick(() => { this.activeTerm = i ?? 0; })
                })
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .padding({ left: 16, right: 16, bottom: 12 })

            // 统计卡片
            Column() {
              Text('2025-2026 · AUTUMN')
                .fontSize(10)
                .fontColor(ElysiaTheme.ROSE_700)
                .letterSpacing(4)
              Row() {
                Text('3.86')
                  .fontSize(42)
                  .fontStyle(FontStyle.Italic)
                  .fontColor(ElysiaTheme.ROSE_700)
                  .fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text('  学期 · GPA')
                  .fontSize(11)
                  .fontColor(ElysiaTheme.INK_SOFT)
              }
              .alignItems(VerticalAlign.Bottom)
              .margin({ top: 4 })

              Row({ space: 8 }) {
                this.StatPill('已修学分', '21.5')
                this.StatPill('加权平均', '89.7')
                this.StatPill('累计 GPA', '3.82')
              }
              .width('100%')
              .margin({ top: 14 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(18)
            .borderRadius(24)
            .linearGradient({
              angle: 135,
              colors: [['#FFE4EE', 0], ['#F1E2FF', 0.5], ['#FFF1D6', 1]]
            })
            .margin({ left: 16, right: 16 })

            RoseDivider({ label: `records · ${this.grades.length} 门` })

            // 成绩列表
            Column({ space: 10 }) {
              ForEach(this.grades, (g: GradeRecord) => {
                this.GradeCard(g)
              })
            }
            .padding({ left: 16, right: 16 })

            Text('— sweet rewards —')
              .fontSize(11)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.INK_MUTE)
              .letterSpacing(4)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 16, bottom: 30 })
          }
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }

  @Builder StatPill(k: string, v: string) {
    Column() {
      Text(v)
        .fontSize(18)
        .fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(k)
        .fontSize(9)
        .fontColor(ElysiaTheme.INK_SOFT)
        .letterSpacing(2)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor('#99FFFFFF')
  }

  @Builder GradeCard(g: GradeRecord) {
    Column() {
      Row() {
        Column() {
          Text(g.name)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(ElysiaTheme.INK)
          Text(g.code)
            .fontSize(10)
            .fontStyle(FontStyle.Italic)
            .fontColor(ElysiaTheme.INK_MUTE)
            .fontFamily(ElysiaTheme.FONT_DISPLAY)
            .margin({ top: 2 })
          Row({ space: 6 }) {
            Pill({ text: g.cls })
            Pill({
              text: `${g.cred} 学分`,
              bg: '#FBE6C2', color: ElysiaTheme.GOLD_700
            })
          }
          .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text(`${g.total}`)
            .fontSize(30)
            .fontStyle(FontStyle.Italic)
            .fontColor(typeof g.total === 'number' && g.total >= 90 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_SOFT)
            .fontFamily(ElysiaTheme.FONT_DISPLAY)
          Text('最终成绩')
            .fontSize(10)
            .fontColor(ElysiaTheme.INK_SOFT)
            .letterSpacing(2)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Divider()
        .strokeWidth(1)
        .color('#80FFB3CE')
        .margin({ top: 10, bottom: 10 })

      Row() {
        this.Mini('期中', g.mid)
        this.Mini('期末', g.fin)
        this.Mini('绩点', g.gpa)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(22)
    .border({ width: 1, color: '#66FFB3CE' })
    .shadow({ radius: 16, color: '#1FD85487', offsetX: 0, offsetY: 4 })
  }

  @Builder Mini(k: string, v: string) {
    Column() {
      Text(v)
        .fontSize(13)
        .fontStyle(FontStyle.Italic)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
        .fontColor(ElysiaTheme.INK)
        .fontWeight(FontWeight.Medium)
      Text(k)
        .fontSize(9)
        .fontColor(ElysiaTheme.INK_SOFT)
        .letterSpacing(2)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
