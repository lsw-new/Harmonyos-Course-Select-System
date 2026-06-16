// 通知强制弹窗：根容器顶层叠加，随 AppStorage.noticeAlertCurrent 出现。
// urgency = 'important' → "确定"按钮立即可点
// urgency = 'urgent'   → "确定"按钮 5 秒倒计时后可点
// 点击"确定"调用 NoticeAlertCenter.acknowledge 标记为已读，并自动出队下一条
import { Notice } from '../../models/Notice';
import { NoticeAlertCenter } from '../services/NoticeAlertCenter';
import { ElysiaTheme } from '../Theme';
import { AppFontFamily } from '../constants/TextStyles';

const URGENT_COUNTDOWN_SECONDS = 5;

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
    if ((cur.urgency || 'normal') === 'urgent' && this.remainSeconds > 0) {
      return;
    }
    this.acking = true;
    await NoticeAlertCenter.acknowledge(cur.id);
    this.acking = false;
  }

  private urgencyLabel(u: string): string {
    if (u === 'urgent') {
      return '紧急通知';
    }
    if (u === 'important') {
      return '重要通知';
    }
    return '通知';
  }

  private urgencyColor(u: string): string {
    if (u === 'urgent') {
      return ElysiaTheme.ROSE_ACCENT;
    }
    return ElysiaTheme.ROSE_600;
  }

  build() {
    if (this.current) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(ElysiaTheme.scrim())
          .onClick(() => {})
        Column() {
          Row() {
            Text(this.urgencyLabel(this.current!.urgency || 'normal'))
              .fontSize(13)
              .fontColor(Color.White)
              .fontFamily(AppFontFamily.body)
              .letterSpacing(1.5)
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12, left: 20, right: 20 })
          .backgroundColor(this.urgencyColor(this.current!.urgency || 'normal'))

          Column() {
            Text(this.current!.title)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(ElysiaTheme.INK)
              .fontFamily(AppFontFamily.display)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text(`${this.current!.publisher} · ${this.current!.publishedAt}`)
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_MUTE)
              .fontFamily(AppFontFamily.body)
              .margin({ top: 6 })
              .width('100%')
              .textAlign(TextAlign.Start)
            Scroll() {
              Text(this.current!.content)
                .fontSize(14)
                .lineHeight(22)
                .fontColor(ElysiaTheme.INK_SOFT)
                .fontFamily(AppFontFamily.body)
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .scrollBar(BarState.Auto)
            .width('100%')
            .constraintSize({ maxHeight: 260 })
            .margin({ top: 16 })
            .align(Alignment.TopStart)

            Button(this.buttonText(), { type: ButtonType.Capsule, stateEffect: !this.disabled() })
              .width('100%')
              .height(44)
              .margin({ top: 20 })
              .fontSize(15)
              .fontColor(Color.White)
              .fontFamily(AppFontFamily.body)
              .backgroundColor(this.disabled() ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
              .opacity(this.disabled() ? 0.7 : 1)
              .enabled(!this.disabled())
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
        .constraintSize({ maxWidth: 480 })
        .borderRadius(20)
        .clip(true)
        .shadow({ radius: 24, color: '#33000000', offsetY: 8 })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
      .hitTestBehavior(HitTestMode.Block)
    }
  }

  private disabled(): boolean {
    if (this.acking) {
      return true;
    }
    const cur = this.current;
    if (!cur) {
      return true;
    }
    if ((cur.urgency || 'normal') === 'urgent' && this.remainSeconds > 0) {
      return true;
    }
    return false;
  }

  private buttonText(): string {
    const cur = this.current;
    if (!cur) {
      return '确定';
    }
    if ((cur.urgency || 'normal') === 'urgent' && this.remainSeconds > 0) {
      return `确定（${this.remainSeconds}s）`;
    }
    return '确定';
  }
}
