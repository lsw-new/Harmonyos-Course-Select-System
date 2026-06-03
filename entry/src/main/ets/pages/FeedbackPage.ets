// 意见反馈 · Feedback
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { FeedbackItem } from '../models/Misc';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Entry
@Component
struct FeedbackPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State activeTab: number = 0;
  @State category: string = 'bug';
  @State title: string = '';
  @State content: string = '';
  @State contact: string = '';
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State loading: boolean = true;
  @State historyErrorMsg: string = '';
  @State history: FeedbackItem[] = [];

  private catLabels: string[] = ['Bug', '建议', '服务', '其他'];
  private catKeys: string[] = ['bug', 'suggestion', 'service', 'other'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Feedback)) {
      return;
    }
    this.loadHistory();
  }

  private loadHistory(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.historyErrorMsg = '';
    ProfileRepository.get().getFeedback().then((list: FeedbackItem[]) => {
      this.history = list;
      this.loading = false;
    }).catch((e: object) => {
      this.historyErrorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private submit(): void {
    if (this.submitting) return;
    if (this.title.trim().length === 0) { this.errorMsg = '请填写标题'; return; }
    if (this.content.trim().length === 0) { this.errorMsg = '请填写内容'; return; }
    this.errorMsg = '';
    this.successMsg = '';
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
        TopBar({ title: '意见反馈', subtitle: '意 见 反 馈', onBack: () => AppRoute.back() })

        Row({ space: 0 }) {
          Text('提交反馈').fontSize(13)
            .fontColor(this.activeTab === 0 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 0 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => {
              this.activeTab = 0;
              this.successMsg = '';
            })
          Text('历史反馈').fontSize(13)
            .fontColor(this.activeTab === 1 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 1 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => {
              this.activeTab = 1;
              this.successMsg = '';
            })
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

              ElysiaInput({ placeholder: '标题', value: $title, leadingIcon: 'edit' })
              TextArea({ placeholder: '详细描述', text: this.content })
                .height(120).fontSize(13).fontColor(ElysiaTheme.INK)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                .onChange((v: string) => { this.content = v; })
              ElysiaInput({ placeholder: '联系方式（选填）', value: $contact, leadingIcon: 'phone' })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg).fontSize(12).fontColor(ElysiaTheme.SUCCESS)
              }

              PrimaryButton({ text: this.submitting ? '提交中...' : '提交反馈', onTap: () => this.submit() })
            } else {
              if (this.loading) {
                LoadingState({ tip: '正在加载...' })
              } else if (this.historyErrorMsg.length > 0) {
                ErrorState({ message: this.historyErrorMsg, onRetry: () => this.loadHistory() })
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
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                }, (item: FeedbackItem) => item.id)
              }
            }
            SafeBottom()
          }.padding({ left: 16, right: 16, top: 12 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}
