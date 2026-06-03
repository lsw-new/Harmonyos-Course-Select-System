// 学生详情 · Étudiant — 学籍档案与学籍状态操作（推入式子页）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, GlowCard, Pill } from '../common/Components';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { AppIcon } from '../common/widgets/AppIcon';
import { StudentAdminRepository } from '../repositories/StudentAdminRepository';
import { StudentDetail, StudentStatus } from '../models/StudentDetailModels';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Entry
@Component
struct AdminStudentDetailPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State studentId: string = '';
  @State detail: StudentDetail | null = null;
  @State hasDetail: boolean = false;
  // 待确认的不可逆操作（毕业）；非空时展示确认浮层。
  @State pendingStatus: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminStudentDetail)) {
      return;
    }
    this.studentId = AppRoute.getParam<string>('studentId', '');
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    this.pendingStatus = '';
    if (this.studentId.length === 0) {
      this.loading = false;
      this.hasDetail = false;
      this.detail = null;
      return;
    }
    StudentAdminRepository.get().getDetail(this.studentId).then((d: StudentDetail) => {
      this.detail = d;
      this.hasDetail = true;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.hasDetail = false;
      this.detail = null;
      this.loading = false;
    });
  }

  private statusLabel(s: string): string {
    if (s === 'active') return '在读';
    if (s === 'graduating') return '毕业班';
    if (s === 'suspended') return '休学';
    return '已毕业';
  }

  private statusColor(s: string): string {
    if (s === 'active') return ElysiaTheme.SUCCESS;
    if (s === 'graduating') return '#D9B675';
    if (s === 'suspended') return ElysiaTheme.ROSE_ACCENT;
    return ElysiaTheme.INK_MUTE;
  }

  private applyStatus(nextStatus: StudentStatus, successTip: string): void {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    StudentAdminRepository.get().updateStatus(this.studentId, nextStatus).then((d: StudentDetail) => {
      this.detail = d;
      this.hasDetail = true;
      this.submitting = false;
      this.pendingStatus = '';
      Toast.show(this.getUIContext(), successTip);
    }).catch((e: object) => {
      this.submitting = false;
      this.pendingStatus = '';
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  private requestGraduate(): void {
    if (this.submitting) {
      return;
    }
    // 毕业为不可逆操作，先弹确认浮层。
    this.pendingStatus = 'graduated';
  }

  private cancelPending(): void {
    this.pendingStatus = '';
  }

  @Builder
  InfoRow(icon: string, label: string, value: string) {
    Row() {
      AppIcon({ name: icon, iconSize: 16, mRight: 10 })
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value.length > 0 ? value : '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MetricCell(label: string, value: string, accent: string) {
    Column() {
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(accent)
      Text(label).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(ElysiaTheme.SURFACE_GLOW)
    .borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  @Builder
  HeaderCard(d: StudentDetail) {
    GlowCard() {
      Column() {
        Row() {
          Column() {
            Text(d.name).fontSize(22).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
            Text(`${d.studentId} · ${d.gender} · ${d.grade}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Pill({ text: this.statusLabel(d.status), color: this.statusColor(d.status), bg: '#FFFDFB' })
        }.width('100%')

        Row({ space: 10 }) {
          this.MetricCell('GPA', `${d.gpa}`, ElysiaTheme.ROSE_600)
          this.MetricCell('已修学分', `${d.earnedCredits}`, ElysiaTheme.LAV_500)
          this.MetricCell('培养学分', `${d.totalCredits}`, ElysiaTheme.GOLD_700)
        }.width('100%').margin({ top: 14 })
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  AcademicCard(d: StudentDetail) {
    GlowCard() {
      Column() {
        Text('培养信息').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700).margin({ bottom: 4 })
        this.InfoRow('students', '学院', d.college)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('book', '专业', d.major)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('roster', '班级', d.className)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('star', '辅导员', d.advisor)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('calendar', '入学日期', d.enrollDate)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  ContactCard(d: StudentDetail) {
    GlowCard() {
      Column() {
        Text('联系方式').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700).margin({ bottom: 4 })
        this.InfoRow('phone', '电话', d.phone)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('mail', '邮箱', d.email)
        Divider().strokeWidth(1).color(ElysiaTheme.hairlineSoft())
        this.InfoRow('location', '宿舍', d.dormitory)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  ActionButton(label: string, fg: string, bg: string, border: string, action: () => void) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(fg)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: 11, bottom: 11 })
      .backgroundColor(bg)
      .border({ width: 1, color: border })
      .borderRadius(999)
      .opacity(this.submitting ? 0.5 : 1)
      .onClick(() => { action(); })
  }

  @Builder
  StatusActions(d: StudentDetail) {
    GlowCard() {
      Column() {
        Text('学籍状态操作').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
        Text(`当前状态：${this.statusLabel(d.status)}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 6, bottom: 12 })

        if (d.status === 'active') {
          Row({ space: 10 }) {
            this.ActionButton('办理休学', ElysiaTheme.ROSE_700, '#FFF0F3', '#B3FFB3CE', () => {
              this.applyStatus('suspended', '已办理休学');
            })
            this.ActionButton('进入毕业班', ElysiaTheme.GOLD_700, '#FFF7EC', '#B3F2D5A0', () => {
              this.applyStatus('graduating', '已进入毕业班');
            })
          }.width('100%')
        } else if (d.status === 'suspended') {
          Row() {
            this.ActionButton('办理复学', '#3F7A52', '#EAF6EE', '#A9D8BC', () => {
              this.applyStatus('active', '已办理复学');
            })
          }.width('100%')
        } else if (d.status === 'graduating') {
          Row() {
            this.ActionButton('办理毕业', '#FFFFFF', '#D85487', '#D85487', () => {
              this.requestGraduate();
            })
          }.width('100%')
        } else {
          Row() {
            AppIcon({ name: 'info', iconSize: 16, mRight: 8, dim: true })
            Text('该学生已毕业，学籍状态为终态，无可执行操作。').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Center)
        }

        if (this.pendingStatus === 'graduated') {
          Column() {
            Row() {
              AppIcon({ name: 'warning', iconSize: 16, mRight: 8 })
              Text('毕业为不可逆操作，确认为该学生办理毕业？').fontSize(12).fontColor('#A93C68').layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Center)
            Row({ space: 10 }) {
              this.ActionButton('取消', ElysiaTheme.INK_SOFT, '#F5F2F4', '#E4D7DE', () => {
                this.cancelPending();
              })
              this.ActionButton(this.submitting ? '办理中...' : '确认毕业', '#FFFFFF', '#D85487', '#D85487', () => {
                this.applyStatus('graduated', '已办理毕业');
              })
            }.width('100%').margin({ top: 10 })
          }
          .width('100%')
          .margin({ top: 12 })
          .padding(12)
          .backgroundColor('#FFF0F3')
          .borderRadius(14)
          .border({ width: 1, color: '#B3FFB3CE' })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  ProfileContent() {
    if (this.detail !== null) {
      Scroll() {
        Column({ space: 12 }) {
          this.HeaderCard(this.detail!)
          this.AcademicCard(this.detail!)
          this.ContactCard(this.detail!)
          this.StatusActions(this.detail!)
          SafeBottom()
        }.width('100%')
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 12 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
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
        TopBar({ title: '学籍详情', subtitle: '学 籍 详 情', onBack: () => { AppRoute.back(); } })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (!this.hasDetail) {
          EmptyState({ title: '未找到该学生', hint: '请返回学生列表重新进入' })
        } else {
          this.ProfileContent()
        }
      }.width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}
