// 我的成绩 · Grades
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, Pill } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { StudentTabBar } from '../common/widgets/TabBars';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { GradeRecord, GradeSummary } from '../models/Academic';

@Component
struct GradesPage {
  @State activeTerm: number = 0;
  @State grades: GradeRecord[] = [];
  @State summary?: GradeSummary = undefined;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  // '全部' must come first; remaining terms are the EXACT strings in mockGrades
  private terms: string[] = ['全部', '2025-2026-1', '2025-2026-2'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Grades)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const term: string | undefined = this.activeTerm === 0 ? undefined : this.terms[this.activeTerm];
    const repo = AcademicRepository.get();
    Promise.all([repo.getGrades(term), repo.getGradeSummary(term)])
      .then((res: [GradeRecord[], GradeSummary]) => {
        this.grades = res[0];
        this.summary = res[1];
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.grades_title'), subtitle: $r('app.string.grades_subtitle'), showBack: false })

        // 学期切换 tabs
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.terms, (t: string, i?: number) => {
              Button(t)
                .height(28)
                .padding({ left: 14, right: 14 })
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(i === this.activeTerm ? Color.White : ElysiaTheme.ROSE_700)
                .backgroundColor(i === this.activeTerm ? '' : ElysiaTheme.glass())
                .linearGradient(i === this.activeTerm ? {
                  angle: 135,
                  colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                .borderRadius(999)
                .border({ width: i === this.activeTerm ? 0 : 1, color: ElysiaTheme.hairline() })
                .onClick(() => {
                  this.activeTerm = i ?? 0;
                  this.loadData();
                })
            }, (t: string) => t)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, bottom: 12 })

        if (this.loading) {
          Column() { LoadingState({ tip: $r('app.string.grades_loading') }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              // 统计卡片
              if (this.summary !== undefined) {
                Column() {
                  Text(`${this.summary!.term}`)
                    .fontSize(10)
                    .fontColor(ElysiaTheme.ROSE_700)
                    .letterSpacing(4)
                  Row() {
                    Text(`${this.summary!.termGpa}`)
                      .fontSize(42)
                      .fontStyle(FontStyle.Italic)
                      .fontColor(ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                    Text($r('app.string.grades_term_gpa'))
                      .fontSize(11)
                      .fontColor(ElysiaTheme.INK_SOFT)
                  }
                  .alignItems(VerticalAlign.Bottom)
                  .margin({ top: 4 })

                  Row({ space: 8 }) {
                    this.StatPill('已修学分', `${this.summary!.earnedCredits}`)
                    this.StatPill('加权平均', `${this.summary!.weightedAverage}`)
                    this.StatPill('累计 GPA', `${this.summary!.totalGpa}`)
                  }
                  .width('100%')
                  .margin({ top: 14 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(18)
                .borderRadius(24)
                .linearGradient({
                  angle: 135,
                  colors: [['#FFE4EE', 0], ['#F1E2FF', 0.5], ['#FFF1D6', 1]]
                })
                .margin({ left: 16, right: 16 })
              }

              RoseDivider({ label: `records · ${this.grades.length} 门` })

              if (this.grades.length === 0) {
                EmptyState({ title: $r('app.string.grades_empty') })
              } else {
                // 成绩列表
                Column({ space: 10 }) {
                  ForEach(this.grades, (g: GradeRecord) => {
                    this.GradeCard(g)
                  }, (g: GradeRecord) => g.id)
                }
                .padding({ left: 16, right: 16 })
              }

              Text($r('app.string.grades_slogan'))
                .fontSize(11)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.INK_MUTE)
                .letterSpacing(4)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
                .margin({ top: 16, bottom: 30 })
              SafeBottom()
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }

        StudentTabBar({
          active: 'grades',
          onTap: (id: string, route: string) => {
            if (id !== 'grades') AppRoute.go(route, { replace: true });
          }
        })
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }

  @Builder StatPill(k: string, v: string) {
    Column() {
      Text(v)
        .fontSize(18)
        .fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(k)
        .fontSize(9)
        .fontColor(ElysiaTheme.INK_SOFT)
        .letterSpacing(2)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor(ElysiaTheme.glassSoft())
  }

  @Builder GradeCard(g: GradeRecord) {
    Column() {
      Row() {
        Column() {
          Text(g.courseName)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(ElysiaTheme.INK)
          Text(g.courseCode)
            .fontSize(10)
            .fontStyle(FontStyle.Italic)
            .fontColor(ElysiaTheme.INK_MUTE)
            .fontFamily(ElysiaTheme.FONT_DISPLAY)
            .margin({ top: 2 })
          Row({ space: 6 }) {
            Pill({ text: g.courseCategory })
            Pill({
              text: `${g.credit} 学分`,
              bg: '#FBE6C2', color: ElysiaTheme.GOLD_700
            })
          }
          .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text(`${g.totalScore ?? g.finalScore ?? '—'}`)
            .fontSize(30)
            .fontStyle(FontStyle.Italic)
            .fontColor(
              (typeof g.totalScore === 'number' && g.totalScore >= 90) ||
              (g.finalScore !== undefined && typeof g.finalScore === 'number' && g.finalScore >= 90)
                ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_SOFT
            )
            .fontFamily(ElysiaTheme.FONT_DISPLAY)
          Text($r('app.string.grades_final'))
            .fontSize(10)
            .fontColor(ElysiaTheme.INK_SOFT)
            .letterSpacing(2)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Divider()
        .strokeWidth(1)
        .color(ElysiaTheme.hairline())
        .margin({ top: 10, bottom: 10 })

      Row() {
        this.Mini('期中', `${g.midtermScore ?? '—'}`)
        this.Mini('期末', `${g.finalExamScore ?? '—'}`)
        this.Mini('绩点', `${g.gradePoint ?? '—'}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(22)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .shadow({ radius: 16, color: '#1FD85487', offsetX: 0, offsetY: 4 })
    .onClick(() => { const p: Record<string, Object> = { 'id': g.id }; AppRoute.go(Routes.GradeDetail, { params: p }); })
  }

  @Builder Mini(k: string, v: string) {
    Column() {
      Text(v)
        .fontSize(13)
        .fontStyle(FontStyle.Italic)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
        .fontColor(ElysiaTheme.INK)
        .fontWeight(FontWeight.Medium)
      Text(k)
        .fontSize(9)
        .fontColor(ElysiaTheme.INK_SOFT)
        .letterSpacing(2)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}

// 系统路由表构建函数
@Builder
export function GradesPageBuilder() {
  NavDestination() {
    GradesPage()
  }
  .hideTitleBar(true)
}
