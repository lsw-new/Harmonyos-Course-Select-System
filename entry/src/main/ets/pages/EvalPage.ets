// 量化评教 · Evaluation
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';

class EvalCourseItem {
  name: string = '';
  t: string = '';
  status: string = '';
  constructor(name: string, t: string, status: string) {
    this.name = name;
    this.t = t;
    this.status = status;
  }
}

@Entry
@Component
struct EvalPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Evaluation', subtitle: '量 化 评 教', onBack: () => router.back() })

        Scroll() {
          Column() {
            Column() {
              Text('Voice of the Rose').fontSize(18).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
              Text('每一份诚挚的反馈，都是花瓣般温柔的力量。请于 11·05 24:00 前完成。')
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18).margin({top:6})
              Row() {
                Text('2 / 6').fontSize(28).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text('  已完成').fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
              }.alignItems(VerticalAlign.Bottom).margin({top:10})
              Stack({alignContent:Alignment.Start}) {
                Stack().width('100%').height(6).backgroundColor('#99FFFFFF').borderRadius(3)
                Stack().width('33%').height(6).borderRadius(3)
                  .linearGradient({angle:90, colors:[[ElysiaTheme.ROSE_500,0],[ElysiaTheme.LAV_500,1]]})
              }.margin({top:8})
            }
            .width('100%').alignItems(HorizontalAlign.Start)
            .padding(16).borderRadius(22)
            .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_200,0],[ElysiaTheme.LAV_200,1]]})

            Column({space:10}) {
              ForEach([
                new EvalCourseItem('鸿蒙应用开发综合实践', '林', 'open'),
                new EvalCourseItem('软件工程经济学', '苏', 'open'),
                new EvalCourseItem('操作系统', '王', 'done'),
                new EvalCourseItem('近代史纲要', '周', 'done'),
                new EvalCourseItem('宋词鉴赏与吟诵', '柳', 'closed')
              ], (task: EvalCourseItem) => {
                Column() {
                  Row() {
                    Stack() { Text(task.t).fontSize(14).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY) }
                      .width(36).height(36).borderRadius(18)
                      .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_100,0],[ElysiaTheme.LAV_200,1]]})
                    Column() {
                      Text(task.name).fontSize(12.5).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                      Text(task.t + ' 老师 · 教师课堂教学情况问卷').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({top:2})
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({left:10})
                    Button(task.status==='open'?'去评教':task.status==='done'?'已提交':'未开放')
                      .height(28).fontSize(10).fontWeight(FontWeight.Bold).padding({left:12,right:12})
                      .fontColor(task.status==='open' ? Color.White : task.status==='done' ? '#3F7A4A' : ElysiaTheme.INK_MUTE)
                      .backgroundColor(task.status==='open' ? '' : '#A6FFFFFF')
                      .linearGradient(task.status==='open' ? {angle:135, colors:[['#FF9FBE',0],[ElysiaTheme.ROSE_500,1]]} : {angle:0, colors:[['#00FFFFFF',0]]})
                      .border({width: task.status==='open' ? 0 : 1, color:'#80FFB3CE'})
                      .borderRadius(999)
                  }
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
