// 教师端首页（roadmap #6）：工作台概览 + 我的课程入口 + 评教入口 + 退出登录。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { TeacherTabBar } from '../common/widgets/TabBars';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherDashboard, TeacherCourse, TeacherAppeal } from '../models/Teacher';
import { SessionStorage } from '../common/storage/SessionStorage';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct TeacherHomePage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State dashboard: TeacherDashboard | null = null;
  @State courses: TeacherCourse[] = [];
  @State pendingAppeals: number = 0;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherHome)) {
      return;
    }
    this.reload();
  }

  private teacherName(): string {
    const t = SessionStorage.get().getTeacher();
    return t ? t.name : '老师';
  }

  private teacherAvatar(): string {
    const t = SessionStorage.get().getTeacher();
    return t ? t.avatarUrl : '';
  }

  // 教师身份行：职称 · 学院（缺失回退）——「工作台身份头」的权威信息行。
  private teacherIdentity(): string {
    const t = SessionStorage.get().getTeacher();
    if (!t) {
      return '授课教师';
    }
    const parts: string[] = [];
    if (t.title.length > 0) {
      parts.push(t.title);
    }
    if (t.college.length > 0) {
      parts.push(t.college);
    }
    return parts.length > 0 ? parts.join(' · ') : '授课教师';
  }

  // 成绩任务状态色（结构即信息：课程行左侧细条按状态着色）。
  private statusColor(s: string): string {
    if (s === 'published') {
      return '#5FB7A1';
    }
    if (s === 'pendingAudit') {
      return ElysiaTheme.LAV_500;
    }
    if (s === 'rejected' || s === 'appealed') {
      return ElysiaTheme.ROSE_500;
    }
    return '#D9B675';
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = TeacherRepository.get();
    const dashP = repo.getDashboard();
    const coursesP = repo.getCourses();
    dashP.then((d: TeacherDashboard) => {
      this.dashboard = d;
      return coursesP;
    }).then((list: TeacherCourse[]) => {
      this.courses = list;
      this.loading = false;
      // 待处理申诉数（工作台徽标，次要信息：失败不阻断首页）
      repo.getAppeals().then((appeals: TeacherAppeal[]) => {
        this.pendingAppeals = appeals.filter((a: TeacherAppeal) => a.status === 'pending').length;
      }).catch(() => {});
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private openCourse(c: TeacherCourse): void {
    const params: Record<string, Object> = { 'courseId': c.courseId, 'courseName': c.name };
    const opts: NavigateOptions = { params: params };
    AppRoute.go(Routes.TeacherCourseDetail, opts);
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => {
      AppRoute.clearTo(Routes.Login);
    }).catch(() => {
      AppRoute.clearTo(Routes.Login);
    });
  }

  private gradeStatusLabel(s: string): string {
    if (s === 'inputting') {
      return '录入中';
    }
    if (s === 'pendingAudit') {
      return '待审核';
    }
    if (s === 'published') {
      return '已发布';
    }
    if (s === 'rejected') {
      return '被驳回';
    }
    if (s === 'appealed') {
      return '申诉中';
    }
    return s;
  }

  // 小型大写眼眉，作为结构性分节标识（教务工作台语汇）。
  @Builder SectionEyebrow(text: string) {
    Row({ space: 8 }) {
      Column().width(14).height(2).borderRadius(1).backgroundColor(ElysiaTheme.ROSE_700)
      Text(text).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).fontWeight(FontWeight.Medium).letterSpacing(1)
    }.width('100%').margin({ top: 4, bottom: 2 })
  }

  // 指标读数：中性大号数字 + 顶部细色条编码该项语义，安静克制如控制台读数。
  @Builder MetricCol(value: string, label: string, color: string) {
    Column({ space: 0 }) {
      Row().width(22).height(3).borderRadius(2).backgroundColor(color).margin({ bottom: 8 })
      Text(value)
        .fontSize(25).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 3 })
    }.layoutWeight(1).height(86).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.SURFACE).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(16)
  }

  // 工作台快捷入口：左侧图标徽片 + 标题/副标题 + 可选未处理数徽标。
  @Builder QuickEntry(icon: string, title: string, subtitle: string, route: string, badge: number) {
    Row({ space: 12 }) {
      Stack() {
        AppIcon({ name: icon, iconSize: 22 })
      }
      .width(42).height(42).borderRadius(12)
      .backgroundColor(ElysiaTheme.ROSE_50)
      .border({ width: 1, color: ElysiaTheme.hairline() })

      Column({ space: 2 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(subtitle).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      if (badge > 0) {
        Text(`${badge}`)
          .fontSize(11).fontColor(Color.White).fontWeight(FontWeight.Bold)
          .constraintSize({ minWidth: 18 }).height(18).textAlign(TextAlign.Center)
          .padding({ left: 5, right: 5 })
          .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(9)
      }
      Text('›').fontSize(18).fontColor(ElysiaTheme.ROSE_500)
    }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .onClick(() => AppRoute.go(route))
  }

  @Builder CourseRow(c: TeacherCourse) {
    Row({ space: 10 }) {
      Column()
        .width(4).height(46).borderRadius(2)
        .backgroundColor(this.statusColor(c.gradeStatus))
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(c.name)
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Pill({ text: this.gradeStatusLabel(c.gradeStatus) })
        }
        Text(`${c.code} · ${c.teachingClassName} · ${c.credit} 学分`)
          .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${c.studentCount} 名学生 · 录入进度 ${c.inputProgress}%`)
          .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .onClick(() => this.openCourse(c))
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '教师工作台', subtitle: this.teacherName(), showBack: false })

        Column() {
        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // 工作台身份头（faculty console）：眼眉 + 深玫瑰细竖条 + 头像 + 姓名/职称·学院 + 评教均分读数
              Column({ space: 0 }) {
                Text('教师工作台 · FACULTY CONSOLE')
                  .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).letterSpacing(1.5).fontWeight(FontWeight.Medium)
                Row({ space: 13 }) {
                  Column().width(3).height(48).borderRadius(2).backgroundColor(ElysiaTheme.ROSE_700)
                  if (this.teacherAvatar().length > 0) {
                    Image(this.teacherAvatar())
                      .width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover)
                      .border({ width: 1.5, color: ElysiaTheme.ROSE_200 })
                  } else {
                    Stack() {
                      Text(this.teacherName().length > 0 ? this.teacherName().charAt(0) : '师')
                        .fontSize(21).fontWeight(FontWeight.Bold).fontColor(Color.White).fontFamily(ElysiaTheme.FONT_DISPLAY)
                    }
                    .width(52).height(52).borderRadius(26)
                    .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.ROSE_700, 1]] })
                    .alignContent(Alignment.Center)
                  }
                  Column({ space: 4 }) {
                    Text(this.teacherName())
                      .fontSize(21).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.teacherIdentity())
                      .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (this.dashboard !== null && this.dashboard.evalAvg !== null) {
                    Column({ space: 1 }) {
                      Text(`${this.dashboard.evalAvg}`)
                        .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                      Text('评教均分').fontSize(9).fontColor(ElysiaTheme.INK_MUTE)
                    }.alignItems(HorizontalAlign.End)
                  }
                }.width('100%').margin({ top: 12 })
              }
              .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(20)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).alignItems(HorizontalAlign.Start)

              // 指标读数条
              Row({ space: 10 }) {
                this.MetricCol(`${this.dashboard ? this.dashboard.courseCount : 0}`, '授课', ElysiaTheme.ROSE_500)
                this.MetricCol(`${this.dashboard ? this.dashboard.studentCount : 0}`, '学生', ElysiaTheme.LAV_500)
                this.MetricCol(`${this.dashboard ? this.dashboard.pendingGradeCount : 0}`, '待录入', '#D9B675')
                this.MetricCol(`${this.dashboard ? this.dashboard.evalSubmitted : 0}`, '评教', '#5FB7A1')
              }.width('100%')

              // 待办：成绩申诉（带待处理徽标；其余功能已进底部导航）
              this.SectionEyebrow('待办事项')
              this.QuickEntry('feedback', '成绩申诉', '受理学生成绩复核', Routes.TeacherAppeal, this.pendingAppeals)

              // 我的课程（工作队列）
              this.SectionEyebrow(`我的课程 · ${this.courses.length}`)
              if (this.courses.length === 0) {
                EmptyState({ title: '暂无授课课程' })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.courses, (item: TeacherCourse) => {
                    this.CourseRow(item)
                  }, (item: TeacherCourse) => item.courseId + '-' + item.taskId)
                }.width('100%')
              }
            }.padding({ left: 16, right: 16, top: 4, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
        }.width('100%').layoutWeight(1)

        TeacherTabBar({
          active: 'home',
          onTap: (id: string, route: string) => {
            if (id !== 'home') {
              AppRoute.go(route, { replace: true });
            }
          }
        })
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TeacherHomePageBuilder() {
  NavDestination() {
    TeacherHomePage()
  }
  .hideTitleBar(true)
}
