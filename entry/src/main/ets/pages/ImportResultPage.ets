// 导入结果 · Import Result（展示态，无现成数据源，参数通过路由传入）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct ImportResultPage {
  @State successCount: string = '0';
  @State failedCount: string = '0';
  @State rate: string = '—';
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.ImportResult)) {
      return;
    }
    this.successCount = AppRoute.getParam<string>('success', '0');
    this.failedCount = AppRoute.getParam<string>('failed', '0');
    this.rate = AppRoute.getParam<string>('rate', '—');
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.importresult_title'), subtitle: $r('app.string.importresult_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            // Hero 区
            Column({ space: 6 }) {
              Pill({ text: $r('app.string.importresult_hero_pill') })
              Text($r('app.string.importresult_hero_title'))
                .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
              Text($r('app.string.importresult_hero_hint'))
                .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 三指标卡
            Row({ space: 10 }) {
              Column() {
                Text(this.successCount)
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.SUCCESS).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.importresult_metric_success')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text(this.failedCount)
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.ROSE_ACCENT).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.importresult_metric_failed')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text(this.rate)
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.importresult_metric_rate')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
            }.width('100%')

            // 导入概要
            Column() {
              Text('导入概要').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.InfoRow('成功条数', this.successCount)
              this.InfoRow('失败条数', this.failedCount)
              this.InfoRow('通过率', this.rate)
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 错误明细区（结构化占位，实际明细由调用方通过后续版本传入）
            Column() {
              Row({ space: 8 }) {
                Column()
                  .width(10).height(38).borderRadius(6)
                  .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text($r('app.string.importresult_error_section_title')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                    Pill({ text: $r('app.string.importresult_error_pill') })
                  }
                  Text($r('app.string.importresult_error_section_hint'))
                    .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
              .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
            }.width('100%')

            // 操作按钮
            Row({ space: 12 }) {
              GhostButton({ text: $r('app.string.importresult_reimport'), onTap: () => Toast.show(this.getUIContext(), '请重新上传文件') })
              PrimaryButton({ text: $r('app.string.importresult_download_report'), onTap: () => Toast.show(this.getUIContext(), '报告下载功能敬请期待') })
            }.width('100%')

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function ImportResultPageBuilder() {
  NavDestination() {
    ImportResultPage()
  }
  .hideTitleBar(true)
}
