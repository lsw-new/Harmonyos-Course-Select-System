// 注册 · Register
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, ElysiaInput, PrimaryButton } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { HttpError } from '../common/http/HttpError';
import { SafeTop } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct RegisterPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State sid: string = '';
  @State name: string = '';
  @State email: string = '';
  @State code: string = '';
  @State pwd: string = '';
  @State pwd2: string = '';
  @State agreed: boolean = true;
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

  private sendEmailCode(): void {
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

  private doRegister(): void {
    if (this.submitting) {
      return;
    }
    const r1 = ValidatorUtils.required(this.sid, '学号');
    if (!r1.ok) { this.errorMsg = r1.message ?? ''; return; }
    const r2 = ValidatorUtils.required(this.name, '姓名');
    if (!r2.ok) { this.errorMsg = r2.message ?? ''; return; }
    const r3 = ValidatorUtils.email(this.email);
    if (!r3.ok) { this.errorMsg = r3.message ?? ''; return; }
    const r4 = ValidatorUtils.required(this.code, '验证码');
    if (!r4.ok) { this.errorMsg = r4.message ?? ''; return; }
    const r5 = ValidatorUtils.password(this.pwd);
    if (!r5.ok) { this.errorMsg = r5.message ?? ''; return; }
    const r6 = ValidatorUtils.match(this.pwd, this.pwd2, '两次密码');
    if (!r6.ok) { this.errorMsg = r6.message ?? ''; return; }
    if (!this.agreed) {
      this.errorMsg = '请先同意用户协议';
      return;
    }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().register({
      studentId: this.sid,
      name: this.name,
      email: this.email,
      emailCode: this.code,
      password: this.pwd,
      confirmPassword: this.pwd2,
      agreed: this.agreed
    }).then((_res: boolean) => {
      this.submitting = false;
      this.successMsg = '注册成功，请登录';
      AppRoute.go(Routes.Login, { replace: true });
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '注册失败';
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.register_title'), subtitle: $r('app.string.register_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Column() {
            Text($r('app.string.register_heading'))
              .fontSize(24)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 6, bottom: 4 })
            Text($r('app.string.register_sub'))
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_SOFT)
              .letterSpacing(2)
              .margin({ bottom: 16 })

            Column({ space: 10 }) {
              ElysiaInput({ placeholder: $r('app.string.common_student_id'), value: $sid })
              ElysiaInput({ placeholder: $r('app.string.common_name'), value: $name })
              ElysiaInput({ placeholder: $r('app.string.register_email'), value: $email })
              Row({ space: 8 }) {
                Column() { ElysiaInput({ placeholder: $r('app.string.common_code6'), value: $code }) }.layoutWeight(1)
                Button(this.codeCountdown > 0 ? `${this.codeCountdown}s` : $r('app.string.register_get_code'))
                  .height(46).fontSize(11)
                  .backgroundColor(ElysiaTheme.glass())
                  .fontColor(this.codeCountdown > 0 ? ElysiaTheme.INK_SOFT : ElysiaTheme.ROSE_700)
                  .border({ width: 1, color: ElysiaTheme.hairline() })
                  .borderRadius(14)
                  .padding({ left: 14, right: 14 })
                  .onClick(() => { this.sendEmailCode(); })
              }
              ElysiaInput({ placeholder: $r('app.string.register_pwd'), value: $pwd, secure: true })
              ElysiaInput({ placeholder: $r('app.string.register_pwd2'), value: $pwd2, secure: true })
            }
            .width('100%')

            Row() {
              Toggle({ type: ToggleType.Checkbox, isOn: this.agreed })
                .width(16).height(16)
                .selectedColor(ElysiaTheme.ROSE_500)
                .onChange((v: boolean) => { this.agreed = v; })
              Text($r('app.string.register_agree'))
                .fontSize(11)
                .fontColor(ElysiaTheme.INK_SOFT)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
            .borderRadius(22)
            .margin({ top: 14 })

            if (this.errorMsg.length > 0) {
              Text(this.errorMsg)
                .fontSize(12)
                .fontColor(ElysiaTheme.ROSE_ACCENT)
                .width('100%')
                .padding({ left: 4 })
                .margin({ top: 6 })
            }
            if (this.successMsg.length > 0) {
              Text(this.successMsg)
                .fontSize(12)
                .fontColor(ElysiaTheme.SUCCESS)
                .width('100%')
                .padding({ left: 4 })
                .margin({ top: 6 })
            }

            PrimaryButton({
              text: this.submitting ? $r('app.string.register_submitting') : $r('app.string.register_submit'),
              onTap: () => { this.doRegister(); }
            })

            Row() {
              Text($r('app.string.register_have_account'))
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
              Text($r('app.string.register_login_link'))
                .fontSize(11)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .onClick(() => AppRoute.go(Routes.Login, { replace: true }))
            }
            .justifyContent(FlexAlign.Center)
            .margin({ top: 14, bottom: 24 })
            .width('100%')
          }
          .padding({ left: 18, right: 18 })
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
export function RegisterPageBuilder() {
  NavDestination() {
    RegisterPage()
  }
  .hideTitleBar(true)
}
