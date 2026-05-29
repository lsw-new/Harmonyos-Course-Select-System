// 修改资料 · Edit Profile
import { ElysiaTheme } from '../common/Theme';
import { AppRoute } from '../app/AppRoute';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { HttpError } from '../common/http/HttpError';
import { UserProfile } from '../models/User';
import { LoadingState } from '../common/widgets/StateViews';

@Entry
@Component
struct EditInfoPage {
  @State loading: boolean = true;
  @State phone: string = '';
  @State email: string = '';
  @State address: string = '';
  @State emergencyContact: string = '';
  @State bio: string = '';
  @State errorMsg: string = '';
  @State submitting: boolean = false;
  @State successMsg: string = '';
  @State studentId: string = '';
  @State name: string = '';
  @State college: string = '';
  @State major: string = '';
  @State className: string = '';

  aboutToAppear(): void {
    ProfileRepository.get().getProfile().then((p: UserProfile) => {
      this.studentId = p.studentId;
      this.name = p.name;
      this.college = p.college;
      this.major = p.major;
      this.className = p.className;
      this.phone = p.phone ?? '';
      this.email = p.email ?? '';
      this.address = p.address ?? '';
      this.emergencyContact = p.emergencyContact ?? '';
      this.bio = p.bio ?? '';
      this.loading = false;
    }).catch(() => { this.loading = false; });
  }

  private submit(): void {
    if (this.submitting) return;
    if (this.phone.length > 0) {
      const r = ValidatorUtils.phone(this.phone);
      if (!r.ok) { this.errorMsg = r.message ?? ''; return; }
    }
    if (this.email.length > 0) {
      const r = ValidatorUtils.email(this.email);
      if (!r.ok) { this.errorMsg = r.message ?? ''; return; }
    }
    this.errorMsg = '';
    this.submitting = true;
    ProfileRepository.get().updateProfile({
      phone: this.phone, email: this.email, address: this.address,
      emergencyContact: this.emergencyContact, bio: this.bio
    }).then(() => {
      this.submitting = false;
      this.successMsg = '资料已更新';
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  @Builder ReadonlyRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: '#22FFB3CE' })
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Edit', subtitle: '修 改 资 料', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column() {
                Text('基本信息（只读）').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
                this.ReadonlyRow('学号', this.studentId)
                this.ReadonlyRow('姓名', this.name)
                this.ReadonlyRow('学院', this.college)
                this.ReadonlyRow('专业', this.major)
                this.ReadonlyRow('班级', this.className)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              RoseDivider({ label: 'editable' })

              Column({ space: 12 }) {
                ElysiaInput({ placeholder: '手机号', value: $phone, leadingIcon: 'phone' })
                ElysiaInput({ placeholder: '邮箱', value: $email, leadingIcon: 'mail' })
                ElysiaInput({ placeholder: '通讯地址', value: $address, leadingIcon: 'location' })
                ElysiaInput({ placeholder: '紧急联系人', value: $emergencyContact, leadingIcon: 'phone' })
                TextArea({ placeholder: '个人简介', text: this.bio })
                  .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
                  .backgroundColor('#CCFFFFFF').border({ width: 1, color: '#80FFB3CE' }).borderRadius(14)
                  .onChange((v: string) => { this.bio = v; })

                if (this.errorMsg.length > 0) {
                  Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
                }
                if (this.successMsg.length > 0) {
                  Text(this.successMsg).fontSize(12).fontColor('#7BB07B')
                }

                PrimaryButton({ text: this.submitting ? '保存中...' : '保存修改', onTap: () => this.submit() })
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              Blank().height(40)
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }
}
