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
  // 验证码请求飞行中：按钮显示「发送中…」并禁用，防止重复点击触发后端 60s 重发节流
  @State codeSending: boolean = false;

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
    if (this.codeCountdown > 0 || this.codeSending) {
      return;
    }
    const r = ValidatorUtils.email(this.email);
    if (!r.ok) {
      this.errorMsg = r.message ?? '邮箱格式不正确';
      return;
    }
    this.errorMsg = '';
    this.successMsg = '';
    this.codeSending = true;
    AuthRepository.get().sendEmailCode(this.email).then((_res: boolean) => {
      this.codeSending = false;
      this.successMsg = '验证码已发送，请查收邮箱（5 分钟内有效）';
      this.startCountdown();
    }).catch((e: object) => {
      this.codeSending = false;
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
        TopBar({ title: $r('app.string.forgot_title'), subtitle: $r('app.string.forgot_subtitle'), onBack: () => AppRoute.back() })

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

              Text($r('app.string.forgot_heading'))
                .fontSize(24)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .margin({ top: 14 })

              Text($r('app.string.forgot_sub'))
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
                ElysiaInput({ placeholder: $r('app.string.common_student_id'), value: $sid })
                ElysiaInput({ placeholder: $r('app.string.forgot_email'), value: $email })
                Row({ space: 8 }) {
                  Column() { ElysiaInput({ placeholder: $r('app.string.common_code6'), value: $code }) }.layoutWeight(1)
                  Button(this.codeCountdown > 0
                    ? `${this.codeCountdown}s`
                    : (this.codeSending ? $r('app.string.common_code_sending') : $r('app.string.forgot_get_code')))
                    .height(46).fontSize(11)
                    .backgroundColor(ElysiaTheme.glass())
                    .fontColor(this.codeCountdown > 0 || this.codeSending ? ElysiaTheme.INK_SOFT : ElysiaTheme.ROSE_700)
                    .border({ width: 1, color: ElysiaTheme.hairline() })
                    .borderRadius(14)
                    .padding({ left: 12, right: 12 })
                    .enabled(this.codeCountdown === 0 && !this.codeSending)
                    .onClick(() => { this.sendCode(); })
                }
                ElysiaInput({ placeholder: $r('app.string.forgot_new_pwd'), value: $newPwd, secure: true })
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
              text: this.submitting ? $r('app.string.forgot_submitting') : $r('app.string.forgot_submit'),
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
