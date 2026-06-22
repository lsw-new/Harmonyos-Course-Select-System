// 教师端首页（roadmap #6）：工作台概览 + 我的课程入口 + 评教入口 + 退出登录。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherDashboard, TeacherCourse } from '../models/Teacher';
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

  @Builder MetricCol(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
    }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
  }

  @Builder QuickEntry(title: string, subtitle: string, route: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(subtitle).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
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
              // Hero
              Column({ space: 6 }) {
                Text(`欢迎，${this.teacherName()} 老师`)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text('在此查看授课班级、录入成绩与评教反馈')
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                this.MetricCol(`${this.dashboard ? this.dashboard.courseCount : 0}`, '授课', ElysiaTheme.ROSE_500)
                this.MetricCol(`${this.dashboard ? this.dashboard.studentCount : 0}`, '学生', '#B589FF')
                this.MetricCol(`${this.dashboard ? this.dashboard.pendingGradeCount : 0}`, '待录入', '#D9B675')
                this.MetricCol(`${this.dashboard ? this.dashboard.evalSubmitted : 0}`, '评教', '#5FB7A1')
              }.width('100%')

              // 快捷入口：课程通知 / 成绩申诉 / 评教反馈
              this.QuickEntry('我的课表', '本学期授课安排', Routes.TeacherSchedule)
              this.QuickEntry('课程通知', '给授课班级发通知', Routes.TeacherNotice)
              this.QuickEntry('成绩申诉', '受理学生成绩复核', Routes.TeacherAppeal)
              this.QuickEntry('评教反馈', '查看课程评教情况', Routes.TeacherEval)
              this.QuickEntry('个人中心', '资料 / 改密码 / 退出', Routes.TeacherProfile)

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
