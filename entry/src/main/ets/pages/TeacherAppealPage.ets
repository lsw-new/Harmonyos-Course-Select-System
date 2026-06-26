// 教师端·成绩申诉处理（roadmap #6 增强）：列出本课程申诉，受理/驳回并回复。
// 三端闭环：学生申诉 → 教师处理 → 学生消息回执 + 管理端可见。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherAppeal } from '../models/Teacher';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

interface AppealRow {
  appealId: string;
  studentName: string;
  studentId: string;
  courseName: string;
  reason: string;
  status: string;
  reply: string;
  replyInput: string;
  submittedAt: string;
}

@Component
struct TeacherAppealPage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State rows: AppealRow[] = [];
  @State filter: string = 'pending';
  @State isRefreshing: boolean = false;
  @StorageProp('breakpoint') bp: string = 'sm';

  private pendingCount(): number {
    return this.rows.filter((r: AppealRow) => r.status === 'pending').length;
  }

  private handledCount(): number {
    return this.rows.filter((r: AppealRow) => r.status !== 'pending').length;
  }

  // 待处理优先：三态筛选；列表内待处理排在前。
  private visibleRows(): AppealRow[] {
    let list: AppealRow[];
    if (this.filter === 'pending') {
      list = this.rows.filter((r: AppealRow) => r.status === 'pending');
    } else if (this.filter === 'handled') {
      list = this.rows.filter((r: AppealRow) => r.status !== 'pending');
    } else {
      list = this.rows.slice();
    }
    return list.sort((a: AppealRow, b: AppealRow) => {
      const pa = a.status === 'pending' ? 0 : 1;
      const pb = b.status === 'pending' ? 0 : 1;
      return pa - pb;
    });
  }

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherAppeal)) {
      return;
    }
    this.reload();
  }

  // isRefresh=true：下拉刷新，不切整页 loading（保留当前内容），完成后复位指示器。
  private reload(isRefresh: boolean = false): void {
    if (!isRefresh) {
      this.loading = true;
      this.errorMsg = '';
    }
    TeacherRepository.get().getAppeals().then((list: TeacherAppeal[]) => {
      this.rows = list.map((a: TeacherAppeal): AppealRow => ({
        appealId: a.appealId,
        studentName: a.studentName.length > 0 ? a.studentName : a.studentId,
        studentId: a.studentId,
        courseName: a.courseName,
        reason: a.reason,
        status: a.status,
        reply: a.reply,
        replyInput: '',
        submittedAt: a.submittedAt
      }));
      this.loading = false;
      this.isRefreshing = false;
    }).catch((e: object) => {
      this.isRefreshing = false;
      if (!isRefresh) {
        this.loading = false;
        this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      }
    });
  }

  private updateReply(appealId: string, value: string): void {
    this.rows = this.rows.map((r: AppealRow): AppealRow => {
      if (r.appealId !== appealId) {
        return r;
      }
      return {
        appealId: r.appealId, studentName: r.studentName, studentId: r.studentId,
        courseName: r.courseName, reason: r.reason, status: r.status, reply: r.reply,
        replyInput: value, submittedAt: r.submittedAt
      };
    });
  }

  private handle(row: AppealRow, decision: string): void {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    TeacherRepository.get().handleAppeal(row.appealId, decision, row.replyInput.trim()).then((status: string) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), status === 'accepted' ? '已受理并通知学生' : '已驳回并通知学生');
      this.reload();
    }).catch((e: object) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '处理失败');
    });
  }

  private statusLabel(s: string): string {
    if (s === 'pending') {
      return '待处理';
    }
    if (s === 'accepted') {
      return '已受理';
    }
    if (s === 'rejected') {
      return '已驳回';
    }
    return s;
  }

  @Builder FilterChip(value: string, label: string) {
    Text(label)
      .fontSize(13).fontColor(this.filter === value ? Color.White : ElysiaTheme.INK)
      .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
      .backgroundColor(this.filter === value ? ElysiaTheme.ROSE_500 : ElysiaTheme.glass())
      .border({ width: 1, color: this.filter === value ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
      .borderRadius(12)
      .onClick(() => { this.filter = value; })
  }

  @Builder AppealCard(r: AppealRow) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(`${r.studentName} · ${r.courseName}`)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Pill({ text: this.statusLabel(r.status) })
      }
      Text(`申诉理由：${r.reason}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (r.status === 'pending') {
        TextInput({ text: r.replyInput, placeholder: '回复意见（可选）' })
          .fontSize(13).height(40).backgroundColor(ElysiaTheme.glass())
          .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(10)
          .onChange((v: string) => this.updateReply(r.appealId, v))
        Row({ space: 10 }) {
          Text('驳回')
            .fontSize(13).fontColor(ElysiaTheme.ROSE_500).fontWeight(FontWeight.Medium)
            .layoutWeight(1).textAlign(TextAlign.Center).padding(10)
            .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
            .onClick(() => this.handle(r, 'rejected'))
          Text('受理')
            .fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Medium)
            .layoutWeight(1).textAlign(TextAlign.Center).padding(10)
            .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
            .borderRadius(12)
            .onClick(() => this.handle(r, 'accepted'))
        }.width('100%')
      } else if (r.reply.length > 0) {
        Text(`处理回复：${r.reply}`).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (r.submittedAt.length > 0) {
        Text(`申诉时间：${r.submittedAt}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%').linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '成绩申诉', subtitle: '受理/驳回并回复学生', onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
          Scroll() {
            Column({ space: 12 }) {
              // 筛选切换：待处理（带计数）/ 已处理（带计数）/ 全部
              Row({ space: 8 }) {
                this.FilterChip('pending', `待处理${this.pendingCount() > 0 ? ' ' + this.pendingCount() : ''}`)
                this.FilterChip('handled', `已处理${this.handledCount() > 0 ? ' ' + this.handledCount() : ''}`)
                this.FilterChip('all', `全部 ${this.rows.length}`)
              }.width('100%')

              if (this.rows.length === 0) {
                EmptyState({ title: '暂无成绩申诉' })
              } else if (this.visibleRows().length === 0) {
                EmptyState({ title: '没有待处理的申诉' })
              } else {
                ForEach(this.visibleRows(), (item: AppealRow) => {
                  this.AppealCard(item)
                }, (item: AppealRow) => item.appealId)
              }
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
          }.scrollBar(BarState.Off).width('100%').height('100%')
          }
          .onRefreshing(() => { this.reload(true); })
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TeacherAppealPageBuilder() {
  NavDestination() {
    TeacherAppealPage()
  }
  .hideTitleBar(true)
}
