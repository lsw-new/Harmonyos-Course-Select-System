// 教师端评教结果（roadmap #6）：按课程聚合评教任务数 / 已提交数 / 提交率。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherEval, TeacherEvalBreakdown } from '../models/Teacher';
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
  // 展开中的课程（空串=全部折叠）+ 已加载的按题细分缓存（按 courseId）
  @State expandedCourseId: string = '';
  @State breakdowns: Map<string, TeacherEvalBreakdown[]> = new Map();
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

  private rateValue(e: TeacherEval): number {
    if (e.taskCount <= 0) {
      return 0;
    }
    return Math.min(100, Math.round((e.submittedCount / e.taskCount) * 100));
  }

  // 总览：跨课程汇总提交与均分（均分仅对有评分的课程取平均）。
  private totalTasks(): number {
    let n = 0;
    this.items.forEach((e: TeacherEval) => { n += e.taskCount; });
    return n;
  }

  private totalSubmitted(): number {
    let n = 0;
    this.items.forEach((e: TeacherEval) => { n += e.submittedCount; });
    return n;
  }

  private overallRate(): number {
    const t = this.totalTasks();
    return t > 0 ? Math.min(100, Math.round((this.totalSubmitted() / t) * 100)) : 0;
  }

  private rateColor(v: number): string {
    if (v >= 80) {
      return '#5FB7A1';
    }
    if (v >= 50) {
      return '#D9B675';
    }
    return ElysiaTheme.ROSE_500;
  }

  private sortedItems(): TeacherEval[] {
    return this.items.slice().sort((a: TeacherEval, b: TeacherEval) => this.rateValue(a) - this.rateValue(b));
  }

  private lowestItem(): TeacherEval | null {
    if (this.items.length === 0) {
      return null;
    }
    let lowest: TeacherEval = this.items[0];
    this.items.forEach((e: TeacherEval) => {
      if (this.rateValue(e) < this.rateValue(lowest)) {
        lowest = e;
      }
    });
    return lowest;
  }

  private overallAvg(): number | null {
    let sum = 0;
    let n = 0;
    this.items.forEach((e: TeacherEval) => {
      if (e.avgScore !== null) {
        sum += e.avgScore;
        n += 1;
      }
    });
    return n > 0 ? Math.round((sum / n) * 10) / 10 : null;
  }

  // 展开/折叠某课程的按题细分；首次展开且未缓存则拉取后整体替换 Record（不可变更新）。
  private toggleExpand(courseId: string): void {
    if (this.expandedCourseId === courseId) {
      this.expandedCourseId = '';
      return;
    }
    this.expandedCourseId = courseId;
    if (this.breakdowns.has(courseId)) {
      return;
    }
    TeacherRepository.get().getEvalBreakdown(courseId).then((list: TeacherEvalBreakdown[]) => {
      this.breakdowns = this.withBreakdown(courseId, list);
    }).catch(() => {
      this.breakdowns = this.withBreakdown(courseId, []);
    });
  }

  // 不可变更新：基于现有缓存整体复制并写入该课程的细分。
  private withBreakdown(courseId: string, list: TeacherEvalBreakdown[]): Map<string, TeacherEvalBreakdown[]> {
    const next: Map<string, TeacherEvalBreakdown[]> = new Map(this.breakdowns);
    next.set(courseId, list);
    return next;
  }

  private breakdownOf(courseId: string): TeacherEvalBreakdown[] {
    const list = this.breakdowns.get(courseId);
    return list !== undefined ? list : [];
  }

  // 每题进度条占比：avg/5*100，截顶到 [0,100]。
  private barPercent(avg: number | null): number {
    if (avg === null) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round((avg / 5) * 100)));
  }

  private avgLabel(avg: number | null): string {
    return avg !== null ? `${avg}` : '—';
  }

  @Builder BreakdownRow(b: TeacherEvalBreakdown) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(b.title).fontSize(12).fontColor(ElysiaTheme.INK).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.avgLabel(b.avg)).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#B589FF')
      }.width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).backgroundColor(ElysiaTheme.hairline()).borderRadius(3)
        Row().width(`${this.barPercent(b.avg)}%`).height(5).borderRadius(3).backgroundColor('#B589FF')
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder BreakdownPanel(courseId: string) {
    Column({ space: 10 }) {
      Text('按题目细分').fontSize(12).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK_SOFT).width('100%')
      if (this.breakdownOf(courseId).length === 0) {
        Text('暂无评分题数据').fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width('100%')
      } else {
        ForEach(this.breakdownOf(courseId), (b: TeacherEvalBreakdown) => {
          this.BreakdownRow(b)
        }, (b: TeacherEvalBreakdown) => b.questionId)
      }
    }
    .width('100%').padding(12).margin({ top: 8 })
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder SummaryCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text(`${this.totalSubmitted()}/${this.totalTasks()}`).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
          Text('总提交').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(`${this.overallRate()}%`).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor('#5FB7A1').fontFamily(ElysiaTheme.FONT_DISPLAY)
          Text('总提交率').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(this.overallAvg() !== null ? `${this.overallAvg()}` : '—').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor('#B589FF').fontFamily(ElysiaTheme.FONT_DISPLAY)
          Text('总评分均值').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
      }.width('100%')
      if (this.lowestItem() !== null && this.rateValue(this.lowestItem() as TeacherEval) < 100) {
        Text(`最需关注：${(this.lowestItem() as TeacherEval).courseName.length > 0 ? (this.lowestItem() as TeacherEval).courseName : (this.lowestItem() as TeacherEval).courseId}  提交率 ${this.rateValue(this.lowestItem() as TeacherEval)}%`)
          .fontSize(11).fontColor(ElysiaTheme.ROSE_500).width('100%').textAlign(TextAlign.Center)
      }
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
  }

  @Builder EvalRow(e: TeacherEval) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(e.courseName.length > 0 ? e.courseName : e.courseId)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.expandedCourseId === e.courseId ? '收起' : '按题目').fontSize(11).fontColor(ElysiaTheme.LAV_500)
        Pill({ text: e.term })
      }
      Row({ space: 16 }) {
        Column({ space: 2 }) {
          Text(`${e.submittedCount}/${e.taskCount}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
          Text('已提交/总数').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(this.rate(e)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.rateColor(this.rateValue(e)))
          Text('提交率').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(e.avgScore !== null ? `${e.avgScore}` : '—').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#B589FF')
          Text('评分均值').fontSize(10).fontColor(ElysiaTheme.INK_SOFT)
        }.alignItems(HorizontalAlign.Start)
      }.width('100%')
      // 提交率进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(6).backgroundColor(ElysiaTheme.hairline()).borderRadius(3)
        Row().width(`${this.rateValue(e)}%`).height(6).borderRadius(3)
          .backgroundColor(this.rateColor(this.rateValue(e)))
      }.width('100%')
      // 展开时显示按题目细分面板
      if (this.expandedCourseId === e.courseId) {
        this.BreakdownPanel(e.courseId)
      }
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18).alignItems(HorizontalAlign.Start)
    .onClick(() => { this.toggleExpand(e.courseId); })
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
                this.SummaryCard()
                ForEach(this.sortedItems(), (item: TeacherEval) => {
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
