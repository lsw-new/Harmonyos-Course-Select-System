// 考试安排 · Exams
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';

class ExamItem {
  date: string = '';
  day: string = '';
  time: string = '';
  name: string = '';
  room: string = '';
  seat: string = '';
  type: string = '';
  constructor(date: string, day: string, time: string, name: string, room: string, seat: string, type: string) {
    this.date = date;
    this.day = day;
    this.time = time;
    this.name = name;
    this.room = room;
    this.seat = seat;
    this.type = type;
  }
}

@Entry
@Component
struct ExamPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Exams', subtitle: '考 试 安 排', onBack: () => router.back() })

        Scroll() {
          Column() {
            Column() {
              Pill({text: '距下场 · 18 天'})
              Text('鸿蒙应用开发 · 期末').fontSize(22).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({top:6})
              Row({space:12}) {
                Column() { Text('日期').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2); Text('2026·01·07').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({top:3}) }
                Column() { Text('时间').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2); Text('14:00-16:00').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({top:3}) }
              }.margin({top:14}).alignItems(VerticalAlign.Top)
              Row({space:12}) {
                Column() { Text('考场').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2); Text('软件楼 305').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({top:3}) }
                Column() { Text('座位').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2); Text('第 02 列 第 04 排').fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({top:3}) }
              }.margin({top:10}).alignItems(VerticalAlign.Top)
            }
            .width('100%').alignItems(HorizontalAlign.Start)
            .padding(16).borderRadius(22)
            .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_200,0],[ElysiaTheme.LAV_200,1]]})

            // 列表
            Column({space:10}) {
              ForEach([
                new ExamItem('01·07', '三', '14:00-16:00', '鸿蒙应用开发综合实践', '软305', '2-04', '闭卷'),
                new ExamItem('01·09', '五', '09:00-11:00', '操作系统', '软201', '5-12', '闭卷'),
                new ExamItem('01·12', '一', '14:00-16:00', '软件工程经济学', '一教 207', '3-08', '开卷'),
                new ExamItem('01·15', '四', '09:00-11:00', '近代史纲要', '二教 102', '4-15', '闭卷'),
              ], (e: ExamItem) => {
                Row() {
                  Column() {
                    Text('JAN').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    Text(e.date.slice(-2)).fontSize(22).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                    Text('周 ' + e.day).fontSize(9).fontColor(ElysiaTheme.ROSE_700).margin({top:3})
                  }
                  .width(60).padding({top:8, bottom:8}).borderRadius(14)
                  .alignItems(HorizontalAlign.Center)
                  .linearGradient({angle:180, colors:[[ElysiaTheme.ROSE_100,0],['#F1E2FF',1]]})

                  Column() {
                    Row() {
                      Text(e.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
                      Pill({text: e.type})
                    }
                    Row() {
                      AppIcon({ name: 'time', iconSize: 12 })
                      Text(e.time).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({left:4})
                    }.margin({top:6})
                    Row() {
                      AppIcon({ name: 'pin', iconSize: 12 })
                      Text(e.room).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({left:4})
                      AppIcon({ name: 'tag', iconSize: 12, mLeft: 8 })
                      Text('座位 ' + e.seat).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({left:4})
                    }.margin({top:4})
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({left:14})
                }
                .width('100%').padding(14)
                .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                .border({width:1, color:'#66FFB3CE'})
                .shadow({radius:14, color:'#1FD85487', offsetX:0, offsetY:4})
              })
            }
            .margin({top:14, bottom:30})
          }
          .padding({left:16, right:16})
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }
}
