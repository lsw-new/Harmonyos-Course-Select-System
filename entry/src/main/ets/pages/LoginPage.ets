// 登录页 · Login
import router from '@ohos.router';
import { ElysiaTheme, Gradients } from '../common/Theme';
import {
  Monogram, Sparkle, RoseIcon, ElysiaInput,
  PrimaryButton, GhostButton, RoseDivider
} from '../common/Components';

@Entry
@Component
struct LoginPage {
  @State studentId: string = '20231104';
  @State password: string = '';
  @State remember: boolean = true;

  build() {
    Stack() {
      // 背景渐变
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [ElysiaTheme.ROSE_50, 0],
            [ElysiaTheme.CREAM_50, 0.55],
            ['#FFF0F5', 1]
          ]
        })

      Scroll() {
        Column() {
          // 顶部状态栏占位
          Blank().height(50)

          // Monogram + 欢迎语
          Column() {
            Monogram({ iconSize: 72 })
            Text('Bonjour,')
              .fontSize(32)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
              .margin({ top: 18 })
            Text('Elysia.')
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
          RoseDivider({ label: 'sign in' })

          // 表单
          Column({ space: 12 }) {
            ElysiaInput({
              placeholder: '学号 / Student ID',
              value: $studentId,
              leadingIcon: 'mine'
            })
            ElysiaInput({
              placeholder: '密码 / Password',
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

              Text('forgot password ?')
                .fontSize(11)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/ForgotPage' });
                })
            }
            .width('100%')
            .padding({ left: 4, right: 4, top: 2 })
          }
          .width('100%')

          // 登录按钮
          Column({ space: 10 }) {
            PrimaryButton({
              text: '登 录 · ENTER',
              onTap: () => {
                router.pushUrl({ url: 'pages/HomePage' });
              }
            })
            GhostButton({
              text: '注册新账号 · Register',
              onTap: () => {
                router.pushUrl({ url: 'pages/RegisterPage' });
              }
            })
          }
          .width('100%')
          .margin({ top: 22 })

          // 底部 slogan
          Text('— Pardon me, may I have the pleasure of your name? —')
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
    }
    .width('100%')
    .height('100%')
  }
}
