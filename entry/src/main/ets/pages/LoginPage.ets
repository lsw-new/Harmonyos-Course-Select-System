// 登录页 · Login
import { ElysiaTheme, Gradients } from '../common/Theme';
import {
  Monogram, Sparkle, RoseIcon, ElysiaInput,
  PrimaryButton, GhostButton, RoseDivider
} from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { SessionStorage } from '../common/storage/SessionStorage';
import { HttpError } from '../common/http/HttpError';
import { LoginOutcome, LoginResult } from '../models/User';
import { SafeTop } from '../common/widgets/SafeArea';

@Component
struct LoginPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State studentId: string = '';
  @State password: string = '';
  @State remember: boolean = true;
  @State errorMsg: string = '';
  @State submitting: boolean = false;
  // #12 登录二次验证步骤状态
  @State twoFactorStep: boolean = false;
  @State twoFactorAccount: string = '';
  @State twoFactorEmail: string = '';
  @State twoFactorCode: string = '';

  aboutToAppear(): void {
    SessionStorage.get().getRememberId().then((id: string) => {
      if (id.length > 0) {
        this.studentId = id;
      }
    });
  }

  // 记住我：登录/验证成功后统一保存或清除已记住的学号，再进入首页
  private finishLogin(): void {
    const s = SessionStorage.get();
    // roadmap #6：教师会话跳教师端首页，其余（学生）进学生首页
    const target: string = s.getRole() === 'teacher' ? Routes.TeacherHome : Routes.Home;
    const rememberOp = this.remember
      ? s.saveRememberId(this.studentId)
      : s.clearRememberId();
    rememberOp.then(() => {
      AppRoute.clearTo(target);
    }).catch(() => {
      // 记住我写入失败不阻断登录主流程
      AppRoute.clearTo(target);
    });
  }

  private doLogin(): void {
    if (this.submitting) {
      return;
    }
    const r1 = ValidatorUtils.required(this.studentId, '学号');
    if (!r1.ok) {
      this.errorMsg = r1.message ?? '';
      return;
    }
    const r2 = ValidatorUtils.required(this.password, '密码');
    if (!r2.ok) {
      this.errorMsg = r2.message ?? '';
      return;
    }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().login({
      studentId: this.studentId,
      password: this.password,
      remember: this.remember
    }).then((outcome: LoginOutcome) => {
      this.submitting = false;
      if (outcome.kind === 'twoFactor') {
        // 需邮箱二次验证：会话尚未建立，切到验证码步骤
        this.twoFactorAccount = outcome.account ?? this.studentId;
        this.twoFactorEmail = outcome.email ?? '';
        this.twoFactorCode = '';
        this.twoFactorStep = true;
        return;
      }
      // 2FA 关闭：会话已在仓储建立，直接进入首页
      this.finishLogin();
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '登录失败';
    });
  }

  // #12 提交登录二次验证码
  private doVerify(): void {
    if (this.submitting) {
      return;
    }
    const r = ValidatorUtils.required(this.twoFactorCode, '验证码');
    if (!r.ok) {
      this.errorMsg = r.message ?? '';
      return;
    }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().verifyLoginCode(this.twoFactorAccount, this.twoFactorCode)
      .then((_res: LoginResult) => {
        this.submitting = false;
        this.finishLogin();
      }).catch((e: object) => {
        this.submitting = false;
        this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败';
      });
  }

  // 返回重新输入账号密码
  private backToCredentials(): void {
    this.twoFactorStep = false;
    this.twoFactorCode = '';
    this.errorMsg = '';
    this.submitting = false;
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      // 背景渐变
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Scroll() {
        Column() {
          // 顶部状态栏占位
          SafeTop()

          // Monogram + 欢迎语
          Column() {
            Monogram({ iconSize: 72 })
            Text($r('app.string.login_hello'))
              .fontSize(32)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 18 })
            Text($r('app.string.common_school'))
              .fontSize(32)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: -4 })
            Text($r('app.string.login_welcome'))
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_SOFT)
              .letterSpacing(4)
              .margin({ top: 10 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 24 })

          // 分隔
          RoseDivider({ label: $r('app.string.login_divider') })

          if (!this.twoFactorStep) {
            // 表单
            Column({ space: 12 }) {
              ElysiaInput({
                placeholder: $r('app.string.common_student_id'),
                value: $studentId,
                leadingIcon: 'mine'
              })
              ElysiaInput({
                placeholder: $r('app.string.common_password'),
                value: $password,
                secure: true,
                leadingIcon: 'lock'
              })

              // 记住我 / 忘记密码
              Row() {
                Row() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.remember })
                    .width(14).height(14)
                    .selectedColor(ElysiaTheme.ROSE_500)
                    .onChange((v: boolean) => { this.remember = v; })
                  Text($r('app.string.login_remember'))
                    .fontSize(11)
                    .fontColor(ElysiaTheme.INK_SOFT)
                    .margin({ left: 4 })
                }

                Blank().layoutWeight(1)

                Text($r('app.string.login_forgot'))
                  .fontSize(11)
                  .fontStyle(FontStyle.Italic)
                  .fontColor(ElysiaTheme.ROSE_700)
                  .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  .onClick(() => {
                    AppRoute.go(Routes.Forgot);
                  })
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 2 })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.ROSE_ACCENT)
                  .width('100%')
                  .padding({ left: 4 })
              }
            }
            .width('100%')

            // 登录按钮
            Column({ space: 10 }) {
              PrimaryButton({
                text: this.submitting ? $r('app.string.login_submitting') : $r('app.string.login_submit'),
                onTap: () => { this.doLogin(); }
              })
              GhostButton({
                text: $r('app.string.login_register'),
                onTap: () => {
                  AppRoute.go(Routes.Register);
                }
              })
              GhostButton({
                text: $r('app.string.login_admin'),
                onTap: () => {
                  AppRoute.go(Routes.AdminLogin);
                }
              })
            }
            .width('100%')
            .margin({ top: 22 })
          } else {
            // #12 登录二次验证步骤：脱敏邮箱 + 验证码输入
            Column({ space: 12 }) {
              Text('登录二次验证')
                .fontSize(15)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text(`验证码已发送至 ${this.twoFactorEmail}，请输入邮箱收到的验证码`)
                .fontSize(12)
                .fontColor(ElysiaTheme.INK_SOFT)
                .width('100%')
                .margin({ bottom: 2 })

              ElysiaInput({
                placeholder: $r('app.string.common_code6'),
                value: $twoFactorCode,
                leadingIcon: 'lock'
              })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.ROSE_ACCENT)
                  .width('100%')
                  .padding({ left: 4 })
              }
            }
            .width('100%')

            Column({ space: 10 }) {
              PrimaryButton({
                text: this.submitting ? $r('app.string.login_submitting') : '验证并登录',
                onTap: () => { this.doVerify(); }
              })
              GhostButton({
                text: '返回重新登录',
                onTap: () => { this.backToCredentials(); }
              })
            }
            .width('100%')
            .margin({ top: 22 })
          }

          // 底部 slogan
          Text($r('app.string.login_slogan'))
            .fontSize(10)
            .fontColor(ElysiaTheme.INK_MUTE)
            .letterSpacing(2)
            .margin({ top: 28 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 26, right: 26 })
      }
      .scrollBar(BarState.Off)
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%')
    .height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function LoginPageBuilder() {
  NavDestination() {
    LoginPage()
  }
  .hideTitleBar(true)
}
