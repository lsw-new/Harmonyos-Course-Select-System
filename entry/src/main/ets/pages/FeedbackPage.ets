// 意见反馈 · Feedback
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { FeedbackItem } from '../models/Misc';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, EmptyState } from '../common/widgets/StateViews';

@Entry
@Component
struct FeedbackPage {
  @State activeTab: number = 0;
  @State category: string = 'bug';
  @State title: string = '';
  @State content: string = '';
  @State contact: string = '';
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State loading: boolean = true;
  @State history: FeedbackItem[] = [];

  private catLabels: string[] = ['Bug', '建议', '服务', '其他'];
  private catKeys: string[] = ['bug', 'suggestion', 'service', 'other'];

  aboutToAppear(): void {
    ProfileRepository.get().getFeedback().then((list: FeedbackItem[]) => {
      this.history = list;
      this.loading = false;
    }).catch(() => { this.loading = false; });
  }

  private submit(): void {
    if (this.submitting) return;
    if (this.title.trim().length === 0) { this.errorMsg = '请填写标题'; return; }
    if (this.content.trim().length === 0) { this.errorMsg = '请填写内容'; return; }
    this.errorMsg = '';
    this.submitting = true;
    ProfileRepository.get().submitFeedback({
      category: this.category as 'bug' | 'suggestion' | 'service' | 'other',
      title: this.title, content: this.content,
      contact: this.contact, screenshots: []
    }).then(() => {
      this.submitting = false;
      this.successMsg = '反馈已提交';
      this.title = '';
      this.content = '';
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '提交失败';
    });
  }

  private stateLabel(state: string): string {
    if (state === 'submitted') return '已提交';
    if (state === 'processing') return '处理中';
    return '已关闭';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Feedback', subtitle: '意 见 反 馈', onBack: () => router.back() })

        Row({ space: 0 }) {
          Text('提交反馈').fontSize(13)
            .fontColor(this.activeTab === 0 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 0 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => { this.activeTab = 0; })
          Text('历史反馈').fontSize(13)
            .fontColor(this.activeTab === 1 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 1 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => { this.activeTab = 1; })
        }.width('100%').padding({ left: 16 })

        Scroll() {
          Column({ space: 14 }) {
            if (this.activeTab === 0) {
              Row({ space: 8 }) {
                ForEach(this.catLabels, (label: string, idx: number) => {
                  Text(label).fontSize(12)
                    .fontColor(this.category === this.catKeys[idx] ? Color.White : ElysiaTheme.ROSE_700)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.category === this.catKeys[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                    .borderRadius(999)
                    .onClick(() => { this.category = this.catKeys[idx]; })
                }, (label: string, idx: number) => `cat-${idx}`)
              }.width('100%').margin({ top: 4 })

              ElysiaInput({ placeholder: '标题', value: $title, leadingIcon: '✎' })
              TextArea({ placeholder: '详细描述', text: this.content })
                .height(120).fontSize(13).fontColor(ElysiaTheme.INK)
                .backgroundColor('#CCFFFFFF').border({ width: 1, color: '#80FFB3CE' }).borderRadius(14)
                .onChange((v: string) => { this.content = v; })
              ElysiaInput({ placeholder: '联系方式（选填）', value: $contact, leadingIcon: '☎' })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg).fontSize(12).fontColor('#7BB07B')
              }

              PrimaryButton({ text: this.submitting ? '提交中...' : '提交反馈', onTap: () => this.submit() })
            } else {
              if (this.loading) {
                LoadingState({})
              } else if (this.history.length === 0) {
                EmptyState({ title: '暂无反馈记录' })
              } else {
                ForEach(this.history, (item: FeedbackItem) => {
                  Row() {
                    Column() {
                      Text(item.title).fontSize(13).fontColor(ElysiaTheme.INK)
                      Text(item.submittedAt).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Pill({ text: this.stateLabel(item.state), color: ElysiaTheme.ROSE_700, bg: '#FFF6FA' })
                  }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                  .border({ width: 1, color: '#66FFB3CE' })
                }, (item: FeedbackItem) => item.id)
              }
            }
            Blank().height(40)
          }.padding({ left: 16, right: 16, top: 12 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
