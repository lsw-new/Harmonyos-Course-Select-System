// 找回密码 · Forgot Password
import { ElysiaTheme } from '../common/Theme';
import { TopBar, ElysiaInput, PrimaryButton, Sparkle } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { HttpError } from '../common/http/HttpError';

@Entry
@Component
struct ForgotPage {
  @State sid: string = '';
  @State phone: string = '';
  @State code: string = '';
  @State newPwd: string = '';
  @State method: number = 0; // 0 phone, 1 email
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State submitting: boolean = false;
  @State smsCountdown: number = 0;
  @StorageProp('darkMode') darkMode: boolean = false;

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

  private sendCode(): void {
    if (this.smsCountdown > 0) {
      return;
    }
    if (this.method === 0) {
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
    } else {
      const r = ValidatorUtils.email(this.phone);
      if (!r.ok) {
        this.errorMsg = r.message ?? '邮箱格式不正确';
        return;
      }
      this.errorMsg = '';
      this.startCountdown();
    }
  }

  private doReset(): void {
    if (this.submitting) {
      return;
    }
    const r1 = ValidatorUtils.required(this.sid, '学号');
    if (!r1.ok) { this.errorMsg = r1.message ?? ''; return; }
    if (this.method === 0) {
      const r2 = ValidatorUtils.phone(this.phone);
      if (!r2.ok) { this.errorMsg = r2.message ?? ''; return; }
    } else {
      const r2 = ValidatorUtils.email(this.phone);
      if (!r2.ok) { this.errorMsg = r2.message ?? ''; return; }
    }
    const r3 = ValidatorUtils.required(this.code, '验证码');
    if (!r3.ok) { this.errorMsg = r3.message ?? ''; return; }
    const r4 = ValidatorUtils.password(this.newPwd);
    if (!r4.ok) { this.errorMsg = r4.message ?? ''; return; }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().resetPassword({
      account: this.sid,
      contact: this.phone,
      verifyCode: this.code,
      newPassword: this.newPwd,
      method: this.method === 0 ? 'phone' : 'email'
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
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient(this.darkMode) })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Recover', subtitle: '找 回 密 码', onBack: () => AppRoute.back() })

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

              Text('Reclaim the rose')
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
              Row({ space: 8 }) {
                Button('手机验证')
                  .height(36)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.method === 0 ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor(this.method === 0 ? '' : '#00FFFFFF')
                  .linearGradient(this.method === 0 ? {
                    angle: 135,
                    colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]]
                  } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .border({ width: this.method === 0 ? 0 : 1, color: ElysiaTheme.hairline(this.darkMode) })
                  .borderRadius(12)
                  .onClick(() => { this.method = 0; })
                Button('校园邮箱')
                  .height(36)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor(this.method === 1 ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor(this.method === 1 ? '' : '#00FFFFFF')
                  .linearGradient(this.method === 1 ? {
                    angle: 135,
                    colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]]
                  } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .border({ width: this.method === 1 ? 0 : 1, color: ElysiaTheme.hairline(this.darkMode) })
                  .borderRadius(12)
                  .onClick(() => { this.method = 1; })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Column({ space: 10 }) {
                ElysiaInput({ placeholder: '学号', value: $sid })
                ElysiaInput({ placeholder: this.method === 0 ? '绑定手机号' : '校园邮箱', value: $phone })
                Row({ space: 8 }) {
                  Column() { ElysiaInput({ placeholder: '6 位验证码', value: $code }) }.layoutWeight(1)
                  Button(this.smsCountdown > 0 ? `${this.smsCountdown}s` : '获取验证码')
                    .height(46).fontSize(11)
                    .backgroundColor(ElysiaTheme.glass(this.darkMode))
                    .fontColor(this.smsCountdown > 0 ? ElysiaTheme.INK_SOFT : ElysiaTheme.ROSE_700)
                    .border({ width: 1, color: ElysiaTheme.hairline(this.darkMode) })
                    .borderRadius(14)
                    .padding({ left: 12, right: 12 })
                    .onClick(() => { this.sendCode(); })
                }
                ElysiaInput({ placeholder: '新密码 ≥ 8 位', value: $newPwd, secure: true })
              }

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg)
                  .fontSize(12)
                  .fontColor('#D8546B')
                  .width('100%')
                  .padding({ left: 4 })
                  .margin({ top: 8 })
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg)
                  .fontSize(12)
                  .fontColor('#7BB07B')
                  .width('100%')
                  .padding({ left: 4 })
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(22)
            .backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) })
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
    }
    .width('100%').height('100%')
  }
}
