// 教师端评教结果（roadmap #6）：按课程聚合评教任务数 / 已提交数 / 提交率。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherEval } from '../models/Teacher';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct TeacherEvalPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State items: TeacherEval[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherEval)) {
      return;
    }
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    TeacherRepository.get().getEvaluations().then((list: TeacherEval[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private rate(e: TeacherEval): string {
    if (e.taskCount <= 0) {
      return '0%';
    }
    return `${Math.round((e.submittedCount / e.taskCount) * 100)}%`;
  }

  @Builder EvalRow(e: TeacherEval) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(e.courseName.length > 0 ? e.courseName : e.courseId)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Pill({ text: e.term })
      }
      Row({ space: 16 }) {
        Column({ space: 2 }) {
          Text(`${e.submittedCount}/${e.taskCount}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
          Text('已提交/总数').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(this.rate(e)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#5FB7A1')
          Text('提交率').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(e.avgScore !== null ? `${e.avgScore}` : '—').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#B589FF')
          Text('评分均值').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
      }.width('100%')
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '评教反馈', subtitle: '按课程查看提交情况', onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              if (this.items.length === 0) {
                EmptyState({ title: '暂无评教数据' })
              } else {
                ForEach(this.items, (item: TeacherEval) => {
                  this.EvalRow(item)
                }, (item: TeacherEval) => item.courseId + '-' + item.term)
              }
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
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
export function TeacherEvalPageBuilder() {
  NavDestination() {
    TeacherEvalPage()
  }
  .hideTitleBar(true)
}
