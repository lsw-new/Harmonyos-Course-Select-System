// 无权限访问 · No Permission（公共页）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct NoPermissionPage {
  @StorageProp('breakpoint') bp: string = 'sm';

  // 公共页：不调用 AppRoute.guard
  aboutToAppear(): void {
  }

  @Builder SectionItem(stepTitle: string, stepDesc: string, tag: string) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(38).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(stepTitle).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Pill({ text: tag })
        }
        Text(stepDesc).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.noperm_title'), subtitle: $r('app.string.noperm_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            // Hero 区：错误说明
            Column({ space: 10 }) {
              Pill({ text: '403', color: ElysiaTheme.ROSE_ACCENT, bg: '#FFE9F1' })
              Text($r('app.string.noperm_hero_title'))
                .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
              Text($r('app.string.noperm_hero_sub'))
                .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 指标卡
            Row({ space: 10 }) {
              Column() {
                Text('403')
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.noperm_metric_errcode')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text($r('app.string.noperm_metric_role'))
                  .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.noperm_label_role')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text($r('app.string.noperm_metric_action'))
                  .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor('#D9B675').fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.noperm_label_suggestion')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
            }.width('100%')

            // 说明卡片
            Column({ space: 10 }) {
              this.SectionItem('权限说明', '该功能仅管理员角色可访问', '说明')
              this.SectionItem('当前会话', '登录状态可能已过期或角色不匹配', '会话')
              this.SectionItem('解决方式', '返回首页或切换账号重新登录', '处理')
            }.width('100%')

            // 操作按钮
            Row({ space: 12 }) {
              GhostButton({
                text: $r('app.string.noperm_btn_back_home'),
                onTap: () => AppRoute.back()
              })
              PrimaryButton({
                text: $r('app.string.noperm_btn_relogin'),
                onTap: () => AppRoute.clearTo(Routes.Login)
              })
            }.width('100%')

            SafeBottom()
          }.padding({ left: 16, right: 16, bottom: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function NoPermissionPageBuilder() {
  NavDestination() {
    NoPermissionPage()
  }
  .hideTitleBar(true)
}
