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
import { TeacherTabBar } from '../common/widgets/TabBars';

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

  // 今天星期（1=周一…7=周日；JS getDay 0=周日）
  private todayWeekday(): number {
    const g = new Date().getDay();
    return g === 0 ? 7 : g;
  }

  // 当前 weekday 是否需要渲染分组标题（与上一项不同）
  private isNewDay(index: number): boolean {
    if (index === 0) {
      return true;
    }
    return this.items[index].weekday !== this.items[index - 1].weekday;
  }

  // 当前时间，零填充 "HH:mm"
  private nowHHMM(): string {
    const d = new Date();
    const h = d.getHours();
    const m = d.getMinutes();
    const hStr = h < 10 ? '0' + h.toString() : h.toString();
    const mStr = m < 10 ? '0' + m.toString() : m.toString();
    return hStr + ':' + mStr;
  }

  // 今日所有课表项
  private todayItems(): TeacherScheduleItem[] {
    const today = this.todayWeekday();
    return this.items.filter((it: TeacherScheduleItem) => it.weekday === today);
  }

  // 今日下一节课（第一个 startTime >= nowHHMM()）
  private nextTodayItem(): TeacherScheduleItem | null {
    const now = this.nowHHMM();
    const list = this.todayItems();
    for (let i = 0; i < list.length; i++) {
      if (list[i].startTime >= now) {
        return list[i];
      }
    }
    return null;
  }

  @Builder NextClassCard() {
    Column({ space: 6 }) {
      Text('下一节课').fontSize(11).fontColor(ElysiaTheme.ROSE_500).fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
      if (this.nextTodayItem() !== null) {
        Row({ space: 8 }) {
          Text((this.nextTodayItem() as TeacherScheduleItem).courseName)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%')
        Text(`${(this.nextTodayItem() as TeacherScheduleItem).startTime}-${(this.nextTodayItem() as TeacherScheduleItem).endTime} · ${(this.nextTodayItem() as TeacherScheduleItem).classroom}`)
          .fontSize(13).fontColor(ElysiaTheme.INK_SOFT).alignSelf(ItemAlign.Start)
        Text((this.nextTodayItem() as TeacherScheduleItem).className)
          .fontSize(12).fontColor(ElysiaTheme.INK_MUTE).alignSelf(ItemAlign.Start)
      } else if (this.todayItems().length > 0) {
        Text('今日课程已结束').fontSize(15).fontColor(ElysiaTheme.INK_SOFT).alignSelf(ItemAlign.Start)
      } else {
        Text('今天没有课').fontSize(15).fontColor(ElysiaTheme.INK_MUTE).alignSelf(ItemAlign.Start)
      }
      Text(`今日 ${this.todayItems().length} 节课`)
        .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).alignSelf(ItemAlign.Start)
    }
    .width('100%').padding(16)
    .backgroundColor(ElysiaTheme.ROSE_50)
    .border({ width: 1.5, color: ElysiaTheme.ROSE_200 }).borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder ItemCard(it: TeacherScheduleItem, isToday: boolean, ongoing: boolean) {
    Row({ space: 10 }) {
      Column()
        .width(4).height(48).borderRadius(2)
        .backgroundColor(ongoing ? ElysiaTheme.ROSE_500 : ElysiaTheme.ROSE_700)
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(it.courseName).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (ongoing) {
            Text('进行中')
              .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(8)
          }
          Pill({ text: `第${it.periodStart}-${it.periodEnd}节` })
        }
        Text(`${it.startTime}-${it.endTime} · ${it.classroom}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
        Text(`${it.className} · ${it.weekText}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14)
    .backgroundColor(isToday ? ElysiaTheme.ROSE_50 : ElysiaTheme.SURFACE)
    .border({ width: isToday ? 1.5 : 1, color: isToday ? ElysiaTheme.ROSE_200 : ElysiaTheme.hairlineSoft() }).borderRadius(16)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%').linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '我的课表', subtitle: '本学期授课安排', showBack: false })

        Column() {
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
                this.NextClassCard()
                ForEach(this.items, (item: TeacherScheduleItem, index: number) => {
                  if (this.isNewDay(index)) {
                    Row({ space: 8 }) {
                      Text(this.weekdayLabel(item.weekday))
                        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
                      if (item.weekday === this.todayWeekday()) {
                        Text('今天')
                          .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
                          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                          .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(8)
                      }
                    }.width('100%').margin({ top: index === 0 ? 4 : 8, bottom: 2 })
                  }
                  this.ItemCard(item, item.weekday === this.todayWeekday(),
                    item.weekday === this.todayWeekday() &&
                    item.startTime <= this.nowHHMM() &&
                    this.nowHHMM() <= item.endTime)
                }, (item: TeacherScheduleItem) => item.itemId)
              }
              SafeBottom()
            }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
        }.width('100%').layoutWeight(1)

        TeacherTabBar({
          active: 'schedule',
          onTap: (id: string, route: string) => {
            if (id !== 'schedule') {
              AppRoute.go(route, { replace: true });
            }
          }
        })
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
