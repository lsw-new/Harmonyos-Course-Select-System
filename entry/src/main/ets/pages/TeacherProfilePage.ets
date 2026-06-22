// 教师端·个人中心（roadmap #6 完善）：资料查看 + 改邮箱 + 修改密码 + 退出登录。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, PrimaryButton } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { AuthRepository } from '../repositories/AuthRepository';
import { ChangePasswordRequest } from '../models/User';
import { TeacherProfile } from '../models/Teacher';
import { SessionStorage } from '../common/storage/SessionStorage';
import { FileService } from '../common/services/FileService';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct TeacherProfilePage {
  @State email: string = '';
  @State savingEmail: boolean = false;
  @State avatarUrl: string = '';
  @State pickingAvatar: boolean = false;
  @State oldPwd: string = '';
  @State newPwd: string = '';
  @State confirmPwd: string = '';
  @State changingPwd: boolean = false;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherProfile)) {
      return;
    }
    const t = SessionStorage.get().getTeacher();
    if (t) {
      this.email = t.email;
      this.avatarUrl = t.avatarUrl;
    }
  }

  private profile(): TeacherProfile {
    const t = SessionStorage.get().getTeacher();
    if (t) {
      return t;
    }
    return { teacherId: '', name: '老师', college: '', title: '', email: '', avatarUrl: '' };
  }

  // 选图 → 上传对象存储 → 写后端 → 刷新会话（与学生端同构）。
  private pickAvatar(): void {
    if (this.pickingAvatar) {
      return;
    }
    this.pickingAvatar = true;
    FileService.pickAndUploadAvatarImage().then((uri: string) => {
      return TeacherRepository.get().updateAvatar(uri).then(() => uri);
    }).then((uri: string) => {
      this.avatarUrl = uri;
      const session = SessionStorage.get();
      const t = session.getTeacher();
      const token = session.getToken();
      if (t && token) {
        const next: TeacherProfile = {
          teacherId: t.teacherId, name: t.name, college: t.college,
          title: t.title, email: t.email, avatarUrl: uri
        };
        session.setTeacherSession(token, next).catch(() => undefined);
      }
      this.pickingAvatar = false;
      Toast.show(this.getUIContext(), '头像已更新');
    }).catch((e: object) => {
      this.pickingAvatar = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '选择头像失败');
    });
  }

  private saveEmail(): void {
    if (this.savingEmail) {
      return;
    }
    this.savingEmail = true;
    TeacherRepository.get().updateEmail(this.email.trim()).then(() => {
      this.savingEmail = false;
      Toast.show(this.getUIContext(), '邮箱已更新');
    }).catch((e: object) => {
      this.savingEmail = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '更新失败');
    });
  }

  private changePwd(): void {
    if (this.changingPwd) {
      return;
    }
    if (this.oldPwd.length === 0 || this.newPwd.length === 0) {
      Toast.show(this.getUIContext(), '请填写原密码与新密码');
      return;
    }
    if (this.newPwd.length < 8) {
      Toast.show(this.getUIContext(), '新密码至少 8 位');
      return;
    }
    if (this.newPwd !== this.confirmPwd) {
      Toast.show(this.getUIContext(), '两次新密码不一致');
      return;
    }
    this.changingPwd = true;
    const req: ChangePasswordRequest = { oldPassword: this.oldPwd, newPassword: this.newPwd, confirmPassword: this.confirmPwd };
    AuthRepository.get().changePassword(req).then(() => {
      this.changingPwd = false;
      this.oldPwd = '';
      this.newPwd = '';
      this.confirmPwd = '';
      Toast.show(this.getUIContext(), '密码已修改');
    }).catch((e: object) => {
      this.changingPwd = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '修改失败');
    });
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => {
      AppRoute.clearTo(Routes.Login);
    }).catch(() => {
      AppRoute.clearTo(Routes.Login);
    });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(ElysiaTheme.INK_SOFT).width(72)
      Text(value.length > 0 ? value : '—').fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  @Builder PwdField(ph: string, val: string, on: (v: string) => void) {
    TextInput({ placeholder: ph, text: val })
      .type(InputType.Password).fontSize(14).height(44)
      .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
      .onChange(on)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%').linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '个人中心', subtitle: this.profile().name, onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            // 资料卡（头像 hero 居中 + 资料明细）
            Column({ space: 2 }) {
              Column({ space: 8 }) {
                if (this.avatarUrl.length > 0) {
                  Image(this.avatarUrl)
                    .width(84).height(84).borderRadius(42)
                    .objectFit(ImageFit.Cover)
                    .border({ width: 2, color: ElysiaTheme.ROSE_100 })
                } else {
                  Stack() {
                    Text(this.profile().name.length > 0 ? this.profile().name.charAt(0) : '师')
                      .fontSize(30).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }
                  .width(84).height(84).borderRadius(42)
                  .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_500, 1]] })
                  .alignContent(Alignment.Center)
                }
                Text(this.pickingAvatar ? '上传中…' : '更换头像')
                  .fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
                  .padding({ left: 16, right: 16, top: 7, bottom: 7 })
                  .backgroundColor(this.pickingAvatar ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                  .borderRadius(999)
                  .onClick(() => this.pickAvatar())
              }.width('100%').padding({ bottom: 10 })

              Text(this.profile().name).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              Text(`工号 ${this.profile().teacherId}`).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
              Divider().color(ElysiaTheme.hairlineSoft())
              this.InfoRow('学院', this.profile().college)
              this.InfoRow('职称', this.profile().title)
            }.width('100%').padding(18).backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Center)

            // 改邮箱
            Column({ space: 10 }) {
              Text('联系邮箱').fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
              TextInput({ placeholder: '填写常用邮箱', text: this.email })
                .fontSize(14).height(44).backgroundColor(ElysiaTheme.glass())
                .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
                .onChange((v: string) => { this.email = v; })
              PrimaryButton({ text: this.savingEmail ? '保存中…' : '保存邮箱', onTap: () => this.saveEmail() })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)

            // 改密码
            Column({ space: 10 }) {
              Text('修改密码').fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
              this.PwdField('原密码', this.oldPwd, (v: string) => { this.oldPwd = v; })
              this.PwdField('新密码（至少 8 位）', this.newPwd, (v: string) => { this.newPwd = v; })
              this.PwdField('确认新密码', this.confirmPwd, (v: string) => { this.confirmPwd = v; })
              PrimaryButton({ text: this.changingPwd ? '提交中…' : '修改密码', onTap: () => this.changePwd() })
            }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)

            // 退出登录
            Text('退出登录')
              .fontSize(14).fontColor(ElysiaTheme.ROSE_500).fontWeight(FontWeight.Medium)
              .width('100%').textAlign(TextAlign.Center).padding(14)
              .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
              .onClick(() => this.logout())

            SafeBottom()
          }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TeacherProfilePageBuilder() {
  NavDestination() {
    TeacherProfilePage()
  }
  .hideTitleBar(true)
}
