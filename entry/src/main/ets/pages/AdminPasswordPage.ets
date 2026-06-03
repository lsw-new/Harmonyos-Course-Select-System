// 管理员修改密码 · Password
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { SysConfigRepository } from '../repositories/SysConfigRepository';
import { HttpError } from '../common/http/HttpError';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

const LETTER_PATTERN: RegExp = /[A-Za-z]/;
const DIGIT_PATTERN: RegExp = /[0-9]/;
const MIN_PWD_LENGTH = 8;

@Component
struct AdminPasswordPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State errorMsg: string = '';
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminPassword)) {
      return;
    }
  }

  private validate(): boolean {
    if (this.oldPassword.trim().length === 0) {
      this.errorMsg = '请输入原密码';
      return false;
    }
    if (this.newPassword.length === 0) {
      this.errorMsg = '请输入新密码';
      return false;
    }
    if (this.newPassword.length < MIN_PWD_LENGTH) {
      this.errorMsg = '新密码长度至少为 8 位';
      return false;
    }
    if (!LETTER_PATTERN.test(this.newPassword) || !DIGIT_PATTERN.test(this.newPassword)) {
      this.errorMsg = '新密码需同时包含字母和数字';
      return false;
    }
    if (this.newPassword === this.oldPassword) {
      this.errorMsg = '新密码不能与原密码相同';
      return false;
    }
    if (this.confirmPassword.length === 0) {
      this.errorMsg = '请再次输入新密码';
      return false;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.errorMsg = '两次新密码不一致';
      return false;
    }
    this.errorMsg = '';
    return true;
  }

  private submit(): void {
    if (this.submitting) return;
    if (!this.validate()) return;
    this.submitting = true;
    SysConfigRepository.get().changeAdminPassword(this.oldPassword, this.newPassword).then((_res: boolean) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '密码修改成功');
      AppRoute.back();
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '修改失败';
    });
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
              Text('修改管理员密码')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 10 })
              Text('新密码至少 8 位，且包含字母与数字')
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
            }
            .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(22)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })

            RoseDivider({ label: '表单' })

            Column({ space: 14 }) {
              ElysiaInput({ placeholder: '原密码', value: $oldPassword, secure: true, leadingIcon: 'lock' })
              ElysiaInput({ placeholder: '新密码', value: $newPassword, secure: true, leadingIcon: 'unlock' })
              ElysiaInput({ placeholder: '确认新密码', value: $confirmPassword, secure: true, leadingIcon: 'unlock' })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT).margin({ top: 4 })
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
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminPasswordPageBuilder() {
  NavDestination() {
    AdminPasswordPage()
  }
  .hideTitleBar(true)
}
