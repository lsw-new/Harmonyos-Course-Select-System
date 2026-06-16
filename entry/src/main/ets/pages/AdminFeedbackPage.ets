// 意见反馈管理 · Admin Feedback
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AdminRepository } from '../repositories/AdminRepository';
import { FeedbackItem, FeedbackCategory, FeedbackState } from '../models/Misc';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

interface FilterChip {
  value: string;
  label: string;
}

@Component
struct AdminFeedbackPage {
  @State loading: boolean = true;
  @State items: FeedbackItem[] = [];
  @State errorMsg: string = '';
  @State stateFilter: string = '';
  @State categoryFilter: string = '';
  @State activeId: string = '';
  @State reply: string = '';
  @State nextState: string = '';
  @State submitting: boolean = false;
  @State formError: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private stateChips: FilterChip[] = [
    { value: '', label: '全部' },
    { value: 'submitted', label: '已提交' },
    { value: 'processing', label: '处理中' },
    { value: 'closed', label: '已关闭' }
  ];

  private categoryChips: FilterChip[] = [
    { value: '', label: '全部' },
    { value: 'bug', label: 'Bug' },
    { value: 'suggestion', label: '建议' },
    { value: 'service', label: '服务' },
    { value: 'other', label: '其他' }
  ];

  private stateOptions: FilterChip[] = [
    { value: 'processing', label: '处理中' },
    { value: 'closed', label: '已关闭' }
  ];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminFeedback)) return;
    this.loadList();
  }

  private loadList(): void {
    this.loading = true;
    this.errorMsg = '';
    AppRoute.showLoading();
    AdminRepository.get().getFeedbackList(this.stateFilter, this.categoryFilter).then((list: FeedbackItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.loading = false;
    });
  }

  private openHandler(item: FeedbackItem): void {
    this.activeId = item.id;
    this.reply = item.reply ?? '';
    this.nextState = item.state === 'submitted' ? 'processing' : item.state;
    this.formError = '';
  }

  private closeHandler(): void {
    this.activeId = '';
    this.reply = '';
    this.nextState = '';
    this.formError = '';
  }

  private doSave(): void {
    const replyTrim: string = this.reply.trim();
    if (replyTrim.length === 0) {
      this.formError = '请填写回复内容';
      return;
    }
    if (this.nextState.length === 0) {
      this.formError = '请选择处理状态';
      return;
    }
    this.submitting = true;
    AdminRepository.get().handleFeedback(this.activeId, replyTrim, this.nextState).then((updated: FeedbackItem) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '已提交回复');
      const merged: FeedbackItem[] = this.items.map((it: FeedbackItem) => it.id === updated.id ? updated : it);
      this.items = merged;
      this.closeHandler();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
    });
  }

  private catLabel(cat: FeedbackCategory): string {
    if (cat === 'bug') return 'Bug';
    if (cat === 'suggestion') return '建议';
    if (cat === 'service') return '服务';
    return '其他';
  }

  private stateLabel(s: FeedbackState): string {
    if (s === 'submitted') return '已提交';
    if (s === 'processing') return '处理中';
    return '已关闭';
  }

  private stateColor(s: FeedbackState): string {
    if (s === 'submitted') return ElysiaTheme.ROSE_500;
    if (s === 'processing') return '#D9B675';
    return ElysiaTheme.INK_MUTE;
  }

  @Builder ChipRow(chips: FilterChip[], active: string, onPick: (v: string) => void, keyPrefix: string) {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(chips, (c: FilterChip) => {
          Text(c.label).fontSize(11)
            .fontColor(active === c.value ? Color.White : ElysiaTheme.ROSE_700)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(active === c.value ? ElysiaTheme.ROSE_500 : '#FFE9F1')
            .borderRadius(999)
            .onClick(() => onPick(c.value))
        }, (c: FilterChip) => `${keyPrefix}-${c.value}`)
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  @Builder FeedbackCard(item: FeedbackItem) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Pill({ text: this.catLabel(item.category), color: ElysiaTheme.ROSE_700, bg: '#FFE9F1' })
        Pill({ text: this.stateLabel(item.state), color: this.stateColor(item.state), bg: '#FFF0F4' })
        Blank()
        Text(item.submittedAt).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%')

      Text(item.title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')

      Text(`${(item.studentName ?? '').length > 0 ? item.studentName : '匿名'} · ${(item.studentId ?? '') || '—'}`)
        .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width('100%')

      Text(item.content).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

      if ((item.reply ?? '').length > 0) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            AppIcon({ name: 'chat', iconSize: 12 })
            Text(`${item.repliedByName ?? '管理员'}回复 · ${item.repliedAt ?? ''}`)
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
          }
          Text(item.reply!).fontSize(12).fontColor(ElysiaTheme.INK).lineHeight(18)
        }.width('100%').padding(10).backgroundColor('#FFF7FA').borderRadius(10).alignItems(HorizontalAlign.Start)
      }

      Row({ space: 10 }) {
        Blank()
        Text(item.state === 'closed' ? '查看' : '处理 / 回复')
          .fontSize(12).fontColor(ElysiaTheme.ROSE_500)
          .onClick(() => this.openHandler(item))
      }.width('100%')
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder HandlerPanel(item: FeedbackItem) {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Pill({ text: this.catLabel(item.category) })
        Text(item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(`${(item.studentName ?? '').length > 0 ? item.studentName : '匿名'} · ${(item.studentId ?? '') || '—'} · ${item.submittedAt}`)
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(18)
      .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      Column({ space: 6 }) {
        Text('反馈正文').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        Text(item.content).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
        if (item.contact.length > 0) {
          Text(`联系方式：${item.contact}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      if ((item.reply ?? '').length > 0) {
        Column({ space: 6 }) {
          Text(`上次回复 · ${item.repliedByName ?? '管理员'} · ${item.repliedAt ?? ''}`)
            .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          Text(item.reply!).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor('#FFF7FA').borderRadius(14)
        .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
      }

      Column({ space: 8 }) {
        Text('处理回复').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        TextArea({ placeholder: '请输入回复内容，会同步推送给提交者', text: this.reply })
          .height(110).fontSize(13).fontColor(ElysiaTheme.INK)
          .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
          .onChange((v: string) => { this.reply = v; })

        Text('处理状态').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
        Row({ space: 8 }) {
          ForEach(this.stateOptions, (opt: FilterChip) => {
            Text(opt.label).fontSize(12)
              .fontColor(this.nextState === opt.value ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.nextState === opt.value ? ElysiaTheme.ROSE_500 : '#FFE9F1')
              .borderRadius(999)
              .onClick(() => { this.nextState = opt.value; })
          }, (opt: FilterChip) => `nst-${opt.value}`)
        }

        if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
        }

        Row({ space: 12 }) {
          GhostButton({ text: '取消', onTap: () => this.closeHandler() })
          PrimaryButton({ text: this.submitting ? '提交中...' : '提交回复', onTap: () => this.doSave() })
        }.width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      SafeBottom()
    }.padding({ left: 16, right: 16 })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({
          title: '意见反馈',
          subtitle: '处理学生反馈并回复',
          showBack: true,
          onBack: () => {
            if (this.activeId.length > 0) {
              this.closeHandler();
            } else {
              AppRoute.back();
            }
          }
        })

        if (this.activeId.length === 0) {
          Column({ space: 10 }) {
            this.ChipRow(this.stateChips, this.stateFilter, (v: string) => {
              this.stateFilter = v;
              this.loadList();
            }, 'st')
            this.ChipRow(this.categoryChips, this.categoryFilter, (v: string) => {
              this.categoryFilter = v;
              this.loadList();
            }, 'cat')
          }.width('100%').padding({ left: 16, right: 16, top: 8 })

          if (this.loading) {
            Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.errorMsg.length > 0) {
            Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadList() }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.items.length === 0) {
            Column() { EmptyState({ title: '暂无反馈' }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            List({ space: 10 }) {
              ForEach(this.items, (item: FeedbackItem) => {
                ListItem() {
                  this.FeedbackCard(item)
                }
              }, (item: FeedbackItem) => item.id)
            }.layoutWeight(1).padding({ left: 16, right: 16, top: 6, bottom: 16 })
          }
        } else {
          Scroll() {
            this.HandlerPanel(this.items.find((it: FeedbackItem) => it.id === this.activeId) ?? this.items[0])
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }.width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminFeedbackPageBuilder() {
  NavDestination() {
    AdminFeedbackPage()
  }
  .hideTitleBar(true)
}
