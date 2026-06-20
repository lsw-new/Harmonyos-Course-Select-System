// 考试管理 · Admin Exams
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminExamItem, AdminExamWritePayload, AdminCourseItem } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { EmptyState, ErrorState } from '../common/widgets/StateViews';
import { SkeletonList } from '../common/widgets/Skeleton';
import { ArrayDataSource } from '../common/widgets/DataSource';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminExamsPage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State formError: string = '';
  @State exams: AdminExamItem[] = [];
  private examsDs: ArrayDataSource<AdminExamItem> = new ArrayDataSource<AdminExamItem>();
  @State courses: AdminCourseItem[] = [];
  @State isEditing: boolean = false;
  @State editingId: string = '';
  @State courseId: string = '';
  @State term: string = '';
  @State examDate: string = '';
  @State startTime: string = '';
  @State endTime: string = '';
  @State location: string = '';
  @State seatNo: string = '';
  @State examType: string = 'final';
  @State pendingDeleteId: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private examTypes: string[] = ['final', 'midterm', 'makeup', 'quiz'];
  private examTypeLabels: string[] = ['期末', '期中', '补考', '测验'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminExams)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    AdminRepository.get().getExams().then((list: AdminExamItem[]) => {
      this.exams = list;
      this.examsDs.setData(list);
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
    // 课程目录用于表单选课（复用管理端课程接口）
    AdminRepository.get().getCourses().then((list: AdminCourseItem[]) => {
      this.courses = list;
    }).catch((e: object) => {
      // 课程目录加载失败不阻断考试列表展示
    });
  }

  private examTypeLabel(t: string): string {
    if (t === 'final') return '期末';
    if (t === 'midterm') return '期中';
    if (t === 'makeup') return '补考';
    if (t === 'quiz') return '测验';
    return t;
  }

  private courseLabel(id: string): string {
    const hit = this.courses.find((c: AdminCourseItem) => c.id === id);
    if (hit) {
      return hit.name;
    }
    return id;
  }

  private resetForm(): void {
    this.editingId = '';
    this.courseId = '';
    this.term = '';
    this.examDate = '';
    this.startTime = '';
    this.endTime = '';
    this.location = '';
    this.seatNo = '';
    this.examType = 'final';
    this.formError = '';
  }

  private openCreate(): void {
    this.pendingDeleteId = '';
    this.resetForm();
    this.isEditing = true;
  }

  private openEdit(e: AdminExamItem): void {
    this.pendingDeleteId = '';
    this.editingId = e.examId;
    this.courseId = e.courseId;
    this.term = e.term;
    this.examDate = e.examDate;
    this.startTime = e.startTime;
    this.endTime = e.endTime;
    this.location = e.location;
    this.seatNo = e.seatNo;
    this.examType = e.examType.length > 0 ? e.examType : 'final';
    this.formError = '';
    this.isEditing = true;
  }

  private cancelEdit(): void {
    this.isEditing = false;
    this.resetForm();
  }

  // 校验：courseId/term 必填；时间可空但给定须 HH:MM 24h
  private isValidTime(value: string): boolean {
    const v = value.trim();
    if (v.length === 0) {
      return true;
    }
    const re = new RegExp('^([01][0-9]|2[0-3]):[0-5][0-9]$');
    return re.test(v);
  }

  private buildPayload(): AdminExamWritePayload | null {
    const courseIdTrim = this.courseId.trim();
    const termTrim = this.term.trim();
    if (courseIdTrim.length === 0) {
      this.formError = '请选择课程';
      return null;
    }
    if (termTrim.length === 0) {
      this.formError = '请填写学期';
      return null;
    }
    if (!this.isValidTime(this.startTime)) {
      this.formError = '开始时间需为 HH:MM（24 小时制）';
      return null;
    }
    if (!this.isValidTime(this.endTime)) {
      this.formError = '结束时间需为 HH:MM（24 小时制）';
      return null;
    }
    const payload: AdminExamWritePayload = {
      courseId: courseIdTrim,
      term: termTrim,
      examDate: this.examDate.trim(),
      startTime: this.startTime.trim(),
      endTime: this.endTime.trim(),
      location: this.location.trim(),
      seatNo: this.seatNo.trim(),
      examType: this.examType.length > 0 ? this.examType : 'final'
    };
    return payload;
  }

  private saveExam(): void {
    if (this.submitting) return;
    const payload = this.buildPayload();
    if (payload === null) return;
    this.submitting = true;
    this.formError = '';
    const repo = AdminRepository.get();
    const action = this.editingId.length > 0 ? repo.updateExam(this.editingId, payload) : repo.createExam(payload);
    action.then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), this.editingId.length > 0 ? '考试已更新' : '考试已新增');
      this.cancelEdit();
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  private requestDelete(e: AdminExamItem): void {
    if (this.submitting) return;
    this.pendingDeleteId = e.examId;
    this.formError = `确认删除考试「${this.courseLabel(e.courseId)}」？`;
  }

  private cancelDelete(): void {
    this.pendingDeleteId = '';
    this.formError = '';
  }

  private deleteExam(e: AdminExamItem): void {
    if (this.submitting) return;
    this.submitting = true;
    this.formError = '';
    AdminRepository.get().deleteExam(e.examId).then(() => {
      this.submitting = false;
      this.pendingDeleteId = '';
      Toast.show(this.getUIContext(), '考试已删除');
      if (this.editingId === e.examId) {
        this.cancelEdit();
      }
      this.loadData();
    }).catch((err: object) => {
      this.submitting = false;
      const msg = (err instanceof HttpError) ? (err as HttpError).message : '删除失败';
      this.formError = msg;
      Toast.show(this.getUIContext(), msg);
    });
  }

  @Builder CourseSelect() {
    Column({ space: 6 }) {
      Text('课程').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.courses, (c: AdminCourseItem) => {
            Text(c.name).fontSize(12)
              .fontColor(this.courseId === c.id ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.courseId === c.id ? ElysiaTheme.ROSE_500 : '#FFE9F1')
              .borderRadius(999)
              .onClick(() => { this.courseId = c.id; })
          }, (c: AdminCourseItem) => `exc-${c.id}-${this.courseId === c.id}`)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder TypeSelect() {
    Column({ space: 6 }) {
      Text('考试类型').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
      Row({ space: 8 }) {
        ForEach(this.examTypeLabels, (label: string, idx: number) => {
          Text(label).fontSize(12)
            .fontColor(this.examType === this.examTypes[idx] ? Color.White : ElysiaTheme.ROSE_700)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.examType === this.examTypes[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
            .borderRadius(999)
            .onClick(() => { this.examType = this.examTypes[idx]; })
        }, (label: string, idx: number) => `etp-${idx}`)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '考试管理', subtitle: '维护考试安排', showBack: true, onBack: () => {
          if (this.isEditing) {
            this.cancelEdit();
          } else {
            AppRoute.back();
          }
        } })

        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Blank().layoutWeight(1)
            Text('新增考试').fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
              .onClick(() => { this.openCreate(); })
          }.width('100%')
        }.padding({ left: 16, right: 16 })

        if (this.isEditing) {
          Scroll() {
            Column({ space: 10 }) {
              Text(this.editingId.length > 0 ? '编辑考试' : '新增考试')
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              this.CourseSelect()
              ElysiaInput({ placeholder: '学期（如 2025-2026-1）', value: $term, leadingIcon: 'time' })
              ElysiaInput({ placeholder: '考试日期（如 2026-07-01）', value: $examDate, leadingIcon: 'time' })
              Row({ space: 8 }) {
                TextInput({ placeholder: '开始 HH:MM', text: this.startTime })
                  .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .layoutWeight(1)
                  .onChange((v: string) => { this.startTime = v; })
                TextInput({ placeholder: '结束 HH:MM', text: this.endTime })
                  .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .layoutWeight(1)
                  .onChange((v: string) => { this.endTime = v; })
              }.width('100%')
              ElysiaInput({ placeholder: '考场地点', value: $location, leadingIcon: 'course' })
              ElysiaInput({ placeholder: '座位号', value: $seatNo, leadingIcon: 'edit' })
              this.TypeSelect()

              if (this.formError.length > 0) {
                Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
              }

              Row({ space: 10 }) {
                GhostButton({ text: '取消', onTap: () => this.cancelEdit() }).layoutWeight(1)
                PrimaryButton({ text: this.submitting ? '保存中...' : '保存', onTap: () => this.saveExam() }).layoutWeight(1)
              }
            }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
          }.height(480).padding({ left: 16, right: 16, top: 10 }).scrollBar(BarState.Off)
        } else if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
            .padding({ left: 16, right: 16, top: 8 })
        }

        if (this.loading) {
          Column() { SkeletonList({ count: 6 }) }.layoutWeight(1).width('100%')
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.exams.length === 0) {
          Column() { EmptyState({ title: '暂无考试安排' }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          List() {
            LazyForEach(this.examsDs, (e: AdminExamItem) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(e.courseName.length > 0 ? e.courseName : this.courseLabel(e.courseId)).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: this.examTypeLabel(e.examType), color: ElysiaTheme.ROSE_700, bg: ElysiaTheme.SURFACE_GLOW })
                  }.width('100%')
                  Text(`${e.courseCode.length > 0 ? e.courseCode : '—'} · ${e.term.length > 0 ? e.term : '—'}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width('100%')
                  Text(`${e.examDate.length > 0 ? e.examDate : '日期待定'} ${e.startTime}${e.endTime.length > 0 ? '-' + e.endTime : ''} · ${e.location.length > 0 ? e.location : '地点待定'}${e.seatNo.length > 0 ? ' · 座位' + e.seatNo : ''}`)
                    .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width('100%')
                  Row() {
                    if (this.pendingDeleteId === e.examId) {
                      Text('确认删除该考试').fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
                      Text('取消').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#F5F2F4').borderRadius(999)
                        .margin({ right: 10 })
                        .onClick(() => { this.cancelDelete(); })
                      Text('确认删除').fontSize(12).fontColor(Color.White)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
                        .onClick(() => { this.deleteExam(e); })
                    } else {
                      Blank().layoutWeight(1)
                      Text('编辑').fontSize(12).fontColor(ElysiaTheme.ROSE_700)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#FFE9F1').borderRadius(999)
                        .margin({ right: 12 })
                        .onClick(() => { this.openEdit(e); })
                      Text('删除').fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#FFF0F3').borderRadius(999)
                        .onClick(() => { this.requestDelete(e); })
                    }
                  }.width('100%').alignItems(VerticalAlign.Center)
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }.margin({ bottom: 8 })
            }, (e: AdminExamItem) => e.examId)
          }.layoutWeight(1).cachedCount(6).padding({ left: 16, right: 16, top: 10 })
        }

        AdminTabBar({ active: 'dashboard', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }.width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminExamsPageBuilder() {
  NavDestination() {
    AdminExamsPage()
  }
  .hideTitleBar(true)
}
