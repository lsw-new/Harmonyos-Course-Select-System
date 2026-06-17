// 通知强制弹窗：根容器顶层叠加，随 AppStorage.noticeAlertCurrent 出现。
// urgency = 'important' → "确定"按钮立即可点
// urgency = 'urgent'   → "确定"按钮 5 秒环形倒计时后可点
// 点击"确定"调用 NoticeAlertCenter.acknowledge 标记为已读，并自动出队下一条
//
// ⚠️ 响应式要点（曾踩坑）：ArkUI 局部刷新只订阅 build() 里【直接读到】的 @State。
// 倒计时数字 / 按钮可用态必须把 this.remainSeconds、this.acking 直接写进 build 表达式，
// 不能包进 buttonText()/disabled() 这类辅助方法里——否则 Button 不会随 remainSeconds 重渲染，
// 表现为"倒计时不显示 + 到点还点不了"。详见 RegisterPage 验证码倒计时的可用写法。
import { Notice } from '../../models/Notice';
import { NoticeAlertCenter } from '../services/NoticeAlertCenter';
import { ElysiaTheme } from '../Theme';
import { AppFontFamily } from '../constants/TextStyles';

const URGENT_COUNTDOWN_SECONDS: number = 5;

@Component
export struct NoticeAlertOverlay {
  @StorageProp('noticeAlertCurrent') @Watch('onCurrentChanged') current: Notice | undefined = undefined;
  @StorageProp('noticeAlertVersion') @Watch('onCurrentChanged') version: number = 0;
  @State remainSeconds: number = 0;
  @State acking: boolean = false;
  private countdown: number = -1;

  aboutToAppear(): void {
    this.syncCountdown();
  }

  aboutToDisappear(): void {
    this.clearCountdown();
  }

  onCurrentChanged(): void {
    this.syncCountdown();
  }

  private syncCountdown(): void {
    this.clearCountdown();
    const cur = this.current;
    if (!cur) {
      this.remainSeconds = 0;
      this.acking = false;
      return;
    }
    if ((cur.urgency || 'normal') === 'urgent') {
      this.remainSeconds = URGENT_COUNTDOWN_SECONDS;
      this.countdown = setInterval(() => {
        if (this.remainSeconds > 0) {
          this.remainSeconds = this.remainSeconds - 1;
        }
        if (this.remainSeconds <= 0) {
          this.clearCountdown();
        }
      }, 1000);
    } else {
      this.remainSeconds = 0;
    }
  }

  private clearCountdown(): void {
    if (this.countdown >= 0) {
      clearInterval(this.countdown);
      this.countdown = -1;
    }
  }

  private async confirm(): Promise<void> {
    const cur = this.current;
    if (!cur || this.acking) {
      return;
    }
    // 紧急通知倒计时未结束：忽略点击（与按钮可用态同源，均读 this.remainSeconds）
    if ((cur.urgency || 'normal') === 'urgent' && this.remainSeconds > 0) {
      return;
    }
    this.acking = true;
    try {
      await NoticeAlertCenter.acknowledge(cur.id);
    } catch (e) {
      // 确认失败兜底：不让 acking 卡死按钮，下次点击可重试
    } finally {
      this.acking = false;
    }
  }

  private isUrgent(): boolean {
    const cur = this.current;
    return !!cur && (cur.urgency || 'normal') === 'urgent';
  }

  private urgencyLabel(): string {
    if (this.isUrgent()) {
      return '紧急通知';
    }
    const cur = this.current;
    if (cur && cur.urgency === 'important') {
      return '重要通知';
    }
    return '通知';
  }

  private accent(): string {
    return this.isUrgent() ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.ROSE_600;
  }

