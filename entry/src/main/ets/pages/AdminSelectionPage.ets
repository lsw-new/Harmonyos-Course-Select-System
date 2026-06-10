// 选课轮次管理 · Sélection
// 真正可用的轮次管理：启动 / 暂停 / 结束 / 编辑起止时间（持久化），
// 非法流转给出提示；结束需二次确认；可展开查看冲突明细。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput, RoseDivider } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { SelectionAdminRepository } from '../repositories/SelectionAdminRepository';
import { AdminRound, RoundConflict, RoundTimePayload } from '../models/SelectionAdminModels';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminSelectionPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State loading: boolean = true;
  @State error: string = '';
  @State submitting: boolean = false;
  @State rounds: AdminRound[] = [];
  // 二次确认结束的目标轮次 id
  @State pendingEndId: string = '';
  // 展开冲突明细的轮次 id + 数据
  @State expandedConflictId: string = '';
  @State conflictLoading: boolean = false;
  @State conflictError: string = '';
  @State conflicts: RoundConflict[] = [];
  // 编辑起止时间的底部表单
  @State isEditing: boolean = false;
  @State editingId: string = '';
  @State editingName: string = '';
  @State startText: string = '';
  @State endText: string = '';
  @State formError: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminSelection)) {
      return;
    }
    this.load();
  }

  private load(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.error = '';
    SelectionAdminRepository.get().getRounds().then((d: AdminRound[]) => {
      this.rounds = d;
      this.loading = false;
    }).catch((e: object) => {
      this.error = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.loading = false;
    });
  }

  private statusLabel(s: string): string {
    if (s === 'running') return '进行中';
    if (s === 'paused') return '已暂停';
    if (s === 'ended') return '已结束';
    return '未开始';
  }

  private statusColor(s: string): string {
    if (s === 'running') return ElysiaTheme.SUCCESS;
    if (s === 'paused') return '#D9B675';
    if (s === 'ended') return ElysiaTheme.INK_MUTE;
    return ElysiaTheme.ROSE_600;
  }

  private statusBg(s: string): string {
    if (s === 'running') return '#E8F8E8';
    if (s === 'paused') return '#FBF1DC';
    if (s === 'ended') return '#F2ECEF';
    return '#FFE9F1';
  }

  // ===== 状态机操作 =====
  private startRound(r: AdminRound): void {
    this.runMutation(SelectionAdminRepository.get().startRound(r.id), '已启动选课轮次');
  }

  private pauseRound(r: AdminRound): void {
    this.runMutation(SelectionAdminRepository.get().pauseRound(r.id), '已暂停选课轮次');
  }

  private requestEnd(r: AdminRound): void {
    if (this.submitting) return;
    this.pendingEndId = r.id;
  }

  private cancelEnd(): void {
    this.pendingEndId = '';
  }

  private confirmEnd(r: AdminRound): void {
    this.pendingEndId = '';
    this.runMutation(SelectionAdminRepository.get().endRound(r.id), '已结束选课轮次');
  }

  private runMutation(action: Promise<AdminRound>, okMessage: string): void {
    if (this.submitting) return;
    this.submitting = true;
    action.then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), okMessage);
      this.load();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  // ===== 编辑起止时间 =====
  private openEdit(r: AdminRound): void {
    this.pendingEndId = '';
    this.editingId = r.id;
    this.editingName = r.name;
    this.startText = r.startTime;
    this.endText = r.endTime;
    this.formError = '';
    this.isEditing = true;
  }

  private cancelEdit(): void {
    this.isEditing = false;
    this.editingId = '';
    this.formError = '';
  }

  private saveTime(): void {
    if (this.submitting) return;
    const id = this.editingId;
    const payload: RoundTimePayload = { id: id, startTime: this.startText, endTime: this.endText };
    this.submitting = true;
    this.formError = '';
    SelectionAdminRepository.get().updateRoundTime(payload).then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '起止时间已更新');
      this.cancelEdit();
      this.load();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  // ===== 冲突明细 =====
  private toggleConflicts(r: AdminRound): void {
    if (this.expandedConflictId === r.id) {
      this.expandedConflictId = '';
      this.conflicts = [];
      this.conflictError = '';
      return;
    }
    this.expandedConflictId = r.id;
    this.conflicts = [];
    this.conflictError = '';
    this.conflictLoading = true;
    SelectionAdminRepository.get().getConflicts(r.id).then((list: RoundConflict[]) => {
      this.conflicts = list;
      this.conflictLoading = false;
    }).catch((e: object) => {
      this.conflictError = (e instanceof HttpError) ? (e as HttpError).message : '冲突明细加载失败';
      this.conflictLoading = false;
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.adminselection_title'), subtitle: $r('app.string.adminselection_subtitle'), onBack: () => { AppRoute.back(); } })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.error.length > 0) {
          Column() { ErrorState({ message: this.error, onRetry: () => { this.load(); } }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.rounds.length === 0) {
          Column() { EmptyState({ title: $r('app.string.adminselection_empty') }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.rounds, (r: AdminRound) => {
                this.RoundCard(r)
              }, (r: AdminRound) => r.id)
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 10 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }.width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })

      if (this.isEditing) {
        this.EditSheet()
      }
    }.width('100%').height('100%')
  }

  @Builder RoundCard(r: AdminRound) {
    Column({ space: 8 }) {
      Row() {
        Text(r.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Pill({ text: this.statusLabel(r.status), color: this.statusColor(r.status), bg: this.statusBg(r.status) })
      }.width('100%')

      Row() {
        AppIcon({ name: 'time', iconSize: 13, mRight: 5 })
        Text(`${r.startTime} ~ ${r.endTime}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)

      // 进度条
      Row() {
        Column().height(8).width(`${r.progressPercent}%`).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(4)
      }.width('100%').height(8).backgroundColor('#FFE9F1').borderRadius(4)
      Text(`进度 ${r.progressPercent}%`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)

      // 统计
      Row() {
        this.MiniStat('参与', String(r.participantCount))
        this.MiniStat('选课', String(r.selectionCount))
        this.MiniStat('学分', r.averageCredit.toFixed(1))
        this.MiniStat('冲突', String(r.conflictCount))
      }.width('100%')

      RoseDivider({ label: $r('app.string.adminselection_ops') })

      // 操作区：根据状态切换二次确认 / 普通按钮
      if (this.pendingEndId === r.id) {
        this.EndConfirmRow(r)
      } else {
        this.ActionRow(r)
      }

      // 冲突明细入口
      if (r.conflictCount > 0) {
        this.ConflictEntry(r)
      }
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  @Builder ActionRow(r: AdminRound) {
    Row({ space: 8 }) {
      if (r.status === 'notStarted' || r.status === 'paused') {
        this.ActionChip(r.status === 'paused' ? '继续' : '启动', ElysiaTheme.ROSE_700, '#FFE9F1', () => { this.startRound(r); })
      }
      if (r.status === 'running') {
        this.ActionChip('暂停', ElysiaTheme.GOLD_700, '#FBF1DC', () => { this.pauseRound(r); })
      }
      if (r.status === 'running' || r.status === 'paused') {
        this.ActionChip('结束', ElysiaTheme.ROSE_ACCENT, '#FFF0F3', () => { this.requestEnd(r); })
      }
      if (r.status !== 'ended') {
        this.ActionChip('编辑时间', ElysiaTheme.INK_SOFT, '#F5F2F4', () => { this.openEdit(r); })
      }
      if (r.status === 'ended') {
        Text($r('app.string.adminselection_ended')).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
      }
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder ActionChip(label: string, color: string, bg: string, onTap: () => void) {
    Text(label).fontSize(12).fontColor(color)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(bg).borderRadius(999)
      .opacity(this.submitting ? 0.5 : 1)
      .onClick(() => { onTap(); })
  }

  @Builder EndConfirmRow(r: AdminRound) {
    Row() {
      Text($r('app.string.adminselection_end_confirm')).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
      Text($r('app.string.common_cancel')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#F5F2F4').borderRadius(999)
        .margin({ right: 10 })
        .onClick(() => { this.cancelEnd(); })
      Text($r('app.string.adminselection_confirm_end')).fontSize(12).fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
        .onClick(() => { this.confirmEnd(r); })
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder ConflictEntry(r: AdminRound) {
    Column({ space: 8 }) {
      Row() {
        AppIcon({ name: 'warning', iconSize: 14, mRight: 6 })
        Text(`${r.conflictCount} 条选课冲突`).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
        Text(this.expandedConflictId === r.id ? $r('app.string.adminselection_collapse') : $r('app.string.adminselection_view_detail')).fontSize(12).fontColor(ElysiaTheme.ROSE_700)
        AppIcon({ name: this.expandedConflictId === r.id ? 'back' : 'forward', iconSize: 12, mLeft: 4 })
      }.width('100%').alignItems(VerticalAlign.Center)
      .padding({ top: 6 })
      .onClick(() => { this.toggleConflicts(r); })

      if (this.expandedConflictId === r.id) {
        this.ConflictList()
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder ConflictList() {
    Column({ space: 8 }) {
      if (this.conflictLoading) {
        Text($r('app.string.adminselection_conflict_loading')).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      } else if (this.conflictError.length > 0) {
        Text(this.conflictError).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT)
      } else if (this.conflicts.length === 0) {
        Text($r('app.string.adminselection_no_conflict')).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      } else {
        ForEach(this.conflicts, (c: RoundConflict) => {
          Column({ space: 4 }) {
            Row() {
              AppIcon({ name: 'students', iconSize: 12, mRight: 5 })
              Text(`${c.studentName} · ${c.studentId}`).fontSize(12).fontColor(ElysiaTheme.INK).layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Center)
            Text(`甲：${c.courseA}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
            Text(`乙：${c.courseB}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
          }.width('100%').alignItems(HorizontalAlign.Start)
          .padding(10).backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(12)
          .border({ width: 1, color: '#33D8546B' })
        }, (c: RoundConflict) => c.id)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
    .padding({ top: 4 })
  }

  @Builder MiniStat(label: string, value: string) {
    Column() {
      Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder EditSheet() {
    Column() {
      Column().layoutWeight(1).width('100%')
        .backgroundColor(ElysiaTheme.scrim())
        .onClick(() => { this.cancelEdit(); })

      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.adminselection_edit_time')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
          Pill({ text: this.editingName, color: ElysiaTheme.ROSE_700, bg: '#FFE9F1' })
        }.width('100%')

        Text($r('app.string.adminselection_format_hint')).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)

        Column({ space: 6 }) {
          Text($r('app.string.adminselection_start')).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
          ElysiaInput({ placeholder: $r('app.string.adminselection_start_ph'), value: $startText, leadingIcon: 'calendar' })
        }.width('100%').alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text($r('app.string.adminselection_end')).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
          ElysiaInput({ placeholder: $r('app.string.adminselection_end_ph'), value: $endText, leadingIcon: 'calendar' })
        }.width('100%').alignItems(HorizontalAlign.Start)

        if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
        }

        Row({ space: 10 }) {
          GhostButton({ text: $r('app.string.common_cancel'), onTap: () => { this.cancelEdit(); } }).layoutWeight(1)
          PrimaryButton({ text: this.submitting ? $r('app.string.common_saving') : $r('app.string.common_save'), onTap: () => { this.saveTime(); } }).layoutWeight(1)
        }
        Blank().height(20)
      }.width('100%').padding(20)
      .backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminSelectionPageBuilder() {
  NavDestination() {
    AdminSelectionPage()
  }
  .hideTitleBar(true)
}
