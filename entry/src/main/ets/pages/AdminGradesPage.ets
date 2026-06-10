// 成绩审核 · Notes
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { GradeAuditItem, GradeScoreRow } from '../models/Admin';
import { GradeScoreEntry } from '../common/remote/RemoteApi';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

// 打分编辑行：学生 + 可编辑分数文本（空串=暂不打分）
interface ScoreEditRow {
  studentId: string;
  name: string;
  scoreText: string;
}

@Component
struct AdminGradesPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State loading: boolean = true;
  @State items: GradeAuditItem[] = [];
  @State activeStatus: string = '全部';
  @State errorMsg: string = '';
  @State formErrorMsg: string = '';
  @State approvingId: string = '';
  @State editingId: string = '';
  @State progressText: string = '';
  @State rejectingId: string = '';
  @State rejectReason: string = '';
  @State submittingId: string = '';
  // 按学生打分面板
  @State scoringId: string = '';
  @State scoreRows: ScoreEditRow[] = [];
  @State scoresLoading: boolean = false;
  @State savingScores: boolean = false;
  // 底部手势条避让（vp）：List 无 TabBar 兜底，需自行留出底部安全区。
  @StorageProp('safeBottom') safeBottom: number = 0;
  private statuses: string[] = ['全部', 'pendingAudit', 'inputting', 'rejected', 'published', 'appealed'];
  private statusLabels: string[] = ['全部', '待审核', '录入中', '已驳回', '已发布', '异议'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminGrades)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const s = this.activeStatus === '全部' ? undefined : this.activeStatus;
    AdminRepository.get().getGradeAudits(s).then((list: GradeAuditItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private approve(id: string): void {
    this.approvingId = id;
    this.formErrorMsg = '';
    AdminRepository.get().approveGrade(id).then(() => {
      this.approvingId = '';
      Toast.show(this.getUIContext(), '审核已通过');
      this.loadData();
    }).catch((e: object) => {
      this.approvingId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '审核失败';
      Toast.show(this.getUIContext(), this.formErrorMsg);
    });
  }

  private beginInput(item: GradeAuditItem): void {
    this.editingId = item.id;
    this.progressText = `${item.inputProgress}`;
    this.rejectingId = '';
    this.rejectReason = '';
    this.formErrorMsg = '';
  }

  private cancelInput(): void {
    this.editingId = '';
    this.progressText = '';
  }

  private submitInput(id: string): void {
    const progress = Number(this.progressText.trim());
    if (!(progress === progress) || progress === Infinity || progress === -Infinity || Math.floor(progress) !== progress || progress < 0 || progress > 100) {
      this.formErrorMsg = '录入进度需为 0-100 的整数';
      return;
    }
    this.submittingId = id;
    AdminRepository.get().inputGrade({ id: id, inputProgress: progress }).then(() => {
      this.submittingId = '';
      this.editingId = '';
      this.progressText = '';
      Toast.show(this.getUIContext(), progress === 100 ? '成绩已提交审核' : '录入进度已保存');
      this.loadData();
    }).catch((e: object) => {
      this.submittingId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '录入失败';
    });
  }

  private beginReject(id: string): void {
    this.rejectingId = id;
    this.rejectReason = '';
    this.editingId = '';
    this.progressText = '';
    this.formErrorMsg = '';
  }

  private cancelReject(): void {
    this.rejectingId = '';
    this.rejectReason = '';
  }

  private submitReject(id: string): void {
    if (this.rejectReason.trim().length === 0) {
      this.formErrorMsg = '请填写驳回理由';
      return;
    }
    this.submittingId = id;
    AdminRepository.get().rejectGrade({ id: id, reason: this.rejectReason }).then(() => {
      this.submittingId = '';
      this.rejectingId = '';
      this.rejectReason = '';
      Toast.show(this.getUIContext(), '已驳回，需重录');
      this.loadData();
    }).catch((e: object) => {
      this.submittingId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '驳回失败';
    });
  }

  private canInput(item: GradeAuditItem): boolean {
    return item.status === 'inputting' || item.status === 'rejected' || item.status === 'appealed';
  }

  // ---- 按学生打分 ----

  private beginScoring(item: GradeAuditItem): void {
    this.scoringId = item.id;
    this.editingId = '';
    this.rejectingId = '';
    this.formErrorMsg = '';
    this.scoreRows = [];
    this.scoresLoading = true;
    AdminRepository.get().getGradeScores(item.id).then((rows: GradeScoreRow[]) => {
      this.scoreRows = rows.map((r): ScoreEditRow => {
        const row: ScoreEditRow = { studentId: r.studentId, name: r.name, scoreText: r.score === null ? '' : `${r.score}` };
        return row;
      });
      this.scoresLoading = false;
    }).catch((e: object) => {
      this.scoresLoading = false;
      this.scoringId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '打分名单加载失败';
      Toast.show(this.getUIContext(), this.formErrorMsg);
    });
  }

  private cancelScoring(): void {
    this.scoringId = '';
    this.scoreRows = [];
  }

  private submitScores(id: string): void {
    const entries: GradeScoreEntry[] = [];
    for (let i = 0; i < this.scoreRows.length; i++) {
      const text = this.scoreRows[i].scoreText.trim();
      if (text.length === 0) {
        continue;
      }
      const value = Number(text);
      if (!Number.isFinite(value) || value < 0 || value > 100) {
        this.formErrorMsg = `「${this.scoreRows[i].name}」的分数需为 0-100`;
        return;
      }
      entries.push({ studentId: this.scoreRows[i].studentId, score: value });
    }
    if (entries.length === 0) {
      this.formErrorMsg = '请先填写至少一名学生的分数';
      return;
    }
    this.formErrorMsg = '';
    this.savingScores = true;
    AdminRepository.get().submitGradeScores(id, entries).then((updated: GradeAuditItem) => {
      this.savingScores = false;
      const idx = this.items.findIndex((it) => it.id === id);
      if (idx >= 0) {
        this.items.splice(idx, 1, updated);
      }
      Toast.show(this.getUIContext(), updated.inputProgress === 100
        ? '打分完成，已转待审核（审核通过后学生可见）'
        : `已保存 ${entries.length} 人分数（进度 ${updated.inputProgress}%）`);
    }).catch((e: object) => {
      this.savingScores = false;
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '保存打分失败';
    });
  }

  private statusColor(s: string): string {
    if (s === 'pendingAudit') return '#D9B675';
    if (s === 'inputting') return ElysiaTheme.ROSE_500;
    if (s === 'published') return ElysiaTheme.SUCCESS;
    if (s === 'rejected') return ElysiaTheme.ROSE_ACCENT;
    return '#B589FF';
  }

  private statusText(s: string): string {
    if (s === 'pendingAudit') return '待审核';
    if (s === 'inputting') return '录入中';
    if (s === 'published') return '已发布';
    if (s === 'rejected') return '已驳回/需重录';
    return '异议';
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.admingrades_title'), subtitle: $r('app.string.admingrades_subtitle'), onBack: () => AppRoute.back() })

        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.statusLabels, (label: string, idx: number) => {
              Text(label).fontSize(11)
                .fontColor(this.activeStatus === this.statuses[idx] ? Color.White : ElysiaTheme.ROSE_700)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.activeStatus === this.statuses[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                .borderRadius(999)
                .onClick(() => { this.activeStatus = this.statuses[idx]; this.loadData(); })
            }, (label: string, idx: number) => `gs-${idx}`)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).padding({ left: 16, right: 16 }).margin({ top: 8 })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => { this.loadData(); } })
        } else if (this.items.length === 0) {
          EmptyState({ title: $r('app.string.admingrades_empty') })
        } else {
          if (this.formErrorMsg.length > 0) {
            Text(this.formErrorMsg).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT)
              .width('100%')
              .padding({ left: 16, right: 16, top: 8 })
          }
          List() {
            ForEach(this.items, (item: GradeAuditItem) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(item.courseName).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: this.statusText(item.status), color: this.statusColor(item.status), bg: '#FFF6FA' })
                  }.width('100%')
                  Text(`${item.teachingClassName} · ${item.teacherName}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  if (item.status === 'rejected' && item.rejectReason !== undefined && item.rejectReason.length > 0) {
                    Text(`驳回理由：${item.rejectReason}`).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT)
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .backgroundColor('#FFF0F0')
                      .borderRadius(10)
                  }
                  Row() {
                    Column().height(6).width(`${item.inputProgress}%`).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(3)
                  }.width('100%').height(6).backgroundColor('#FFE9F1').borderRadius(3)
                  Row() {
                    Text(`录入 ${item.inputProgress}% · ${item.updatedAt}`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                    if (item.status !== 'published') {
                      Text(this.scoringId === item.id ? $r('app.string.admingrades_score_collapse') : $r('app.string.admingrades_score_btn')).fontSize(11).fontColor(Color.White)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor(ElysiaTheme.ROSE_500)
                        .borderRadius(999)
                        .onClick(() => {
                          if (this.scoringId === item.id) {
                            this.cancelScoring();
                          } else {
                            this.beginScoring(item);
                          }
                        })
                    }
                    if (this.canInput(item)) {
                      Text(this.editingId === item.id ? $r('app.string.admingrades_collapse_input') : $r('app.string.admingrades_input_grade')).fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor('#FFE9F1')
                        .borderRadius(999)
                        .margin({ left: 6 })
                        .onClick(() => {
                          if (this.editingId === item.id) {
                            this.cancelInput();
                          } else {
                            this.beginInput(item);
                          }
                        })
                    }
                    if (item.status === 'pendingAudit') {
                      Text($r('app.string.admingrades_reject')).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor('#FFF0F0')
                        .borderRadius(999)
                        .margin({ left: 6 })
                        .onClick(() => { this.beginReject(item.id); })
                      Text($r('app.string.admingrades_approve')).fontSize(11).fontColor(Color.White)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor(this.approvingId === item.id ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                        .borderRadius(999)
                        .margin({ left: 6 })
                        .enabled(this.approvingId !== item.id)
                        .onClick(() => { this.approve(item.id); })
                    }
                  }.width('100%')

                  if (this.scoringId === item.id) {
                    Column({ space: 8 }) {
                      if (this.scoresLoading) {
                        Text($r('app.string.admingrades_score_loading')).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                          .width('100%').textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
                      } else if (this.scoreRows.length === 0) {
                        Text($r('app.string.admingrades_score_empty')).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                          .width('100%').textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
                      } else {
                        Text($r('app.string.admingrades_score_note')).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
                        ForEach(this.scoreRows, (row: ScoreEditRow) => {
                          Row({ space: 8 }) {
                            Text(row.name).fontSize(12).fontColor(ElysiaTheme.INK).layoutWeight(1)
                            Text(row.studentId).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
                            TextInput({ placeholder: $r('app.string.admingrades_score_ph'), text: row.scoreText })
                              .type(InputType.NUMBER_DECIMAL)
                              .width(76)
                              .height(34)
                              .fontSize(12)
                              .fontColor(ElysiaTheme.INK)
                              .backgroundColor(ElysiaTheme.glass())
                              .border({ width: 1, color: ElysiaTheme.hairline() })
                              .borderRadius(10)
                              .onChange((v: string) => { row.scoreText = v; })
                          }.width('100%')
                        }, (row: ScoreEditRow) => row.studentId)
                        Row({ space: 8 }) {
                          Text($r('app.string.common_cancel')).fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                            .backgroundColor('#FFE9F1')
                            .borderRadius(999)
                            .onClick(() => { this.cancelScoring(); })
                          Text(this.savingScores ? $r('app.string.admingrades_score_saving') : $r('app.string.admingrades_score_save')).fontSize(11).fontColor(Color.White)
                            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                            .backgroundColor(this.savingScores ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                            .borderRadius(999)
                            .enabled(!this.savingScores)
                            .onClick(() => { this.submitScores(item.id); })
                        }.width('100%').justifyContent(FlexAlign.End)
                      }
                    }.width('100%').padding(10).backgroundColor(ElysiaTheme.glassSoft()).borderRadius(12)
                  }

                  if (this.editingId === item.id) {
                    Column({ space: 8 }) {
                      TextInput({ placeholder: $r('app.string.admingrades_progress_ph'), text: this.progressText })
                        .type(InputType.Number)
                        .height(38)
                        .fontSize(12)
                        .fontColor(ElysiaTheme.INK)
                        .backgroundColor(ElysiaTheme.glass())
                        .border({ width: 1, color: ElysiaTheme.hairline() })
                        .borderRadius(12)
                        .onChange((v: string) => { this.progressText = v; })
                      Row({ space: 8 }) {
                        Text($r('app.string.common_cancel')).fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor('#FFE9F1')
                          .borderRadius(999)
                          .onClick(() => { this.cancelInput(); })
                        Text(this.submittingId === item.id ? $r('app.string.common_saving') : $r('app.string.admingrades_save_input')).fontSize(11).fontColor(Color.White)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor(this.submittingId === item.id ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                          .borderRadius(999)
                          .enabled(this.submittingId !== item.id)
                          .onClick(() => { this.submitInput(item.id); })
                      }.width('100%').justifyContent(FlexAlign.End)
                    }.width('100%').padding(10).backgroundColor(ElysiaTheme.glassSoft()).borderRadius(12)
                  }

                  if (this.rejectingId === item.id) {
                    Column({ space: 8 }) {
                      Text($r('app.string.admingrades_reject_note')).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                      TextArea({ placeholder: $r('app.string.admingrades_reject_ph'), text: this.rejectReason })
                        .height(70)
                        .fontSize(12)
                        .fontColor(ElysiaTheme.INK)
                        .backgroundColor(ElysiaTheme.glass())
                        .border({ width: 1, color: ElysiaTheme.hairline() })
                        .borderRadius(12)
                        .onChange((v: string) => { this.rejectReason = v; })
                      Row({ space: 8 }) {
                        Text($r('app.string.common_cancel')).fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor('#FFE9F1')
                          .borderRadius(999)
                          .onClick(() => { this.cancelReject(); })
                        Text(this.submittingId === item.id ? $r('app.string.admingrades_rejecting') : $r('app.string.admingrades_confirm_reject')).fontSize(11).fontColor(Color.White)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor(this.submittingId === item.id ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_ACCENT)
                          .borderRadius(999)
                          .enabled(this.submittingId !== item.id)
                          .onClick(() => { this.submitReject(item.id); })
                      }.width('100%').justifyContent(FlexAlign.End)
                    }.width('100%').padding(10).backgroundColor(ElysiaTheme.glassSoft()).borderRadius(12)
                  }

                  if (this.formErrorMsg.length > 0 && (this.editingId === item.id || this.rejectingId === item.id || this.scoringId === item.id)) {
                    Text(this.formErrorMsg).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT)
                  }
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }.margin({ bottom: 8 })
            }, (item: GradeAuditItem) => item.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10, bottom: this.safeBottom + 24 })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminGradesPageBuilder() {
  NavDestination() {
    AdminGradesPage()
  }
  .hideTitleBar(true)
}
