// 今日课程 · Today
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';

class TodayCourseItem {
  t: string = '';
  e: string = '';
  n: string = '';
  name: string = '';
  room: string = '';
  teacher: string = '';
  constructor(t: string, e: string, n: string, name: string, room: string, teacher: string) {
    this.t = t;
    this.e = e;
    this.n = n;
    this.name = name;
    this.room = room;
    this.teacher = teacher;
  }
}

@Entry
@Component
struct TodayPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Today', subtitle: '今 日 课 程', onBack: () => router.back() })

        Column() {
          Scroll() {
            Row({ space: 6 }) {
              ForEach(['今天','明天','本周'], (t: string, i?: number) => {
                Button(t).height(28).fontSize(11).padding({left:14,right:14})
                  .borderRadius(999)
                  .fontColor(i===0 ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor(i===0 ? '' : '#B3FFFFFF')
                  .linearGradient(i===0 ? {angle:135, colors:[[ElysiaTheme.ROSE_500,0],['#E08AB8',1]]} : {angle:0, colors:[['#00FFFFFF',0]]})
                  .border({width: i===0?0:1, color:'#80FFB3CE'})
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .padding({left:16, right:16, bottom:14})

          List({ space: 12 }) {
            ForEach([
              new TodayCourseItem('08:00', '09:35', '1-2', '鸿蒙应用开发综合实践', '软305', '林老师'),
              new TodayCourseItem('10:00', '11:35', '3-4', '软件工程经济学', '一教 207', '苏老师'),
              new TodayCourseItem('14:00', '15:35', '5-6', '近代史纲要', '二教 102', '周老师'),
              new TodayCourseItem('19:00', '20:35', '9-10', '考研英语·自习', '图书馆·静读', '自习')
            ], (c: TodayCourseItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(c.t).fontSize(14).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                    Text(c.e).fontSize(9).fontColor(ElysiaTheme.INK_MUTE)
                  }
                  .width(50).alignItems(HorizontalAlign.End)
                  Stack().width(9).height(9).borderRadius(5).backgroundColor(ElysiaTheme.ROSE_500).margin({left:8, right:8})
                  Column() {
                    Text(c.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                    Text('📍 ' + c.room + ' · ' + c.teacher).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({top:4})
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }
                .width('100%').padding(12)
                .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                .border({width:1, color:'#66FFB3CE'})
                .shadow({radius:14, color:'#1FD85487', offsetX:0, offsetY:4})
              }
            })
          }
          .scrollBar(BarState.Off)
          .padding({left:16, right:16})
          .layoutWeight(1)
        }
      }
    }
    .width('100%').height('100%')
  }
}
