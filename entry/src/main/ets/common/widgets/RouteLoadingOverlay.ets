// 全局路由加载遮罩。
// AppRoute 在导航(go/back/clearTo)时把 AppStorage 的 routeLoading 置 true，1.5s 后置 false。
// 各页根 Stack 顶层放置本组件：routeLoading 为 true 时全屏覆盖「正在加载」，1.5s 后隐藏、直接露出目标页。
import { ElysiaTheme } from '../Theme';
import { AppFontFamily } from '../constants/TextStyles';

@Component
export struct RouteLoadingOverlay {
  @StorageLink('routeLoading') routeLoading: boolean = false;

  build() {
    if (this.routeLoading) {
      Column() {
        LoadingProgress()
          .width(56)
          .height(56)
          .color(ElysiaTheme.ROSE_500)
        Text('正在加载...')
          .fontSize(13)
          .fontStyle(FontStyle.Italic)
          .fontColor(ElysiaTheme.ROSE_700)
          .fontFamily(AppFontFamily.display)
          .letterSpacing(2)
          .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })
      .zIndex(100)
    }
  }
}
