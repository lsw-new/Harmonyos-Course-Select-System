// 发布通知 · Annonce
import { ElysiaTheme } from '../common/Theme';
import { TopBar, PrimaryButton, ElysiaInput } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { HttpError } from '../common/http/HttpError';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import promptAction from '@ohos.promptAction';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct AdminNoticePage {
  @State title: string = '';
  @State content: string = '';
  @State publisher: string = '教务处';
  @State category: string = '教务';
  @State urgency: string = 'normal';
  @State receiverType: string = 'all';
  @State scopeText: string = '';
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State showConfirm: boolean = false;

  private urgencyLabels: string[] = ['普通', '重要', '紧急'];
  private urgencyKeys: string[] = ['normal', 'important', 'urgent'];
  private receiverLabels: string[] = ['全体', '学生', '教师', '自定义'];
  private receiverKeys: string[] = ['all', 'students', 'teachers', 'custom'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminNotice)) return;
  }

  private publish(): void {
    if (this.submitting) return;
    if (this.title.trim().length === 0) { this.errorMsg = '请填写标题'; return; }
    if (this.content.trim().length === 0) { this.errorMsg = '请填写正文'; return; }
    this.errorMsg = '';
    this.showConfirm = true;
  }

  private confirmPublish(): void {
    this.showConfirm = false;
    this.submitting = true;

    let receiverScope: string[] = [];
    if (this.receiverType === 'custom') {
      receiverScope = this.scopeText.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    }

    AdminRepository.get().publishNotice({
      title: this.title, content: this.content, publisher: this.publisher,
      category: this.category,
      urgency: this.urgency as 'normal' | 'important' | 'urgent',
      receiverType: this.receiverType as 'all' | 'students' | 'teachers' | 'custom',
      receiverScope: receiverScope
    }).then(() => {
      this.submitting = false;
      this.successMsg = '通知已发布';
      this.title = '';
      this.content = '';
      this.scopeText = '';
      promptAction.showToast({ message: '通知已发布' });
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '发布失败';
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
        TopBar({ title: '发布通知', subtitle: '发 布 通 知', onBack: () => AppRoute.back() })

        Scroll() {
          Column({ space: 14 }) {
            ElysiaInput({
              placeholder: '通知标题',
              value: $title,
              leadingIcon: 'edit'
            })

            TextArea({ placeholder: '通知正文', text: this.content })
              .height(160).fontSize(13).fontColor(ElysiaTheme.INK)
              .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
              .onChange((v: string) => {
                this.content = v;
                if (this.successMsg.length > 0) { this.successMsg = ''; }
              })

            ElysiaInput({ placeholder: '发布单位', value: $publisher, leadingIcon: 'public' })

            // 紧急程度
            Column({ space: 6 }) {
              Text('紧急程度').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
              Row({ space: 8 }) {
                ForEach(this.urgencyLabels, (label: string, idx: number) => {
                  Text(label).fontSize(12)
                    .fontColor(this.urgency === this.urgencyKeys[idx] ? Color.White : ElysiaTheme.ROSE_700)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.urgency === this.urgencyKeys[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                    .borderRadius(999)
                    .onClick(() => { this.urgency = this.urgencyKeys[idx]; })
                }, (label: string, idx: number) => `u-${idx}`)
              }
            }.width('100%').alignItems(HorizontalAlign.Start)

            // 接收对象
            Column({ space: 6 }) {
              Text('接收对象').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
              Row({ space: 8 }) {
                ForEach(this.receiverLabels, (label: string, idx: number) => {
                  Text(label).fontSize(12)
                    .fontColor(this.receiverType === this.receiverKeys[idx] ? Color.White : ElysiaTheme.ROSE_700)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.receiverType === this.receiverKeys[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                    .borderRadius(999)
                    .onClick(() => { this.receiverType = this.receiverKeys[idx]; })
                }, (label: string, idx: number) => `r-${idx}`)
              }
              if (this.receiverType === 'custom') {
                ElysiaInput({
                  placeholder: '输入接收范围，逗号分隔（如：计科2101、计科2102）',
                  value: $scopeText,
                  leadingIcon: 'public'
                })
              }
            }.width('100%').alignItems(HorizontalAlign.Start)

            if (this.errorMsg.length > 0) {
              Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
            }
            if (this.successMsg.length > 0) {
              Text(this.successMsg).fontSize(12).fontColor('#7BB07B')
            }

            PrimaryButton({ text: this.submitting ? '发布中...' : '发布通知', onTap: () => this.publish() })

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }

      if (this.showConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text('确认发布？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text('通知将发送给所选接收对象').fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text('取消').fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor('#E0FFFFFF').borderRadius(999)
                .onClick(() => { this.showConfirm = false; })
              Text('确认发布').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                .onClick(() => { this.confirmPublish(); })
            }.margin({ top: 8 })
          }.padding(24).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor(ElysiaTheme.scrim())
        .onClick(() => { this.showConfirm = false; })
      }
    }.width('100%').height('100%')
  }
}
