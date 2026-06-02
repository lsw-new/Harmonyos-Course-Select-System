// 修改资料 · Edit Profile
import { ElysiaTheme } from '../common/Theme';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { HttpError } from '../common/http/HttpError';
import { UserProfile } from '../models/User';
import { LoadingState } from '../common/widgets/StateViews';
import { FileService } from '../common/services/FileService';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

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
  @State avatarUrl: string = '';
  @State pickingAvatar: boolean = false;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.EditInfo)) {
      return;
    }
    ProfileRepository.get().getProfile().then((p: UserProfile) => {
      this.studentId = p.studentId;
      this.name = p.name;
      this.college = p.college;
      this.major = p.major;
      this.className = p.className;
      this.avatarUrl = p.avatarUrl ?? '';
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

  private pickAvatar(): void {
    if (this.pickingAvatar) return;
    this.errorMsg = '';
    this.successMsg = '';
    this.pickingAvatar = true;
    FileService.pickAvatarImage().then((uri: string) => {
      return ProfileRepository.get().updateProfile({ avatarUrl: uri });
    }).then((p: UserProfile) => {
      this.avatarUrl = p.avatarUrl ?? '';
      this.pickingAvatar = false;
      this.successMsg = '头像已更新';
    }).catch((e: object) => {
      this.pickingAvatar = false;
      this.errorMsg = e instanceof Error ? e.message : '选择头像失败';
    });
  }

  @Builder ReadonlyRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: '#22FFB3CE' })
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
        TopBar({ title: '修改资料', subtitle: '修 改 资 料', onBack: () => AppRoute.back() })

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
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              Column() {
                Text('头像').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                Row() {
                  Column() {
                    Text(this.avatarUrl.length > 0 ? '已选择' : '未选择')
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
                    Text(this.avatarUrl.length > 0 ? this.avatarUrl : '点击右侧按钮选择本地图片')
                      .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 }).maxLines(2)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text(this.pickingAvatar ? '选择中...' : '选择头像')
                    .fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                    .onClick(() => this.pickAvatar())
                }
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              RoseDivider({ label: '可编辑' })

              Column({ space: 12 }) {
                ElysiaInput({ placeholder: '手机号', value: $phone, leadingIcon: 'phone' })
                ElysiaInput({ placeholder: '邮箱', value: $email, leadingIcon: 'mail' })
                ElysiaInput({ placeholder: '通讯地址', value: $address, leadingIcon: 'location' })
                ElysiaInput({ placeholder: '紧急联系人', value: $emergencyContact, leadingIcon: 'phone' })
                TextArea({ placeholder: '个人简介', text: this.bio })
                  .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
                  .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .onChange((v: string) => { this.bio = v; })

                if (this.errorMsg.length > 0) {
                  Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
                }
                if (this.successMsg.length > 0) {
                  Text(this.successMsg).fontSize(12).fontColor('#7BB07B')
                }

                PrimaryButton({ text: this.submitting ? '保存中...' : '保存修改', onTap: () => this.submit() })
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }
}
