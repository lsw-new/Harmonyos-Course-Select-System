// 教师端首页（roadmap #6）：工作台概览 + 我的课程入口 + 评教入口 + 退出登录。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
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

  @Builder MetricCol(icon: string, value: string, label: string, color: string) {
    Column({ space: 2 }) {
      AppIcon({ name: icon, iconSize: 16 })
      Text(value)
        .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
    }.layoutWeight(1).height(82).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
  }

  // 工作台快捷入口：左侧图标徽片 + 标题/副标题 + 可选未处理数徽标。
  @Builder QuickEntry(icon: string, title: string, subtitle: string, route: string, badge: number) {
    Row({ space: 12 }) {
      Stack() {
        AppIcon({ name: icon, iconSize: 24 })
      }
      .width(46).height(46).borderRadius(15)
      .linearGradient({ angle: 135, colors: [[Color.White, 0], [ElysiaTheme.ROSE_100, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairline() })
      .shadow({ radius: 8, color: '#33F2709C', offsetX: 0, offsetY: 3 })

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
        .width(10).height(46).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
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
        TopBar({ title: '教师工作台', subtitle: this.teacherName() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // Hero（头像 + 欢迎语）
              Row({ space: 14 }) {
                if (this.teacherAvatar().length > 0) {
                  Image(this.teacherAvatar())
                    .width(56).height(56).borderRadius(28)
                    .objectFit(ImageFit.Cover)
                    .border({ width: 2, color: Color.White })
                } else {
                  Stack() {
                    Text(this.teacherName().length > 0 ? this.teacherName().charAt(0) : '师')
                      .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }
                  .width(56).height(56).borderRadius(28)
                  .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_500, 1]] })
                  .alignContent(Alignment.Center)
                }
                Column({ space: 6 }) {
                  Text(`欢迎，${this.teacherName()} 老师`)
                    .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                  Text('在此查看授课班级、录入成绩与评教反馈')
                    .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                this.MetricCol('course', `${this.dashboard ? this.dashboard.courseCount : 0}`, '授课', ElysiaTheme.ROSE_500)
                this.MetricCol('students', `${this.dashboard ? this.dashboard.studentCount : 0}`, '学生', '#B589FF')
                this.MetricCol('grades', `${this.dashboard ? this.dashboard.pendingGradeCount : 0}`, '待录入', '#D9B675')
                this.MetricCol('evaluation', `${this.dashboard ? this.dashboard.evalSubmitted : 0}`, '评教', '#5FB7A1')
              }.width('100%')

              // 快捷入口：课表 / 通知 / 申诉（带待办徽标）/ 评教 / 个人中心
              this.QuickEntry('schedule', '我的课表', '本学期授课安排', Routes.TeacherSchedule, 0)
              this.QuickEntry('notice', '课程通知', '给授课班级发通知', Routes.TeacherNotice, 0)
              this.QuickEntry('feedback', '成绩申诉', '受理学生成绩复核', Routes.TeacherAppeal, this.pendingAppeals)
              this.QuickEntry('evaluation', '评教反馈', '查看课程评教情况', Routes.TeacherEval, 0)
              this.QuickEntry('mine', '个人中心', '资料 / 改密码 / 退出', Routes.TeacherProfile, 0)

              // 我的课程
              Text('我的课程').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                .width('100%').margin({ top: 4 })
              if (this.courses.length === 0) {
                EmptyState({ title: '暂无授课课程' })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.courses, (item: TeacherCourse) => {
                    this.CourseRow(item)
                  }, (item: TeacherCourse) => item.courseId + '-' + item.taskId)
                }.width('100%')
              }

              // 退出登录
              Text('退出登录')
                .fontSize(14).fontColor(ElysiaTheme.ROSE_500).fontWeight(FontWeight.Medium)
                .width('100%').textAlign(TextAlign.Center).padding(14).margin({ top: 6 })
                .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
                .onClick(() => this.logout())

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
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
