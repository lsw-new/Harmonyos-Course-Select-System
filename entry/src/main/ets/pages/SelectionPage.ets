// 选课中心 · Selection
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';

class SelectionCourseItem {
  name: string = '';
  code: string = '';
  t: string = '';
  cap: string = '';
  cred: string = '';
  tag: string = '';
  status: string = '';
  constructor(name: string, code: string, t: string, cap: string, cred: string, tag: string, status: string) {
    this.name = name;
    this.code = code;
    this.t = t;
    this.cap = cap;
    this.cred = cred;
    this.tag = tag;
    this.status = status;
  }
}

@Entry
@Component
struct SelectionPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Selection', subtitle: '选 课 中 心', onBack: () => router.back() })

        Scroll() {
          Column() {
            // Hero
            Column() {
              Row() {
                Column() {
                  Pill({text:'正选阶段·进行中'})
                  Text('Round II · Selection').fontSize(18).fontStyle(FontStyle.Italic)
                    .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY).margin({top:6})
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Column() {
                  Text('03d 14h').fontSize(14).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text('剩余 · UNTIL 10·24').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                }.alignItems(HorizontalAlign.End)
              }
              Stack().width('100%').height(6).borderRadius(3).backgroundColor('#99FFFFFF').margin({top:12})
              Row() {
                Text('已选 14.5 学分').fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
                Text('上限 24 学分').fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
              }.margin({top:8})
            }
            .width('100%').padding(16).borderRadius(22)
            .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_100,0],[ElysiaTheme.LAV_200,1]]})

            // 列表
            Column({ space: 10 }) {
              ForEach([
                new SelectionCourseItem('人机交互设计', 'SE-5012', '林老师', '56/60', '2.0', '专选', 'select'),
                new SelectionCourseItem('宋词鉴赏与吟诵', 'GE-2031', '柳老师', '120/120', '1.5', '公选', 'full'),
                new SelectionCourseItem('机器学习导论', 'CS-4108', '谢老师', '42/60', '3.0', '专选', 'select'),
                new SelectionCourseItem('西方艺术史', 'GE-1021', '宋老师', '14:00-15:35', '1.5', '已选', 'taken')
              ], (c: SelectionCourseItem) => {
                Row() {
                  Column() {
                    Row() {
                      Text(c.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                      Text('  ' + c.code).fontSize(10).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.INK_MUTE).fontFamily(ElysiaTheme.FONT_DISPLAY)
                    }
                    Text(c.t + ' · ' + c.cap).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({top:4})
                    Row({space:6}) {
                      Pill({text: c.tag})
                      Pill({text: c.cred + ' 学分', bg:'#FBE6C2', color: ElysiaTheme.GOLD_700})
                    }.margin({top:6})
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Button(c.status==='select'?'选 课' : c.status==='full' ? '已 满' : '退 选')
                    .height(34).fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(c.status==='select' ? Color.White : (c.status==='full' ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_700))
                    .backgroundColor(c.status==='select' ? '' : '#B3FFFFFF')
                    .linearGradient(c.status==='select' ? {angle:135, colors:[['#FF9FBE',0],[ElysiaTheme.ROSE_500,1]]} : {angle:0, colors:[['#00FFFFFF',0]]})
                    .border({width: c.status==='select' ? 0 : 1, color:'#80FFB3CE'})
                    .borderRadius(999)
                    .padding({left:14, right:14})
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
