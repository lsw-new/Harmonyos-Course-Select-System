// 管理员登录 · Sign in
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, GhostButton, ElysiaInput, Pill, Monogram } from '../common/Components';
import { AuthRepository } from '../repositories/AuthRepository';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppRoute, Routes } from '../app/AppRoute';
import { HttpError } from '../common/http/HttpError';
import { AdminProfile, AdminLoginResult } from '../models/Admin';

@Entry
@Component
struct AdminLoginPage {
  @State adminId: string = '';
  @State password: string = '';
  @State captcha: string = '';
  @State remember: boolean = false;
  @State errorMsg: string = '';
  @State submitting: boolean = false;
  @State captchaCode: string = '3A7F';
  @StorageProp('darkMode') darkMode: boolean = false;

  private refreshCaptcha(): void {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 4; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    this.captchaCode = code;
  }

  private login(): void {
    if (this.submitting) return;
    if (this.adminId.trim().length === 0) { this.errorMsg = '请输入工号'; return; }
    if (this.password.length === 0) { this.errorMsg = '请输入密码'; return; }
    if (this.captcha.length !== 4) { this.errorMsg = '请输入 4 位验证码'; return; }
    this.errorMsg = '';
    this.submitting = true;
    AuthRepository.get().adminLogin({
      adminId: this.adminId, password: this.password,
      captcha: this.captcha, remember: this.remember
    }).then((res: AdminLoginResult) => {
      SessionStorage.get().setAdminSession(res.token, res.profile).then(() => {
        AppRoute.clearTo(Routes.AdminDashboard);
      });
    }).catch((e: object) => {
      this.submitting = false;
      this.refreshCaptcha();
      this.captcha = '';
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '登录失败';
    });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient(this.darkMode) })

      Column() {
        Blank().height(60)

        Column({ space: 6 }) {
          Monogram({ iconSize: 56 })
          Pill({ text: 'ADMIN · 教务' })
          Text('管理员控制台登录')
            .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 8 }).padding({ bottom: 24 })
        }.width('100%').alignItems(HorizontalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            ElysiaInput({ placeholder: '工号', value: $adminId, leadingIcon: 'students' })
            ElysiaInput({ placeholder: '密码', value: $password, secure: true, leadingIcon: 'lock' })

            Row({ space: 10 }) {
              TextInput({ placeholder: '验证码', text: this.captcha })
                .type(InputType.Normal).height(46).fontSize(13)
                .fontColor(ElysiaTheme.INK).placeholderColor(ElysiaTheme.INK_MUTE)
                .backgroundColor(ElysiaTheme.glass(this.darkMode)).border({ width: 1, color: ElysiaTheme.hairline(this.darkMode) }).borderRadius(14)
                .layoutWeight(1)
                .onChange((v: string) => { this.captcha = v; })
              Text(this.captchaCode)
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
                .letterSpacing(4).padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor('#FFE9F1').borderRadius(10)
                .onClick(() => { this.refreshCaptcha(); })
            }.width('100%')

            Row() {
              Toggle({ type: ToggleType.Checkbox, isOn: this.remember })
                .selectedColor(ElysiaTheme.ROSE_500).width(18).height(18)
                .onChange((v: boolean) => { this.remember = v; })
              Text('本机记住').fontSize(12).fontColor(ElysiaTheme.ROSE_500)
            }.width('100%').alignItems(VerticalAlign.Center)

            if (this.errorMsg.length > 0) {
              Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
            }

            PrimaryButton({ text: this.submitting ? '登录中...' : '进入控制台', onTap: () => this.login() })
            GhostButton({
              text: '返回学生登录',
              onTap: () => {
                AppRoute.go(Routes.Login, { replace: true });
              }
            })

            Blank().height(40)
          }.padding({ left: 24, right: 24 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
