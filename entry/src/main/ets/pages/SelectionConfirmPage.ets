// 选课确认 · Selection Confirm
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { Course } from '../models/Course';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct SelectionConfirmPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State course: Course | null = null;
  @State submitting: boolean = false;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.SelectionConfirm)) {
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

  private doSelect(): void {
    if (this.submitting || this.course === null) {
      return;
    }
    this.submitting = true;
    const noSchedule: boolean = this.course!.weekday < 1;
    CourseRepository.get().selectCourse(this.course!.id).then(() => {
      this.submitting = false;
      // 集中实践类课程无固定排课，不会出现在课表网格中，明确告知避免误以为选课未生效
      Toast.show(this.getUIContext(), noSchedule ? '选课成功（集中实践类课程无固定排课，不在课表中显示）' : '选课成功，已加入我的课表');
      // 通知选课中心重新拉取，保证返回后已选学分/按钮状态同步
      AppStorage.setOrCreate('selection.refreshTick', Date.now());
      AppRoute.back();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : (e instanceof Error ? e.message : '选课失败');
      Toast.show(this.getUIContext(), msg);
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.selconfirm_title'), subtitle: $r('app.string.selconfirm_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.course !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero：课程名称卡
              Column({ space: 10 }) {
                Pill({ text: `${this.course!.category} · ${this.course!.credit} 学分` })
                Text(`${this.course!.name} · ${this.course!.code}`)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                  .lineHeight(26)
                Text(`${this.course!.teacher} · ${this.course!.college}`)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡：容量 / 学分 / 教室
              Row({ space: 10 }) {
                this.MetricCard(
                  this.course!.capacity !== undefined
                    ? `${this.course!.selectedCount ?? 0}/${this.course!.capacity}`
                    : '—',
                  '容量',
                  ElysiaTheme.ROSE_500
                )
                this.MetricCard(`${this.course!.credit}`, '学分', ElysiaTheme.GOLD_700)
                this.MetricCard(this.course!.weeks.length > 0 ? this.course!.weeks : '—', '周次', ElysiaTheme.LAV_500)
              }.width('100%')

              // 风险核对卡片
              Column({ space: 10 }) {
                this.InfoCard('课程信息', `${this.course!.category} · ${this.course!.teachingClassNo} · ${this.course!.teacher}`, '核对')
                this.InfoCard('时间地点', `${this.course!.classroom} · ${this.course!.weeks}`, '可用')
                this.InfoCard(
                  '容量情况',
                  this.course!.capacity !== undefined
                    ? `已报名 ${this.course!.selectedCount ?? 0} / ${this.course!.capacity} 人`
                    : '容量不限',
                  this.course!.capacity !== undefined &&
                  this.course!.selectedCount !== undefined &&
                  this.course!.selectedCount! >= this.course!.capacity!
                    ? '已满'
                    : '可选'
                )
              }.width('100%')

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.selconfirm_btn_back'), onTap: () => AppRoute.back() })
                PrimaryButton({
                  text: this.submitting ? $r('app.string.common_submitting_zh') : $r('app.string.selconfirm_btn_confirm'),
                  onTap: () => this.doSelect()
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

  @Builder MetricCard(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
    }
    .layoutWeight(1).height(70)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() })
    .borderRadius(18)
  }

  @Builder InfoCard(title: string, desc: string, tag: string) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(38).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Pill({ text: tag })
        }
        Text(desc).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
  }
}

@Builder
export function SelectionConfirmPageBuilder() {
  NavDestination() {
    SelectionConfirmPage()
  }
  .hideTitleBar(true)
}
