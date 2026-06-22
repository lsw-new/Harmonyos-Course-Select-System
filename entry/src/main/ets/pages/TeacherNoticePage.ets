// 教师端·课程通知（roadmap #6 增强）：选课程 → 发通知（落库 + 给本班学生发消息）→ 我的发布列表。
// 三端闭环：教师发 → 学生通知列表/消息中心 → 管理端通知管理可见。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton } from '../common/Components';
import { TeacherRepository, TeacherNoticeResult } from '../repositories/TeacherRepository';
import { TeacherCourse, TeacherNotice } from '../models/Teacher';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct TeacherNoticePage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State courses: TeacherCourse[] = [];
  @State notices: TeacherNotice[] = [];
  @State selectedCourseId: string = '';
  @State title: string = '';
  @State content: string = '';
  @State urgency: string = 'normal';
  @StorageProp('breakpoint') bp: string = 'sm';

  private urgencyLabel(u: string): string {
    if (u === 'important') {
      return '重要';
    }
    if (u === 'urgent') {
      return '紧急';
    }
    return '普通';
  }

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherNotice)) {
      return;
    }
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = TeacherRepository.get();
    const cP = repo.getCourses();
    const nP = repo.getNotices();
    cP.then((cs: TeacherCourse[]) => {
      this.courses = cs;
      if (this.selectedCourseId.length === 0 && cs.length > 0) {
        this.selectedCourseId = cs[0].courseId;
      }
      return nP;
    }).then((ns: TeacherNotice[]) => {
      this.notices = ns;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private publish(): void {
    if (this.submitting) {
      return;
    }
    if (this.selectedCourseId.length === 0) {
      Toast.show(this.getUIContext(), '请先选择课程');
      return;
    }
    if (this.title.trim().length === 0 || this.content.trim().length === 0) {
      Toast.show(this.getUIContext(), '请填写标题和正文');
      return;
    }
    this.submitting = true;
    TeacherRepository.get().publishNotice(this.selectedCourseId, this.title.trim(), this.content.trim(), this.urgency).then((r: TeacherNoticeResult) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), `已发布，送达 ${r.recipients} 名学生`);
      this.title = '';
      this.content = '';
      this.urgency = 'normal';
      this.reload();
    }).catch((e: object) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '发布失败');
    });
  }

  @Builder CourseChip(c: TeacherCourse) {
    Text(c.name)
      .fontSize(13).fontColor(this.selectedCourseId === c.courseId ? Color.White : ElysiaTheme.INK)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.selectedCourseId === c.courseId ? ElysiaTheme.ROSE_500 : ElysiaTheme.glass())
      .border({ width: 1, color: this.selectedCourseId === c.courseId ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
      .borderRadius(20)
      .onClick(() => { this.selectedCourseId = c.courseId; })
  }

  @Builder UrgencyChip(value: string) {
    Text(this.urgencyLabel(value))
      .fontSize(13).fontColor(this.urgency === value ? Color.White : ElysiaTheme.INK)
      .layoutWeight(1).textAlign(TextAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(this.urgency === value ? ElysiaTheme.ROSE_500 : ElysiaTheme.glass())
      .border({ width: 1, color: this.urgency === value ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
      .borderRadius(12)
      .onClick(() => { this.urgency = value; })
  }

  @Builder NoticeRow(n: TeacherNotice) {
    Row({ space: 10 }) {
      // 左侧紧急程度颜色条
      Column()
        .width(4).height(44).borderRadius(2)
        .backgroundColor(n.urgency === 'urgent' ? ElysiaTheme.ROSE_500 : (n.urgency === 'important' ? '#D9B675' : ElysiaTheme.hairline()))
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(n.title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (n.urgency === 'important' || n.urgency === 'urgent') {
            Text(this.urgencyLabel(n.urgency))
              .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(n.urgency === 'urgent' ? ElysiaTheme.ROSE_500 : '#D9B675').borderRadius(8)
          }
          Pill({ text: n.category })
        }
        Text(n.summary).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(n.publishedAt).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%').linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '课程通知', subtitle: '发布给授课班级', onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              // 发布表单
              Column({ space: 10 }) {
                Text('选择课程').fontSize(13).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).width('100%')
                if (this.courses.length === 0) {
                  Text('暂无授课课程').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width('100%')
                } else {
                  Scroll() {
                    Row({ space: 8 }) {
                      ForEach(this.courses, (c: TeacherCourse) => {
                        this.CourseChip(c)
                      }, (c: TeacherCourse) => c.courseId)
                    }
                  }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
                }
                TextInput({ text: this.title, placeholder: '通知标题' })
                  .fontSize(14).height(44).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
                  .onChange((v: string) => { this.title = v; })
                Text(`${this.title.length}/100`)
                  .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).width('100%').textAlign(TextAlign.End)
                Text('紧急程度').fontSize(13).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).width('100%')
                Row({ space: 8 }) {
                  this.UrgencyChip('normal')
                  this.UrgencyChip('important')
                  this.UrgencyChip('urgent')
                }.width('100%')
                Text('重要/紧急通知将在学生端强制弹窗提醒')
                  .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width('100%')
                TextArea({ text: this.content, placeholder: '通知正文…' })
                  .fontSize(14).height(110).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
                  .onChange((v: string) => { this.content = v; })
                Text(`${this.content.length}/2000`)
                  .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).width('100%').textAlign(TextAlign.End)
                PrimaryButton({ text: this.submitting ? '发布中…' : '发布通知', onTap: () => this.publish() })
              }
              .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)

              // 我的发布
              Text('我发布的通知').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%').margin({ top: 4 })
              if (this.notices.length === 0) {
                EmptyState({ title: '还没有发布过通知' })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.notices, (item: TeacherNotice) => {
                    this.NoticeRow(item)
                  }, (item: TeacherNotice) => item.noticeId)
                }.width('100%')
              }
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TeacherNoticePageBuilder() {
  NavDestination() {
    TeacherNoticePage()
  }
  .hideTitleBar(true)
}
