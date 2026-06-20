// 实践成果受理 · Admin Practice Submissions
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AdminRepository } from '../repositories/AdminRepository';
import { PracticeSubmissionAdminItem, PracticeSubmissionStatus, PracticeScorePayload } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

interface SubmissionFilterChip {
  value: string;
  label: string;
}

@Component
struct AdminPracticeSubmissionsPage {
  @State loading: boolean = true;
  @State items: PracticeSubmissionAdminItem[] = [];
  @State errorMsg: string = '';
  @State statusFilter: string = '';
  @State activeId: string = '';
  @State scoreText: string = '';
  @State feedback: string = '';
  @State nextStatus: string = '';
  @State submitting: boolean = false;
  @State formError: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private statusChips: SubmissionFilterChip[] = [
    { value: '', label: '全部' },
    { value: 'submitted', label: '待评分' },
    { value: 'scored', label: '已评分' },
    { value: 'passed', label: '已通过' },
    { value: 'rejected', label: '已驳回' }
  ];

  private statusOptions: SubmissionFilterChip[] = [
    { value: 'scored', label: '已评分' },
    { value: 'passed', label: '已通过' },
    { value: 'rejected', label: '已驳回' }
  ];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminPracticeSubmissions)) return;
    this.loadList();
  }

  private loadList(): void {
    this.loading = true;
    this.errorMsg = '';
    AppRoute.showLoading();
    AdminRepository.get().getPracticeSubmissions(this.statusFilter, '').then((list: PracticeSubmissionAdminItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.loading = false;
    });
  }

  private openHandler(item: PracticeSubmissionAdminItem): void {
    this.activeId = item.submissionId;
    this.scoreText = item.score === null ? '' : String(item.score);
    this.feedback = item.feedback.length > 0 ? item.feedback : '';
    this.nextStatus = item.status === 'submitted' ? 'scored' : item.status;
    this.formError = '';
  }

  private closeHandler(): void {
    this.activeId = '';
    this.scoreText = '';
    this.feedback = '';
    this.nextStatus = '';
    this.formError = '';
  }

  private doSave(): void {
    if (this.nextStatus.length === 0) {
      this.formError = '请选择处理状态';
      return;
    }
    let score: number | null = null;
    const scoreTrim: string = this.scoreText.trim();
    if (scoreTrim.length > 0) {
      const parsed: number = Number(scoreTrim);
      if (!Number.isFinite(parsed) || parsed < 0 || parsed > 100) {
        this.formError = '分数需为 0-100 的数字';
        return;
      }
      score = parsed;
    }
    const payload: PracticeScorePayload = {
      score: score,
      feedback: this.feedback.trim(),
      status: this.nextStatus as PracticeSubmissionStatus
    };
    this.submitting = true;
    AdminRepository.get().scorePracticeSubmission(this.activeId, payload).then((updated: PracticeSubmissionAdminItem) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '已提交评分');
      const merged: PracticeSubmissionAdminItem[] = this.items.map((it: PracticeSubmissionAdminItem) => it.submissionId === updated.submissionId ? updated : it);
      this.items = merged;
      this.closeHandler();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
    });
  }

  private statusLabel(s: PracticeSubmissionStatus): string {
    if (s === 'submitted') return '待评分';
    if (s === 'scored') return '已评分';
    if (s === 'passed') return '已通过';
    return '已驳回';
  }

  private statusColor(s: PracticeSubmissionStatus): string {
    if (s === 'submitted') return ElysiaTheme.ROSE_500;
    if (s === 'scored') return '#D9B675';
    if (s === 'passed') return ElysiaTheme.SUCCESS;
    return ElysiaTheme.INK_MUTE;
  }

  @Builder ChipRow(groupLabel: string, chips: SubmissionFilterChip[], active: string, onPick: (v: string) => void, keyPrefix: string) {
    Row({ space: 10 }) {
      Text(groupLabel).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width(28)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(chips, (c: SubmissionFilterChip) => {
            Text(c.label).fontSize(12)
              .fontWeight(active === c.value ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(active === c.value ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(active === c.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.pillBg())
              .border({ width: 1, color: active === c.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
              .borderRadius(999)
              .onClick(() => onPick(c.value))
          }, (c: SubmissionFilterChip) => `${keyPrefix}-${c.value}-${active === c.value}`)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
    }.width('100%')
  }

  @Builder SubmissionCard(item: PracticeSubmissionAdminItem) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Pill({ text: this.statusLabel(item.status), color: this.statusColor(item.status), bg: '#FFF0F4' })
        if (item.score !== null) {
          Pill({ text: `${item.score} 分`, color: ElysiaTheme.GOLD_700, bg: '#FBE6C2' })
        }
        Blank()
        Text(item.submittedAt).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%')

      Text(item.projectTitle.length > 0 ? item.projectTitle : '实践项目')
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`${item.studentName.length > 0 ? item.studentName : '学生'} · ${item.studentId.length > 0 ? item.studentId : '—'}`)
        .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width('100%')

      Text(item.content).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

      if (item.feedback.length > 0) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            AppIcon({ name: 'chat', iconSize: 12 })
            Text(`${item.scoredBy.length > 0 ? item.scoredBy : '管理员'}评语 · ${item.scoredAt}`)
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
          }
          Text(item.feedback).fontSize(12).fontColor(ElysiaTheme.INK).lineHeight(18)
        }.width('100%').padding(10).backgroundColor('#FFF7FA').borderRadius(10).alignItems(HorizontalAlign.Start)
      }

      Row({ space: 10 }) {
        Blank()
        Text(item.status === 'submitted' ? '评分 / 受理' : '查看 / 重新评分')
          .fontSize(12).fontColor(ElysiaTheme.ROSE_500)
          .onClick(() => this.openHandler(item))
      }.width('100%')
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder HandlerPanel(item: PracticeSubmissionAdminItem) {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Pill({ text: this.statusLabel(item.status), color: this.statusColor(item.status), bg: '#FFF0F4' })
        Text(item.projectTitle.length > 0 ? item.projectTitle : '实践项目')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(`${item.studentName.length > 0 ? item.studentName : '学生'} · ${item.studentId.length > 0 ? item.studentId : '—'} · ${item.submittedAt}`)
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(18)
      .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      Column({ space: 6 }) {
        Text('成果内容').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        Text(item.content).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
        if (item.attachments.length > 0) {
          Text(`附件：${item.attachments.join('、')}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      if (item.feedback.length > 0) {
        Column({ space: 6 }) {
          Text(`上次评语 · ${item.scoredBy.length > 0 ? item.scoredBy : '管理员'} · ${item.scoredAt}`)
            .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          Text(item.feedback).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor('#FFF7FA').borderRadius(14)
        .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
      }

      Column({ space: 8 }) {
        Text('评分（0-100，可空）').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        TextInput({ placeholder: '请输入分数', text: this.scoreText })
          .type(InputType.Number).height(44).fontSize(13).fontColor(ElysiaTheme.INK)
          .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
          .onChange((v: string) => { this.scoreText = v; })

        Text('评语（可选）').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
        TextArea({ placeholder: '请输入评语，会同步给学生', text: this.feedback })
          .height(100).fontSize(13).fontColor(ElysiaTheme.INK)
          .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
          .onChange((v: string) => { this.feedback = v; })

        Text('处理状态').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
        Row({ space: 8 }) {
          ForEach(this.statusOptions, (opt: SubmissionFilterChip) => {
            Text(opt.label).fontSize(12)
              .fontWeight(this.nextStatus === opt.value ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.nextStatus === opt.value ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.nextStatus === opt.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.pillBg())
              .border({ width: 1, color: this.nextStatus === opt.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
              .borderRadius(999)
              .onClick(() => { this.nextStatus = opt.value; })
          }, (opt: SubmissionFilterChip) => `pst-${opt.value}-${this.nextStatus === opt.value}`)
        }

        if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
        }

        Row({ space: 12 }) {
          GhostButton({ text: '取消', onTap: () => this.closeHandler() })
          PrimaryButton({ text: this.submitting ? '提交中...' : '提交评分', onTap: () => this.doSave() })
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
          title: '实践成果',
          subtitle: '评阅学生实践成果',
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
            this.ChipRow('状态', this.statusChips, this.statusFilter, (v: string) => {
              this.statusFilter = v;
              this.loadList();
            }, 'psst')
          }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor(ElysiaTheme.SURFACE).borderRadius(16)
          .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
          .shadow({ radius: 10, color: '#14D8546B', offsetX: 0, offsetY: 3 })
          .margin({ left: 16, right: 16, top: 8 })

          if (this.loading) {
            Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.errorMsg.length > 0) {
            Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadList() }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.items.length === 0) {
            Column() { EmptyState({ title: '暂无成果提交' }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            List({ space: 10 }) {
              ForEach(this.items, (item: PracticeSubmissionAdminItem) => {
                ListItem() {
                  this.SubmissionCard(item)
                }
              }, (item: PracticeSubmissionAdminItem) => item.submissionId)
            }.layoutWeight(1).padding({ left: 16, right: 16, top: 6, bottom: 16 })
          }
        } else {
          Scroll() {
            this.HandlerPanel(this.items.find((it: PracticeSubmissionAdminItem) => it.submissionId === this.activeId) ?? this.items[0])
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }.width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminPracticeSubmissionsPageBuilder() {
  NavDestination() {
    AdminPracticeSubmissionsPage()
  }
  .hideTitleBar(true)
}
