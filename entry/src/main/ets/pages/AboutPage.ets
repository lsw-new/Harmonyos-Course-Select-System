// 关于 · Elysia 教学管理系统（公共页，无需守卫）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Monogram, Pill, RoseDivider } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

class CreditItem {
  icon: string = '';
  label: string = '';
  value: string = '';
  constructor(icon: string, label: string, value: string) {
    this.icon = icon;
    this.label = label;
    this.value = value;
  }
}

@Component
struct AboutPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  private credits: CreditItem[] = [
    new CreditItem('info', '版本', 'V1.0.0 (build 20260529)'),
    new CreditItem('star', '出品', '景德镇艺术职业大学教务处'),
    new CreditItem('students', '研发团队', '景德镇艺术职业大学信息中心'),
    new CreditItem('mail', '联系邮箱', 'support@jdart.edu.cn'),
    new CreditItem('phone', '服务热线', '400-820-0000'),
    new CreditItem('location', '地址', '茶苑校区 · 行政楼 3F')
  ];

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.about_title'), subtitle: $r('app.string.about_subtitle'), onBack: () => { AppRoute.back(); } })

        Scroll() {
          Column({ space: 14 }) {
            // 品牌卡片
            Column({ space: 8 }) {
              Monogram({ iconSize: 76 })
              Text($r('app.string.about_app_name'))
                .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 6 })
              Text($r('app.string.about_app_sub'))
                .fontSize(12).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
              Pill({ text: 'V1.0.0', color: ElysiaTheme.ROSE_700, bg: ElysiaTheme.SURFACE_GLOW })
            }.width('100%').alignItems(HorizontalAlign.Center).padding(24)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 简介
            Column({ space: 8 }) {
              Text($r('app.string.about_section')).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
              Text($r('app.string.about_intro'))
                .fontSize(13).fontColor(ElysiaTheme.INK_SOFT).lineHeight(22)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            // 构建 / 致谢
            Column() {
              Text($r('app.string.about_build_info')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
              ForEach(this.credits, (it: CreditItem) => {
                this.CreditRow(it)
              }, (it: CreditItem) => it.label)
            }.width('100%').padding(16)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            RoseDivider({ label: $r('app.string.about_legal') })

            // 协议 / 隐私
            Column() {
              this.DocLinkRow('用户协议', 'agreement')
              this.DocLinkRow('隐私政策', 'privacy')
            }.width('100%').padding(16)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

            Text($r('app.string.about_copyright'))
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 4 })

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }

  @Builder CreditRow(it: CreditItem) {
    Row() {
      AppIcon({ name: it.icon, iconSize: 18, mRight: 10 })
      Text(it.label).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
      Text(it.value).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder DocLinkRow(label: string, docType: string) {
    Row() {
      Text(label).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
      AppIcon({ name: 'forward', iconSize: 14, dim: true, mLeft: 6 })
    }.width('100%').padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
    .onClick(() => {
      const p: Record<string, Object> = { 'type': docType };
      AppRoute.go(Routes.Doc, { params: p });
    })
  }
}

// 系统路由表构建函数
@Builder
export function AboutPageBuilder() {
  NavDestination() {
    AboutPage()
  }
  .hideTitleBar(true)
