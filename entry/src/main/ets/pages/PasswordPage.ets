// 修改密码 · Password
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, GlowCard, Pill } from '../common/Components';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { AuthRepository } from '../repositories/AuthRepository';
import { HttpError } from '../common/http/HttpError';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { SessionStorage } from '../common/storage/SessionStorage';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct PasswordPage {
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State errorMsg: string = '';
  @State submitting: boolean = false;
  @State successMsg: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Password)) {
      return;
    }
  }

  private getStrengthLabel(): string {
    if (this.newPassword.length === 0) return '';
    const s = ValidatorUtils.passwordStrength(this.newPassword);
    if (s === 'weak') return '弱';
    if (s === 'medium') return '中';
    return '强';
  }

  private getStrengthColor(): string {
    const s = ValidatorUtils.passwordStrength(this.newPassword);
    if (s === 'weak') return '#D8546B';
    if (s === 'medium') return '#D9B675';
    return '#7BB07B';
  }

  private validate(): boolean {
    const r1 = ValidatorUtils.required(this.oldPassword, '原密码');
    if (!r1.ok) { this.errorMsg = r1.message ?? ''; return false; }
    if (this.newPassword === this.oldPassword) {
      this.errorMsg = '新密码不能与原密码相同';
      return false;
    }
    const r2 = ValidatorUtils.password(this.newPassword);
    if (!r2.ok) { this.errorMsg = r2.message ?? ''; return false; }
    const r3 = ValidatorUtils.match(this.newPassword, this.confirmPassword, '两次新密码');
    if (!r3.ok) { this.errorMsg = r3.message ?? ''; return false; }
    this.errorMsg = '';
    return true;
  }

  private submit(): void {
    if (!this.validate() || this.submitting) return;
    this.submitting = true;
    AuthRepository.get().changePassword({
      oldPassword: this.oldPassword,
      newPassword: this.newPassword,
      confirmPassword: this.confirmPassword
    }).then((_res: boolean) => {
      this.submitting = false;
      this.successMsg = '密码修改成功，请重新登录';
      AuthRepository.get().logout().then((_r: boolean) => {
        return SessionStorage.get().clear();
      }).then(() => {
        AppRoute.clearTo(Routes.Login);
      });
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '修改失败';
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
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '修改密码', subtitle: '修 改 密 码', onBack: () => AppRoute.back() })

        Scroll() {
          Column() {
            Column() {
              Pill({ text: '账户安全' })
              Text('修改登录密码')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 10 })
              Text('修改后需重新登录')
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
            }
            .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(22)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })

            RoseDivider({ label: '表单' })

            Column({ space: 14 }) {
              ElysiaInput({ placeholder: '原密码', value: $oldPassword, secure: true, leadingIcon: 'lock' })
              ElysiaInput({ placeholder: '新密码', value: $newPassword, secure: true, leadingIcon: 'unlock' })

              if (this.newPassword.length > 0) {
                Row() {
                  Text('密码强度：').fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  Text(this.getStrengthLabel()).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.getStrengthColor())
                }
                .width('100%').padding({ left: 4 })
              }

              ElysiaInput({ placeholder: '确认新密码', value: $confirmPassword, secure: true, leadingIcon: 'unlock' })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg).fontSize(12).fontColor('#D8546B').margin({ top: 4 })
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg).fontSize(12).fontColor('#7BB07B').margin({ top: 4 })
              }

              PrimaryButton({ text: this.submitting ? '提交中...' : '确认修改', onTap: () => this.submit() })
            }
            .width('100%').padding(18).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
            .shadow({ radius: 16, color: '#1FD85487', offsetX: 0, offsetY: 4 })

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
