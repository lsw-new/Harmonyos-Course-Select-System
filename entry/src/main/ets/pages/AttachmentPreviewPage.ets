// 附件预览 · Attachment Preview（公共页）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct AttachmentPreviewPage {
  @State fileName: string = '附件';
  @State fileType: string = '文件';
  @StorageProp('breakpoint') bp: string = 'sm';

  // 公共页：不调用 AppRoute.guard
  aboutToAppear(): void {
    this.fileName = AppRoute.getParam<string>('name', '附件');
    this.fileType = AppRoute.getParam<string>('type', '文件');
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
        TopBar({ title: $r('app.string.attachmentpreview_title'), subtitle: $r('app.string.attachmentpreview_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            // Hero 区：文件名与类型
            Column({ space: 10 }) {
              Pill({ text: this.fileType.toUpperCase() })
              Text(this.fileName)
                .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
              Text($r('app.string.attachmentpreview_subtitle'))
                .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 指标卡
            Row({ space: 10 }) {
              Column() {
                Text(this.fileType.toUpperCase())
                  .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.attachmentpreview_metric_format')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text('—')
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.attachmentpreview_metric_size')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

              Column() {
                Text('—')
                  .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                  .fontColor('#D9B675').fontFamily(ElysiaTheme.FONT_DISPLAY)
                Text($r('app.string.attachmentpreview_metric_pages')).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
            }.width('100%')

            // 文件信息
            Column() {
              Text($r('app.string.attachmentpreview_section_info')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              this.InfoRow('文件名', this.fileName)
              this.InfoRow('类型', this.fileType)
              this.InfoRow('大小', '—')
              this.InfoRow('来源', '—')
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 预览占位区
            Column() {
              Text($r('app.string.attachmentpreview_section_preview')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
              Column() {
                Text('📄').fontSize(48)
                Text(this.fileName)
                  .fontSize(13).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 10 })
                  .textAlign(TextAlign.Center).maxLines(2)
                Text($r('app.string.attachmentpreview_preview_hint'))
                  .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 6 })
                  .textAlign(TextAlign.Center)
              }.width('100%').padding(40).alignItems(HorizontalAlign.Center)
              .backgroundColor(ElysiaTheme.glassSoft()).borderRadius(16)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 操作按钮
            Row({ space: 12 }) {
              GhostButton({
                text: $r('app.string.attachmentpreview_btn_share'),
                onTap: () => Toast.show(this.getUIContext(), '分享功能暂未开放')
              })
              PrimaryButton({
                text: $r('app.string.attachmentpreview_btn_download'),
                onTap: () => Toast.show(this.getUIContext(), '下载功能暂未开放')
              })
            }.width('100%')

            SafeBottom()
          }.padding({ left: 16, right: 16, bottom: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AttachmentPreviewPageBuilder() {
  NavDestination() {
    AttachmentPreviewPage()
  }
  .hideTitleBar(true)
}
