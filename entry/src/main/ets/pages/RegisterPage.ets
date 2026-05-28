// 注册 · Register
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, ElysiaInput, PrimaryButton } from '../common/Components';

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

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Register', subtitle: '注 册', onBack: () => router.back() })

        Scroll() {
          Column() {
            Text('Create your story')
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
              ElysiaInput({ placeholder: '学号 / ID', value: $sid })
              ElysiaInput({ placeholder: '姓名 / Name', value: $name })
              ElysiaInput({ placeholder: '手机号 / +86 13800138000', value: $phone })
              Row({ space: 8 }) {
                Column() { ElysiaInput({ placeholder: '6 位验证码', value: $code }) }.layoutWeight(1)
                Button('获取').height(46).fontSize(11)
                  .backgroundColor('#B3FFFFFF')
                  .fontColor(ElysiaTheme.ROSE_700)
                  .border({ width: 1, color: '#80FFB3CE' })
                  .borderRadius(14)
                  .padding({ left: 14, right: 14 })
              }
              ElysiaInput({ placeholder: '初始密码 / Password', value: $pwd, secure: true })
              ElysiaInput({ placeholder: '确认密码 / Confirm', value: $pwd2, secure: true })
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
            .border({ width: 1, color: '#66FFB3CE' })
            .borderRadius(22)
            .margin({ top: 14 })

            PrimaryButton({
              text: '提交注册 · CREATE',
              onTap: () => router.back()
            })

            Row() {
              Text('已有账号？')
                .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
              Text('  Sign in')
                .fontSize(11)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .onClick(() => router.back())
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
