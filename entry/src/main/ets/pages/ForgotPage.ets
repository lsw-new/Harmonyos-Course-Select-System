// 找回密码 · Forgot Password
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, ElysiaInput, PrimaryButton, Sparkle } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';

@Entry
@Component
struct ForgotPage {
  @State sid: string = '';
  @State phone: string = '';
  @State code: string = '';
  @State newPwd: string = '';
  @State method: number = 0; // 0 phone, 1 email

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Recover', subtitle: '找 回 密 码', onBack: () => router.back() })

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
                  .border({ width: this.method === 0 ? 0 : 1, color: '#99FFB3CE' })
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
                  .border({ width: this.method === 1 ? 0 : 1, color: '#99FFB3CE' })
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
                  Button('59 s').height(46).fontSize(11)
                    .backgroundColor('#B3FFFFFF')
                    .fontColor(ElysiaTheme.ROSE_700)
                    .border({ width: 1, color: '#80FFB3CE' })
                    .borderRadius(14)
                    .padding({ left: 12, right: 12 })
                }
                ElysiaInput({ placeholder: '新密码 ≥ 8 位', value: $newPwd, secure: true })
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(22)
            .backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: '#66FFB3CE' })
            .margin({ top: 24 })

            PrimaryButton({ text: '重 置 密 码 · RESET', onTap: () => router.back() })
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
