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
import { LoginResult } from '../models/User';
import { SafeTop } from '../common/widgets/SafeArea';

@Component
struct LoginPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State studentId: string = '';
  @State password: string = '';
  @State remember: boolean = true;
  @State errorMsg: string = '';
  @State submitting: boolean = false;

  aboutToAppear(): void {
    SessionStorage.get().getRememberId().then((id: string) => {
      if (id.length > 0) {
        this.studentId = id;
      }
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
    }).then((res: LoginResult) => {
      const s = SessionStorage.get();
      const rememberOp = this.remember
        ? s.saveRememberId(this.studentId)
        : s.clearRememberId();
      return rememberOp.then(() => s.setStudentSession(res.token, res.user));
    }).then(() => {
      AppRoute.clearTo(Routes.Home);
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '登录失败';
    });
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
            Text('你好，')
              .fontSize(32)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 18 })
            Text('景德镇艺术职业大学')
              .fontSize(32)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: -4 })
            Text('欢迎回到 · 教学管理学生端')
              .fontSize(11)
              .fontColor(ElysiaTheme.INK_SOFT)
              .letterSpacing(4)
              .margin({ top: 10 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 24 })

          // 分隔
          RoseDivider({ label: '登录' })

          // 表单
          Column({ space: 12 }) {
            ElysiaInput({
              placeholder: '学号',
              value: $studentId,
              leadingIcon: 'mine'
            })
            ElysiaInput({
              placeholder: '密码',
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
                Text('  记住我')
                  .fontSize(11)
                  .fontColor(ElysiaTheme.INK_SOFT)
              }

              Blank().layoutWeight(1)

              Text('忘记密码？')
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
              text: this.submitting ? '登录中...' : '登 录 · ENTER',
              onTap: () => { this.doLogin(); }
            })
            GhostButton({
              text: '注册新账号',
              onTap: () => {
                AppRoute.go(Routes.Register);
              }
            })
            GhostButton({
              text: '管理员登录',
              onTap: () => {
                AppRoute.go(Routes.AdminLogin);
              }
            })
          }
          .width('100%')
          .margin({ top: 22 })

          // 底部 slogan
          Text('— 敢问芳名？ —')
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
