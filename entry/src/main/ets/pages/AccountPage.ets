// 我的账户 · Account
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram, RoseIcon, Sparkle } from '../common/Components';

@Entry
@Component
struct AccountPage {
  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Account', subtitle: '我 的 账 户', onBack: () => router.back() })

        Scroll() {
          Column() {
            Column() {
              Row() {
              Monogram({iconSize:56})
                Blank().layoutWeight(1)
                Pill({text:'激活', bg:'#D8F0D8', color:'#3F7A4A'})
              }
              Text('Elysia').fontSize(24).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY).margin({top:14})
              Text('20231104 · elysia@school.edu.cn').fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({top:2})
            }
            .width('100%').alignItems(HorizontalAlign.Start).padding(20).borderRadius(24)
            .linearGradient({angle:135, colors:[[ElysiaTheme.ROSE_200,0],[ElysiaTheme.LAV_200,0.7],['#FFF1D6',1]]})

            Row({space:10}) {
              Column() {
                Text('⌘').fontSize(22).fontColor(ElysiaTheme.ROSE_700)
                Text('修改密码').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({top:6})
              }.layoutWeight(1).padding({top:14, bottom:14})
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({width:1, color:'#66FFB3CE'})
              Column() {
                Text('📷').fontSize(22).fontColor(ElysiaTheme.ROSE_700)
                Text('更换头像').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({top:6})
              }.layoutWeight(1).padding({top:14, bottom:14})
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({width:1, color:'#66FFB3CE'})
              Column() {
                Text('⏏').fontSize(22).fontColor(ElysiaTheme.ROSE_700)
                Text('退出登录').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({top:6})
              }.layoutWeight(1).padding({top:14, bottom:14})
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({width:1, color:'#66FFB3CE'})
            }.width('100%').margin({top:18})

            Column() {
              this.HistoryRow('10·19 23:47', '42 min', false)
              this.HistoryRow('10·18 09:12', '2 h 14 min', false)
              this.HistoryRow('10·15 14:30', '1 h 02 min', false)
              this.HistoryRow('10·12 21:00', '38 min', true)
            }
            .width('100%').padding({left:14, right:14}).margin({top:18, bottom:30})
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({width:1, color:'#66FFB3CE'})
          }
          .padding({left:16, right:16})
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }

  @Builder HistoryRow(time: string, duration: string, isLast: boolean) {
    Row() {
      Stack().width(8).height(8).borderRadius(4).backgroundColor(ElysiaTheme.ROSE_500)
      Column() {
        Text(time).fontSize(12).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.INK).fontFamily(ElysiaTheme.FONT_DISPLAY).fontWeight(FontWeight.Medium)
        Text('校园网 · 桂林').fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({top:2})
      }.alignItems(HorizontalAlign.Start).margin({left:10}).layoutWeight(1)
      Text('在线 ' + duration).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
    }.width('100%').padding({top:10, bottom:10})
    if (!isLast) { Divider().strokeWidth(1).color('#80FFB3CE') }
  }
}
