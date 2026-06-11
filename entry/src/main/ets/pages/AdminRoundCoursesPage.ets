// 选课课程管理（按轮次入口）· Cours de Sélection
// 从「选课管理」点击轮次进入：面向年级发布选课课程，对应年级学生可见可选；
// 增删改查直写后端 courses 表（与学生选课中心/课表派生同源同步）。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminCourseItem, AdminCourseWritePayload, AdminCourseCategory, AdminCourseStatus } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminRoundCoursesPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @StorageProp('safeBottom') safeBottom: number = 0;
  @State courses: AdminCourseItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State submitting: boolean = false;
  // 二次确认删除的课程 id
  @State pendingDeleteId: string = '';
  // 新增 / 编辑底部表单
  @State sheetOpen: boolean = false;
  @State editingId: string = '';
  @State fName: string = '';
  @State fCode: string = '';
  @State fTeacher: string = '';
  @State fCredit: string = '2';
  @State fCapacity: string = '40';
  @State fTime: string = '';
  @State fGrade: string = '';
  @State fCategory: string = 'elective';
  @State fStatus: string = 'open';
  @State formError: string = '';
  // 轮次名（路由参数带入，仅作页头展示）
  @State roundName: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminRoundCourses)) {
      return;
    }
    this.roundName = AppRoute.getParam<string>('roundName', '选课轮次');
    this.load();
  }

  private load(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.error = '';
    AdminRepository.get().getCourses()
      .then((list: AdminCourseItem[]) => {
        // 本页聚焦选课中心课程：选修 / 公选（必修走班级课表，不在此管理）
        this.courses = list.filter((c: AdminCourseItem) => c.category === 'elective' || c.category === 'public');
        this.loading = false;
      })
      .catch((e: object) => {
        this.error = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private gradeLabel(c: AdminCourseItem): string {
    const g = c.targetGrade ?? '';
    return g.length > 0 ? `面向 ${g}` : '全部年级';
  }

  private statusLabel(s: AdminCourseStatus): string {
    if (s === 'open') return '选课开放';
    if (s === 'closed') return '已下架';
    if (s === 'draft') return '草稿';
    return '已归档';
  }

  private statusColor(s: AdminCourseStatus): string {
    return s === 'open' ? '#2E7D32' : ElysiaTheme.INK_MUTE;
  }

  private statusBg(s: AdminCourseStatus): string {
    return s === 'open' ? '#E6F4EA' : '#F5F2F4';
  }

  private openCreate(): void {
    this.editingId = '';
    this.fName = '';
    this.fCode = '';
    this.fTeacher = '';
    this.fCredit = '2';
    this.fCapacity = '40';
    this.fTime = '';
    this.fGrade = '';
    this.fCategory = 'elective';
    this.fStatus = 'open';
    this.formError = '';
    this.sheetOpen = true;
  }

  private openEdit(c: AdminCourseItem): void {
    this.editingId = c.id;
    this.fName = c.name;
    this.fCode = c.code;
    this.fTeacher = c.teacher;
    this.fCredit = String(c.credit);
    this.fCapacity = String(c.capacity);
    this.fTime = c.timeText;
    this.fGrade = c.targetGrade ?? '';
    this.fCategory = c.category;
    this.fStatus = c.status;
    this.formError = '';
    this.sheetOpen = true;
  }

  private save(): void {
    if (this.submitting) {
      return;
    }
    const name = this.fName.trim();
    const code = this.fCode.trim();
    const teacher = this.fTeacher.trim();
    const credit = Number(this.fCredit.trim());
    const capacity = Number(this.fCapacity.trim());
    const grade = this.fGrade.trim();
    if (name.length === 0 || code.length === 0 || teacher.length === 0) {
      this.formError = '课程名称 / 编码 / 教师不能为空';
      return;
    }
    if (!Number.isFinite(credit) || credit <= 0 || credit > 20) {
      this.formError = '学分需为 0-20 之间的数字';
      return;
    }
    if (!Number.isInteger(capacity) || capacity < 0 || capacity > 1000) {
      this.formError = '容量需为 0-1000 的整数';
      return;
    }
    if (grade.length > 0 && !/^20\d{2}级$/.test(grade)) {
      this.formError = '面向年级需为「20XX级」格式（如 2023级），留空＝全部年级';
      return;
    }
    const existing = this.courses.find((c: AdminCourseItem) => c.id === this.editingId);
    const payload: AdminCourseWritePayload = {
      code: code,
      name: name,
      teacher: teacher,
      category: this.fCategory as AdminCourseCategory,
      credit: credit,
      timeText: this.fTime.trim(),
      capacity: capacity,
      selectedCount: existing ? existing.selectedCount : 0,
      status: this.fStatus as AdminCourseStatus,
      targetGrade: grade
    };
    this.submitting = true;
    this.formError = '';
    const promise: Promise<AdminCourseItem> = this.editingId.length > 0
      ? AdminRepository.get().updateCourse(this.editingId, payload)
      : AdminRepository.get().createCourse(payload);
    promise
      .then(() => {
        this.submitting = false;
        this.sheetOpen = false;
        Toast.show(this.getUIContext(), this.editingId.length > 0 ? '课程已保存，选课中心同步生效' : '课程已发布，对应年级即刻可见');
        this.load();
      })
      .catch((e: object) => {
        this.submitting = false;
        this.formError = e instanceof Error ? e.message : '保存失败';
      });
  }

  private doDelete(c: AdminCourseItem): void {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    AdminRepository.get().deleteCourse(c.id)
      .then(() => {
        this.submitting = false;
        this.pendingDeleteId = '';
        Toast.show(this.getUIContext(), '课程已删除');
        this.load();
      })
      .catch((e: object) => {
        this.submitting = false;
        this.pendingDeleteId = '';
        Toast.show(this.getUIContext(), e instanceof Error ? e.message : '删除失败');
      });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: this.roundName, subtitle: '选课课程 · 面向年级发布', onBack: () => { AppRoute.back(); } })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.error.length > 0) {
          Column() { ErrorState({ message: this.error, onRetry: () => { this.load(); } }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              Row() {
                Text(`共 ${this.courses.length} 门选修 / 公选课程`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                Text('＋ 新增课程').fontSize(12).fontColor(Color.White)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]] })
                  .borderRadius(999)
                  .onClick(() => { this.openCreate(); })
              }.width('100%').alignItems(VerticalAlign.Center)

              if (this.courses.length === 0) {
                EmptyState({ icon: 'selection', title: '暂无选课课程，点击右上角新增' })
              } else {
                ForEach(this.courses, (c: AdminCourseItem) => {
                  this.CourseCard(c)
                }, (c: AdminCourseItem) => c.id)
              }
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 10 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }.width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })

      if (this.sheetOpen) {
        this.EditSheet()
      }
    }.width('100%').height('100%')
  }

  @Builder CourseCard(c: AdminCourseItem) {
    Column({ space: 8 }) {
      Row() {
        Text(c.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Pill({ text: this.statusLabel(c.status), color: this.statusColor(c.status), bg: this.statusBg(c.status) })
      }.width('100%')

      Row() {
        AppIcon({ name: 'book', iconSize: 12, mRight: 5 })
        Text(`${c.code} · ${c.teacher} · ${c.credit} 学分`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row() {
        AppIcon({ name: 'time', iconSize: 12, mRight: 5 })
        Text(c.timeText.length > 0 ? c.timeText : '时间待定').fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
        Text(`已选 ${c.selectedCount}/${c.capacity}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Pill({
          text: this.gradeLabel(c),
          color: (c.targetGrade ?? '').length > 0 ? '#6F47A8' : ElysiaTheme.INK_SOFT,
          bg: (c.targetGrade ?? '').length > 0 ? '#F1E2FF' : '#F5F2F4'
        })
        Pill({ text: c.category === 'public' ? '公选' : '选修', color: ElysiaTheme.GOLD_700, bg: '#FBF1DC' })
        Blank().layoutWeight(1)
      }.width('100%')

      if (this.pendingDeleteId === c.id) {
        Row() {
          Text('删除后选课中心立即下架，确认？').fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
          Text('取消').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F5F2F4').borderRadius(999).margin({ right: 10 })
            .onClick(() => { this.pendingDeleteId = ''; })
          Text('确认删除').fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
            .onClick(() => { this.doDelete(c); })
        }.width('100%').alignItems(VerticalAlign.Center)
      } else {
        Row({ space: 8 }) {
          Text('编辑').fontSize(12).fontColor(ElysiaTheme.ROSE_700)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFE9F1').borderRadius(999)
            .opacity(this.submitting ? 0.5 : 1)
            .onClick(() => { this.openEdit(c); })
          Text('删除').fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFF0F3').borderRadius(999)
            .opacity(this.submitting ? 0.5 : 1)
            .onClick(() => { this.pendingDeleteId = c.id; })
        }.width('100%').alignItems(VerticalAlign.Center)
      }
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  @Builder ChoiceChip(label: string, active: boolean, onTap: () => void) {
    Text(label).fontSize(12)
      .fontColor(active ? Color.White : ElysiaTheme.INK_SOFT)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(active ? ElysiaTheme.ROSE_500 : '#F5F2F4')
      .borderRadius(999)
      .onClick(() => { onTap(); })
  }

  @Builder EditSheet() {
    Column() {
      Column().layoutWeight(1).width('100%')
        .backgroundColor(ElysiaTheme.scrim())
        .onClick(() => { this.sheetOpen = false; })

      Column({ space: 10 }) {
        Row() {
          Text(this.editingId.length > 0 ? '编辑选课课程' : '发布选课课程').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
          Pill({ text: this.roundName, color: ElysiaTheme.ROSE_700, bg: '#FFE9F1' })
        }.width('100%')

        Scroll() {
          Column({ space: 10 }) {
            ElysiaInput({ placeholder: '课程名称（如 古典音乐鉴赏）', value: $fName, leadingIcon: 'course' })
            ElysiaInput({ placeholder: '课程编码（如 MUS10102）', value: $fCode, leadingIcon: 'tag' })
            ElysiaInput({ placeholder: '授课教师', value: $fTeacher, leadingIcon: 'students' })
            Row({ space: 10 }) {
              ElysiaInput({ placeholder: '学分', value: $fCredit, leadingIcon: 'star' }).layoutWeight(1)
              ElysiaInput({ placeholder: '容量', value: $fCapacity, leadingIcon: 'roster' }).layoutWeight(1)
            }.width('100%')
            ElysiaInput({ placeholder: '上课时间（如 周二 9-10 节）', value: $fTime, leadingIcon: 'time' })
            ElysiaInput({ placeholder: '面向年级（如 2023级，留空＝全部年级）', value: $fGrade, leadingIcon: 'grades' })

            Row({ space: 8 }) {
              Text('类别').fontSize(12).fontColor(ElysiaTheme.INK_SOFT).width(40)
              this.ChoiceChip('选修', this.fCategory === 'elective', () => { this.fCategory = 'elective'; })
              this.ChoiceChip('公选', this.fCategory === 'public', () => { this.fCategory = 'public'; })
            }.width('100%').alignItems(VerticalAlign.Center)

            Row({ space: 8 }) {
              Text('状态').fontSize(12).fontColor(ElysiaTheme.INK_SOFT).width(40)
              this.ChoiceChip('开放选课', this.fStatus === 'open', () => { this.fStatus = 'open'; })
              this.ChoiceChip('下架', this.fStatus === 'closed', () => { this.fStatus = 'closed'; })
            }.width('100%').alignItems(VerticalAlign.Center)
          }.width('100%')
        }.scrollBar(BarState.Off).constraintSize({ maxHeight: 360 })

        if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
        }

        Row({ space: 10 }) {
          GhostButton({ text: $r('app.string.common_cancel'), onTap: () => { this.sheetOpen = false; } }).layoutWeight(1)
          PrimaryButton({ text: this.submitting ? $r('app.string.common_saving') : $r('app.string.common_save'), onTap: () => { this.save(); } }).layoutWeight(1)
        }
        Blank().height(this.safeBottom + 8)
      }.width('100%').padding(20)
      .backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminRoundCoursesPageBuilder() {
  NavDestination() {
    AdminRoundCoursesPage()
  }
  .hideTitleBar(true)
}
