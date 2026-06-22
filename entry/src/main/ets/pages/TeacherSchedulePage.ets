// 教师端·我的课表（roadmap #6 完善）：按教师姓名匹配的授课课表项，按星期分组展示。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { TeacherRepository } from '../repositories/TeacherRepository';
import { TeacherScheduleItem } from '../models/Teacher';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct TeacherSchedulePage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State items: TeacherScheduleItem[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherSchedule)) {
      return;
    }
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    TeacherRepository.get().getSchedule().then((list: TeacherScheduleItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private weekdayLabel(d: number): string {
    const names: string[] = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return (d >= 1 && d <= 7) ? names[d] : '其他';
  }

  // 当前 weekday 是否需要渲染分组标题（与上一项不同）
  private isNewDay(index: number): boolean {
    if (index === 0) {
      return true;
    }
    return this.items[index].weekday !== this.items[index - 1].weekday;
  }

  @Builder ItemCard(it: TeacherScheduleItem) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(48).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(it.courseName).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Pill({ text: `第${it.periodStart}-${it.periodEnd}节` })
        }
        Text(`${it.startTime}-${it.endTime} · ${it.classroom}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
        Text(`${it.className} · ${it.weekText}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(16)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%').linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '我的课表', subtitle: '本学期授课安排', onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 10 }) {
              if (this.items.length === 0) {
                EmptyState({ title: '本学期暂无课表' })
              } else {
                ForEach(this.items, (item: TeacherScheduleItem, index: number) => {
                  if (this.isNewDay(index)) {
                    Text(this.weekdayLabel(item.weekday))
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
                      .width('100%').margin({ top: index === 0 ? 4 : 8, bottom: 2 })
                  }
                  this.ItemCard(item)
                }, (item: TeacherScheduleItem) => item.itemId)
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
export function TeacherSchedulePageBuilder() {
  NavDestination() {
    TeacherSchedulePage()
  }
  .hideTitleBar(true)
}
