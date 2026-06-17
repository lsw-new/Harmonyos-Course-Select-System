// 修改资料 · Edit Profile
import { ElysiaTheme } from '../common/Theme';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { ValidatorUtils } from '../common/utils/ValidatorUtils';
import { HttpError } from '../common/http/HttpError';
import { UserProfile } from '../models/User';
import { LoadingState } from '../common/widgets/StateViews';
import { FileService } from '../common/services/FileService';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct EditInfoPage {
  @StorageProp('breakpoint') bp: string = 'sm';
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

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.editinfo_title'), subtitle: $r('app.string.editinfo_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // 头像置顶：居中 hero 页头（大头像 + 姓名 + 更换按钮）
              Column({ space: 10 }) {
                // 头像实时预览：base64 data URL / 网络地址直接渲染，无头像时显示首字徽章
                if (this.avatarUrl.length > 0) {
                  Image(this.avatarUrl)
                    .width(88).height(88).borderRadius(44)
                    .objectFit(ImageFit.Cover)
                    .border({ width: 2, color: ElysiaTheme.ROSE_100 })
                } else {
                  Stack() {
                    Text(this.name.length > 0 ? this.name.charAt(0) : '?')
                      .fontSize(32).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }
                  .width(88).height(88).borderRadius(44)
                  .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_500, 1]] })
                  .alignContent(Alignment.Center)
                }
                Text(this.name.length > 0 ? this.name : '—')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                Text($r('app.string.editinfo_pick_hint'))
                  .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).maxLines(2).textAlign(TextAlign.Center)
                Text(this.pickingAvatar ? $r('app.string.editinfo_picking') : $r('app.string.editinfo_pick_avatar'))
                  .fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
                  .padding({ left: 18, right: 18, top: 9, bottom: 9 })
                  .backgroundColor(this.pickingAvatar ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                  .borderRadius(999)
                  .margin({ top: 2 })
                  .onClick(() => this.pickAvatar())
              }.width('100%').padding({ top: 22, bottom: 22, left: 16, right: 16 })
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              .alignItems(HorizontalAlign.Center)

              Column() {
                Text($r('app.string.editinfo_readonly_section')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
                this.ReadonlyRow('学号', this.studentId)
                this.ReadonlyRow('姓名', this.name)
                this.ReadonlyRow('学院', this.college)
                this.ReadonlyRow('专业', this.major)
                this.ReadonlyRow('班级', this.className)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              RoseDivider({ label: $r('app.string.editinfo_editable') })

              Column({ space: 12 }) {
                ElysiaInput({ placeholder: $r('app.string.editinfo_phone'), value: $phone, leadingIcon: 'phone' })
                ElysiaInput({ placeholder: $r('app.string.editinfo_email'), value: $email, leadingIcon: 'mail' })
                ElysiaInput({ placeholder: $r('app.string.editinfo_address'), value: $address, leadingIcon: 'location' })
                ElysiaInput({ placeholder: $r('app.string.editinfo_emergency'), value: $emergencyContact, leadingIcon: 'phone' })
                TextArea({ placeholder: $r('app.string.editinfo_bio'), text: this.bio })
                  .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
                  .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .onChange((v: string) => { this.bio = v; })

                if (this.errorMsg.length > 0) {
                  Text(this.errorMsg).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
                }
                if (this.successMsg.length > 0) {
                  Text(this.successMsg).fontSize(12).fontColor(ElysiaTheme.SUCCESS)
                }

                PrimaryButton({ text: this.submitting ? $r('app.string.common_saving') : $r('app.string.editinfo_save'), onTap: () => this.submit() })
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function EditInfoPageBuilder() {
  NavDestination() {
    EditInfoPage()
  }
  .hideTitleBar(true)
}
