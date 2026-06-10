// 成绩详情 · Grade Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { GradeRecord } from '../models/Academic';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct GradeDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State grade: GradeRecord | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.GradeDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少成绩 ID';
      this.loading = false;
      return;
    }
    AcademicRepository.get().getGrades().then((records: GradeRecord[]) => {
      const found: GradeRecord | undefined = records.find((r: GradeRecord) => r.id === id);
      if (found === undefined) {
        this.errorMsg = '成绩不存在';
      } else {
        this.grade = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(84)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder MetricCard(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontStyle(FontStyle.Italic)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label)
        .fontSize(10)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .height(70)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() })
    .borderRadius(18)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.gradedetail_title'), subtitle: $r('app.string.gradedetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.grade !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 渐变卡
              Column({ space: 10 }) {
                Pill({ text: `${this.grade!.courseCategory} · ${this.grade!.credit} 学分` })
                Text(this.grade!.courseName)
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.INK)
                  .lineHeight(26)
                Text(`最终成绩 ${this.grade!.finalScore ?? this.grade!.totalScore ?? '—'}`)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(18)
              .borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡（总分 / 绩点 / 学分）——使用模型真实字段
              Row({ space: 10 }) {
                this.MetricCard('总分', `${this.grade!.totalScore ?? this.grade!.finalScore ?? '—'}`, ElysiaTheme.ROSE_500)
                this.MetricCard('绩点', `${this.grade!.gradePoint ?? '—'}`, ElysiaTheme.LAV_500)
                this.MetricCard('学分', `${this.grade!.credit}`, ElysiaTheme.GOLD_500)
              }.width('100%')

              // 信息卡
              Column() {
                Text($r('app.string.gradedetail_section_info'))
                  .fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('课程代码', this.grade!.courseCode)
                this.InfoRow('教学班', this.grade!.teachingClassNo)
                this.InfoRow('类别', this.grade!.courseCategory)
                this.InfoRow('学期', this.grade!.term)
                this.InfoRow('状态', this.grade!.status ?? '—')
                this.InfoRow('发布时间', this.grade!.publishedAt ?? '—')
                // midtermScore / finalExamScore 模型字段存在，有值则显示，否则显示 —
                this.InfoRow('期中成绩', `${this.grade!.midtermScore ?? '—'}`)
                this.InfoRow('期末成绩', `${this.grade!.finalExamScore ?? '—'}`)
                if (this.grade!.rank !== undefined) {
                  this.InfoRow('班级排名', `${this.grade!.rank!}`)
                }
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.gradedetail_btn_back'), onTap: () => AppRoute.back() })
                PrimaryButton({
                  text: $r('app.string.gradedetail_btn_appeal'),
                  onTap: () => { const p: Record<string, Object> = { 'id': this.grade!.id }; AppRoute.go(Routes.GradeAppeal, { params: p }); }
                })
              }.width('100%')

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function GradeDetailPageBuilder() {
  NavDestination() {
    GradeDetailPage()
  }
  .hideTitleBar(true)
}
