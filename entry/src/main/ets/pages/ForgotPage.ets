// 找回密码 · Forgot Password
import { ElysiaTheme } from '../common/Theme';
import { TopBar, ElysiaInput, PrimaryButton, Sparkle } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { HttpError } from '../common/http/HttpError';
import { SafeTop } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct ForgotPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State sid: string = '';
  @State email: string = '';
  @State code: string = '';
  @State newPwd: string = '';
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State submitting: boolean = false;
  @State codeCountdown: number = 0;

  private countdownTimer: number = -1;

  private startCountdown(): void {
    this.codeCountdown = 60;
    this.countdownTimer = setInterval(() => {
      this.codeCountdown -= 1;
      if (this.codeCountdown <= 0) {
        clearInterval(this.countdownTimer);
        this.countdownTimer = -1;
        this.codeCountdown = 0;
      }
    }, 1000);
  }

  private sendCode(): void {
    if (this.codeCountdown > 0) {
      return;
    }
    const r = ValidatorUtils.email(this.email);
    if (!r.ok) {
      this.errorMsg = r.message ?? '邮箱格式不正确';
      return;
    }
    this.errorMsg = '';
    AuthRepository.get().sendEmailCode(this.email).then((_res: boolean) => {
      this.startCountdown();
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '发送失败';
    });
  }

  private doReset(): void {
    if (this.submitting) {
      return;
    }
    const r1 = ValidatorUtils.required(this.sid, '学号');
    if (!r1.ok) { this.errorMsg = r1.message ?? ''; return; }
    const r2 = ValidatorUtils.email(this.email);
    if (!r2.ok) { this.errorMsg = r2.message ?? ''; return; }
    const r3 = ValidatorUtils.required(this.code, '验证码');
    if (!r3.ok) { this.errorMsg = r3.message ?? ''; return; }
    const r4 = ValidatorUtils.password(this.newPwd);
    if (!r4.ok) { this.errorMsg = r4.message ?? ''; return; }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().resetPassword({
      account: this.sid,
      contact: this.email,
      verifyCode: this.code,
      newPassword: this.newPwd,
      method: 'email'
    }).then((_res: boolean) => {
      this.submitting = false;
      this.successMsg = '密码重置成功，请登录';
      AppRoute.go(Routes.Login, { replace: true });
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '重置失败';
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '找回密码', subtitle: '找 回 密 码', onBack: () => AppRoute.back() })

        Scroll() {
          Column() {
            Column() {
              Stack() {
                AppIcon({ name: 'rose', iconSize: 46 })
              }
              .width(90).height(90)
              .borderRadius(45)
              .linearGradient({
                angle: 135,
                colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_500, 1]]
              })
              .shadow({ radius: 24, color: '#99F2709C', offsetX: 0, offsetY: 12 })

              Text('重拾玫瑰')
                .fontSize(24)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .margin({ top: 14 })

              Text('忘记密码并不可怕 —— 玫瑰，依旧绽放为你')
                .fontSize(11)
                .fontColor(ElysiaTheme.INK_SOFT)
                .letterSpacing(2)
                .margin({ top: 6 })
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 20 })

            Column() {
              Column({ space: 10 }) {
                ElysiaInput({ placeholder: '学号', value: $sid })
                ElysiaInput({ placeholder: '校园邮箱', value: $email })
                Row({ space: 8 }) {
                  Column() { ElysiaInput({ placeholder: '6 位验证码', value: $code }) }.layoutWeight(1)
                  Button(this.codeCountdown > 0 ? `${this.codeCountdown}s` : '获取验证码')
                    .height(46).fontSize(11)
                    .backgroundColor(ElysiaTheme.glass())
                    .fontColor(this.codeCountdown > 0 ? ElysiaTheme.INK_SOFT : ElysiaTheme.ROSE_700)
                    .border({ width: 1, color: ElysiaTheme.hairline() })
                    .borderRadius(14)
                    .padding({ left: 12, right: 12 })
                    .onClick(() => { this.sendCode(); })
                }
                ElysiaInput({ placeholder: '新密码 ≥ 8 位', value: $newPwd, secure: true })
              }

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.ROSE_ACCENT)
                  .width('100%')
                  .padding({ left: 4 })
                  .margin({ top: 8 })
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.SUCCESS)
                  .width('100%')
                  .padding({ left: 4 })
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(22)
            .backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
            .margin({ top: 24 })

            PrimaryButton({
              text: this.submitting ? '重置中...' : '重 置 密 码 · RESET',
              onTap: () => { this.doReset(); }
            })
          }
          .padding({ left: 26, right: 26, bottom: 30 })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function ForgotPageBuilder() {
  NavDestination() {
    ForgotPage()
  }
  .hideTitleBar(true)
}
