// 学籍信息 · Roster
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';

@Entry
@Component
struct RosterPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Roster', subtitle: '学 籍 信 息', onBack: () => router.back() })

        Scroll() {
          Column() {
            Row() {
              Stack() { Text('PHOTO').fontSize(9).fontColor(ElysiaTheme.ROSE_700).letterSpacing(2).fontFamily('monospace') }
                .width(84).height(108).borderRadius(12).backgroundColor(ElysiaTheme.ROSE_200)
              Column() {
                Text('Elysia · 同学').fontSize(22).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text('软件学院 · 软件工程').fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({top:4})
                Text('SE-2023-04 · 20231104').fontSize(10).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.INK_MUTE).fontFamily(ElysiaTheme.FONT_DISPLAY).margin({top:2})
                Row({space:6}) { Pill({text:'在籍'}); Pill({text:'在校', bg:'#D8F0D8', color:'#3F7A4A'}) }.margin({top:8})
              }.alignItems(HorizontalAlign.Start).margin({left:14}).layoutWeight(1)
            }
            .width('100%').padding(18).borderRadius(22)
            .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_100,0],[ElysiaTheme.LAV_200,1]]})

            Column() {
              ForEach([
                ['学号','20231104'], ['姓名','艾莉希雅'], ['英文名','Elysia'],
                ['性别','女'], ['年级','2023 级'], ['学制','四年'],
                ['项目·学历','本科 · 本科'], ['专业','软件工程'],
                ['院系','软件学院'], ['班级','软件 2304 班'],
                ['入校时间','2023·09·01'], ['毕业时间','2027·07 (预)'],
                ['学籍状态','正常'], ['所属校区','花江校区']
              ] as Array<[string,string]>, (kv: [string, string], i?: number) => {
                Row() {
                  Text(kv[0]).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
                  Text(kv[1]).fontSize(12).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK)
                }.width('100%').padding({top:10, bottom:10})
                if (i !== undefined && i < 13) { Divider().strokeWidth(1).color('#80FFB3CE') }
              })
            }
            .width('100%').padding({left:14, right:14, top:4, bottom:4})
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
            .border({width:1, color:'#66FFB3CE'})
            .shadow({radius:14, color:'#1FD85487', offsetX:0, offsetY:4})
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
