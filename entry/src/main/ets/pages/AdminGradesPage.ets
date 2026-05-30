// 成绩审核 · Notes
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { GradeAuditItem } from '../models/Admin';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { AppRoute, Routes } from '../app/AppRoute';
import promptAction from '@ohos.promptAction';
import { SafeTop } from '../common/widgets/SafeArea';

@Entry
@Component
struct AdminGradesPage {
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
      promptAction.showToast({ message: '审核已通过' });
      this.loadData();
    }).catch((e: object) => {
      this.approvingId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '审核失败';
      promptAction.showToast({ message: this.formErrorMsg });
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
      promptAction.showToast({ message: progress === 100 ? '成绩已提交审核' : '录入进度已保存' });
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
      promptAction.showToast({ message: '已驳回，需重录' });
      this.loadData();
    }).catch((e: object) => {
      this.submittingId = '';
      this.formErrorMsg = (e instanceof HttpError) ? (e as HttpError).message : '驳回失败';
    });
  }

  private canInput(item: GradeAuditItem): boolean {
    return item.status === 'inputting' || item.status === 'rejected' || item.status === 'appealed';
  }

  private statusColor(s: string): string {
    if (s === 'pendingAudit') return '#D9B675';
    if (s === 'inputting') return ElysiaTheme.ROSE_500;
    if (s === 'published') return '#7BB07B';
    if (s === 'rejected') return '#D8546B';
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
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '成绩管理', subtitle: '成 绩 管 理', onBack: () => AppRoute.back() })

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
          EmptyState({ title: '暂无成绩记录' })
        } else {
          if (this.formErrorMsg.length > 0) {
            Text(this.formErrorMsg).fontSize(11).fontColor('#D8546B')
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
                    Text(`驳回理由：${item.rejectReason}`).fontSize(11).fontColor('#D8546B')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .backgroundColor('#FFF0F0')
                      .borderRadius(10)
                  }
                  Row() {
                    Column().height(6).width(`${item.inputProgress}%`).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(3)
                  }.width('100%').height(6).backgroundColor('#FFE9F1').borderRadius(3)
                  Row() {
                    Text(`录入 ${item.inputProgress}% · ${item.updatedAt}`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                    if (this.canInput(item)) {
                      Text(this.editingId === item.id ? '收起录入' : '录入成绩').fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor('#FFE9F1')
                        .borderRadius(999)
                        .onClick(() => {
                          if (this.editingId === item.id) {
                            this.cancelInput();
                          } else {
                            this.beginInput(item);
                          }
                        })
                    }
                    if (item.status === 'pendingAudit') {
                      Text('驳回').fontSize(11).fontColor('#D8546B')
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor('#FFF0F0')
                        .borderRadius(999)
                        .margin({ left: 6 })
                        .onClick(() => { this.beginReject(item.id); })
                      Text('审核通过').fontSize(11).fontColor(Color.White)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor(this.approvingId === item.id ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500)
                        .borderRadius(999)
                        .margin({ left: 6 })
                        .enabled(this.approvingId !== item.id)
                        .onClick(() => { this.approve(item.id); })
                    }
                  }.width('100%')

                  if (this.editingId === item.id) {
                    Column({ space: 8 }) {
                      TextInput({ placeholder: '录入进度 0-100，100 后提交审核', text: this.progressText })
                        .type(InputType.Number)
                        .height(38)
                        .fontSize(12)
                        .fontColor(ElysiaTheme.INK)
                        .backgroundColor(ElysiaTheme.glass())
                        .border({ width: 1, color: ElysiaTheme.hairline() })
                        .borderRadius(12)
                        .onChange((v: string) => { this.progressText = v; })
                      Row({ space: 8 }) {
                        Text('取消').fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor('#FFE9F1')
                          .borderRadius(999)
                          .onClick(() => { this.cancelInput(); })
                        Text(this.submittingId === item.id ? '保存中...' : '保存录入').fontSize(11).fontColor(Color.White)
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
                      Text('请填写驳回理由，确认后该记录将标记为“已驳回/需重录”。').fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                      TextArea({ placeholder: '驳回理由（1-120 字，不能换行）', text: this.rejectReason })
                        .height(70)
                        .fontSize(12)
                        .fontColor(ElysiaTheme.INK)
                        .backgroundColor(ElysiaTheme.glass())
                        .border({ width: 1, color: ElysiaTheme.hairline() })
                        .borderRadius(12)
                        .onChange((v: string) => { this.rejectReason = v; })
                      Row({ space: 8 }) {
                        Text('取消').fontSize(11).fontColor(ElysiaTheme.ROSE_700)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor('#FFE9F1')
                          .borderRadius(999)
                          .onClick(() => { this.cancelReject(); })
                        Text(this.submittingId === item.id ? '驳回中...' : '确认驳回').fontSize(11).fontColor(Color.White)
                          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                          .backgroundColor(this.submittingId === item.id ? ElysiaTheme.INK_MUTE : '#D8546B')
                          .borderRadius(999)
                          .enabled(this.submittingId !== item.id)
                          .onClick(() => { this.submitReject(item.id); })
                      }.width('100%').justifyContent(FlexAlign.End)
                    }.width('100%').padding(10).backgroundColor(ElysiaTheme.glassSoft()).borderRadius(12)
                  }

                  if (this.formErrorMsg.length > 0 && (this.editingId === item.id || this.rejectingId === item.id)) {
                    Text(this.formErrorMsg).fontSize(11).fontColor('#D8546B')
                  }
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }.margin({ bottom: 8 })
            }, (item: GradeAuditItem) => item.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10, bottom: this.safeBottom + 24 })
        }
      }
    }.width('100%').height('100%')
  }
}
