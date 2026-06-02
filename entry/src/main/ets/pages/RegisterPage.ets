// 注册 · Register
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, ElysiaInput, PrimaryButton } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { HttpError } from '../common/http/HttpError';
import { SafeTop } from '../common/widgets/SafeArea';

@Entry
@Component
struct RegisterPage {
  @State sid: string = '';
  @State name: string = '';
  @State phone: string = '';
  @State code: string = '';
  @State pwd: string = '';
  @State pwd2: string = '';
  @State agreed: boolean = true;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State submitting: boolean = false;
  @State smsCountdown: number = 0;

  private countdownTimer: number = -1;

  private startCountdown(): void {
    this.smsCountdown = 60;
    this.countdownTimer = setInterval(() => {
      this.smsCountdown -= 1;
      if (this.smsCountdown <= 0) {
        clearInterval(this.countdownTimer);
        this.countdownTimer = -1;
        this.smsCountdown = 0;
      }
    }, 1000);
  }

  private sendSms(): void {
    if (this.smsCountdown > 0) {
      return;
    }
    const r = ValidatorUtils.phone(this.phone);
    if (!r.ok) {
      this.errorMsg = r.message ?? '手机号格式不正确';
      return;
    }
    this.errorMsg = '';
    AuthRepository.get().sendSms(this.phone).then((_res: boolean) => {
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
    const r3 = ValidatorUtils.phone(this.phone);
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
      phone: this.phone,
      smsCode: this.code,
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

  pageTransition() {
    PageTransitionEnter({ duration: 280, curve: Curve.Friction })
      .slide(SlideEffect.Right)
      .opacity(0.4)
    PageTransitionExit({ duration: 240, curve: Curve.Friction })
      .slide(SlideEffect.Left)
      .opacity(0.4)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '注册', subtitle: '注 册', onBack: () => AppRoute.back() })

        Scroll() {
          Column() {
            Text('开启你的故事')
              .fontSize(24)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 6, bottom: 4 })
            Text('填写以下信息以开始你的旅程')
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_SOFT)
              .letterSpacing(2)
              .margin({ bottom: 16 })

            Column({ space: 10 }) {
              ElysiaInput({ placeholder: '学号', value: $sid })
              ElysiaInput({ placeholder: '姓名', value: $name })
              ElysiaInput({ placeholder: '手机号 / +86 13800138000', value: $phone })
              Row({ space: 8 }) {
                Column() { ElysiaInput({ placeholder: '6 位验证码', value: $code }) }.layoutWeight(1)
                Button(this.smsCountdown > 0 ? `${this.smsCountdown}s` : '获取')
                  .height(46).fontSize(11)
                  .backgroundColor(ElysiaTheme.glass())
                  .fontColor(this.smsCountdown > 0 ? ElysiaTheme.INK_SOFT : ElysiaTheme.ROSE_700)
                  .border({ width: 1, color: ElysiaTheme.hairline() })
                  .borderRadius(14)
                  .padding({ left: 14, right: 14 })
                  .onClick(() => { this.sendSms(); })
              }
              ElysiaInput({ placeholder: '初始密码', value: $pwd, secure: true })
              ElysiaInput({ placeholder: '确认密码', value: $pwd2, secure: true })
            }
            .width('100%')

            Row() {
              Toggle({ type: ToggleType.Checkbox, isOn: this.agreed })
                .width(16).height(16)
                .selectedColor(ElysiaTheme.ROSE_500)
                .onChange((v: boolean) => { this.agreed = v; })
              Text('  我已阅读并同意《用户协议》与《隐私政策》')
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
                .fontColor('#D8546B')
                .width('100%')
                .padding({ left: 4 })
                .margin({ top: 6 })
            }
            if (this.successMsg.length > 0) {
              Text(this.successMsg)
                .fontSize(12)
                .fontColor('#7BB07B')
                .width('100%')
                .padding({ left: 4 })
                .margin({ top: 6 })
            }

            PrimaryButton({
              text: this.submitting ? '提交中...' : '提交注册 · CREATE',
              onTap: () => { this.doRegister(); }
            })

            Row() {
              Text('已有账号？')
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
              Text('  登录')
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
    }
    .width('100%').height('100%')
  }
}
