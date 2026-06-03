// 课程详情 · Course Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, Pill, GlowCard, GhostButton } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { Course } from '../models/Course';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct CourseDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State course: Course | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.CourseDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少课程 ID';
      this.loading = false;
      return;
    }
    CourseRepository.get().getCourseDetail(id).then((c: Course) => {
      this.course = c;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
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
        TopBar({ title: '课程详情', subtitle: '课 程 详 情', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.course !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero
              Column() {
                Pill({ text: `${this.course!.category} · ${this.course!.credit} 学分` })
                Text(this.course!.name)
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                  .margin({ top: 10 })
                Text(`${this.course!.code} · ${this.course!.teacher} · ${this.course!.classroom}`)
                  .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(22)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })

              // 基本信息
              Column() {
                Text('基本信息').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('课程代码', this.course!.code)
                this.InfoRow('教学班号', this.course!.teachingClassNo)
                this.InfoRow('授课教师', this.course!.teacher)
                this.InfoRow('开课学院', this.course!.college)
                this.InfoRow('校区', this.course!.campus ?? '—')
                this.InfoRow('教室', this.course!.classroom)
                this.InfoRow('周次', this.course!.weeks)
                this.InfoRow('容量', this.course!.capacity ? `${this.course!.selectedCount ?? 0}/${this.course!.capacity}` : '—')
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 课程简介
              if (this.course!.description && this.course!.description!.length > 0) {
                Column() {
                  Text('课程简介').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 6 })
                  Text(this.course!.description!)
                    .fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 考核方式
              if (this.course!.assessment) {
                Column() {
                  Text('考核比例').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
                  Row({ space: 12 }) {
                    this.AssessBar('平时', this.course!.assessment!.usual, ElysiaTheme.ROSE_500)
                    this.AssessBar('实验', this.course!.assessment!.experiment, ElysiaTheme.LAV_500)
                    this.AssessBar('期末', this.course!.assessment!.finalDefense, ElysiaTheme.GOLD_500)
                  }.width('100%')
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 操作
              Row({ space: 12 }) {
                GhostButton({ text: '进入评教', onTap: () => AppRoute.go(Routes.Eval) })
              }.width('100%')

              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }

  @Builder AssessBar(label: string, percent: number, color: string) {
    Column() {
      Column()
        .width(36).height(Math.max(percent * 1.2, 4))
        .backgroundColor(color).borderRadius(6)
      Text(`${percent}%`).fontSize(11).fontColor(ElysiaTheme.INK).margin({ top: 4 })
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
    }.alignItems(HorizontalAlign.Center).layoutWeight(1)
  }
}