  // 把 "2026-06-16T13:01:49.670Z" 这类 ISO 串收成 "2026-06-16 13:01"，解析失败回退原串
  private formatTime(raw: string): string {
    if (!raw) {
      return '';
    }
    const t: number = Date.parse(raw);
    if (Number.isNaN(t)) {
      return raw;
    }
    const d: Date = new Date(t);
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  @Builder
  countdownRing() {
    Stack() {
      Progress({ value: this.remainSeconds, total: URGENT_COUNTDOWN_SECONDS, type: ProgressType.Ring })
        .width(42)
        .height(42)
        .color(ElysiaTheme.ROSE_ACCENT)
        .backgroundColor(ElysiaTheme.ROSE_200)
        .style({ strokeWidth: 4 })
      Text(`${this.remainSeconds}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.ROSE_ACCENT)
        .fontFamily(AppFontFamily.display)
    }
    .width(42)
    .height(42)
  }

  build() {
    if (this.current) {
      Stack() {
        // 遮罩：占满全屏并消费背景点击，阻止触摸穿透到后面的页面（模态）。
        // 注意：模态拦截只能放在这层 scrim 上，绝不能给外层 Stack 设 HitTestMode.Block——
        // Block 会连同自己的子节点（含"我已知悉"按钮）一起屏蔽触摸，导致按钮永远点不动。
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(ElysiaTheme.scrim())
          .backdropBlur(6)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {})

        // 卡片
        Column() {
          // 头部：左侧紧急 Pill，右侧倒计时环（仅紧急且未结束）
          Row() {
            Row({ space: 8 }) {
              Circle({ width: 8, height: 8 }).fill(this.accent())
              Text(this.urgencyLabel())
                .fontSize(12)
                .fontColor(this.accent())
                .fontFamily(AppFontFamily.body)
                .letterSpacing(2)
                .fontWeight(FontWeight.Bold)
            }
            .padding({ left: 12, right: 14, top: 7, bottom: 7 })
            .backgroundColor(ElysiaTheme.SURFACE)
            .borderRadius(20)
            .shadow({ radius: 8, color: '#14000000', offsetY: 2 })

            Blank()

            if (this.isUrgent() && this.remainSeconds > 0) {
              this.countdownRing()
            }
          }
          .width('100%')
          .padding({ top: 16, bottom: 16, left: 18, right: 18 })
          .alignItems(VerticalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [[ElysiaTheme.SURFACE_GLOW, 0.0], [ElysiaTheme.ROSE_100, 1.0]]
          })

          // 正文
          Column() {
            Text(this.current!.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(ElysiaTheme.INK)
              .fontFamily(AppFontFamily.display)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text(`${this.current!.publisher} · ${this.formatTime(this.current!.publishedAt)}`)
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_MUTE)
              .fontFamily(AppFontFamily.body)
              .margin({ top: 6 })
              .width('100%')
              .textAlign(TextAlign.Start)

            Divider()
              .color(ElysiaTheme.hairline())
              .margin({ top: 14, bottom: 14 })

            Scroll() {
              Text(this.current!.content)
                .fontSize(14)
                .lineHeight(23)
                .fontColor(ElysiaTheme.INK_SOFT)
                .fontFamily(AppFontFamily.body)
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .scrollBar(BarState.Auto)
            .width('100%')
            .constraintSize({ maxHeight: 240 })
            .align(Alignment.TopStart)

            // 确定按钮：label / 可用态 / 配色 全部内联读 this.remainSeconds、this.acking（保证响应式）
            Button(
              this.isUrgent() && this.remainSeconds > 0 ? `${this.remainSeconds} 秒后可确认` : '我已知悉',
              { type: ButtonType.Capsule, stateEffect: !(this.acking || (this.isUrgent() && this.remainSeconds > 0)) }
            )
              .width('100%')
              .height(48)
              .margin({ top: 20 })
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isUrgent() && this.remainSeconds > 0 ? ElysiaTheme.INK_MUTE : Color.White)
              .fontFamily(AppFontFamily.body)
              .backgroundColor(this.isUrgent() && this.remainSeconds > 0 ? ElysiaTheme.pillBg() : ElysiaTheme.ROSE_500)
              .enabled(!(this.acking || (this.isUrgent() && this.remainSeconds > 0)))
              .onClick(() => {
                this.confirm();
              })
          }
          .width('100%')
          .padding({ top: 20, bottom: 20, left: 22, right: 22 })
          .backgroundColor(ElysiaTheme.SURFACE)
          .alignItems(HorizontalAlign.Start)
        }
        .width('86%')
        .constraintSize({ maxWidth: 420 })
        .borderRadius(24)
        .clip(true)
        .shadow({ radius: 28, color: '#33000000', offsetY: 10 })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
  }
}
