// 我的课表 · Schedule
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { StudentTabBar } from '../common/widgets/TabBars';
import { CourseRepository } from '../repositories/CourseRepository';
import { ScheduleItem } from '../models/Course';
import { ScheduleImportService, DEFAULT_TERM } from '../common/services/ScheduleImportService';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { TermUtils } from '../common/utils/TermUtils';
import common from '@ohos.app.ability.common';

function generateWeekNumbers(): number[] {
  let weeks: number[] = [];
  for (let i = 1; i <= 18; i++) {
    weeks.push(i);
  }
  return weeks;
}

@Component
struct SchedulePage {
  @State currentWeek: number = TermUtils.teachingWeek();
  // 周次滚动条控制器：进入页面时把当前周滚动到居中位置
  private weekScroller: ListScroller = new ListScroller();
  @State schedule: ScheduleItem[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State importing: boolean = false;
  @State showImportSheet: boolean = false;
  @StorageProp('breakpoint') bp: string = 'sm';

  private days: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Schedule)) {
      return;
    }
    this.loadSchedule();
  }

  private loadSchedule(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    CourseRepository.get().getSchedule(undefined, this.currentWeek)
      .then((res: ScheduleItem[]) => {
        this.schedule = res;
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private importBundled(): void {
    this.runImport(() => {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return ScheduleImportService.importBundledSchedule(ctx, DEFAULT_TERM);
    }, '已导入我的课表');
  }

  private importFromFile(): void {
    this.runImport(() => {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return ScheduleImportService.pickAndImportSchedule(ctx, DEFAULT_TERM);
    }, '已从文件导入课表');
  }

  private runImport(load: () => Promise<ScheduleItem[]>, okPrefix: string): void {
    if (this.importing) {
      return;
    }
    this.importing = true;
    this.showImportSheet = false;
    load()
      .then((items: ScheduleItem[]) => CourseRepository.get().saveImportedSchedule(items))
      .then((n: number) => {
        this.importing = false;
        this.currentWeek = TermUtils.teachingWeek();
        this.weekScroller.scrollToIndex(this.currentWeek - 1, true, ScrollAlign.CENTER);
        Toast.show(this.getUIContext(), `${okPrefix} · 共 ${n} 节`);
        this.loadSchedule();
      })
      .catch((e: object) => {
        this.importing = false;
        Toast.show(this.getUIContext(), e instanceof Error ? e.message : '导入失败');
      });
  }

  private restoreSample(): void {
    this.showImportSheet = false;
    CourseRepository.get().clearImportedSchedule().then(() => {
      Toast.show(this.getUIContext(), '已恢复示例课表');
      this.loadSchedule();
    });
  }

  @Builder ImportSheet() {
    Column() {
      Column({ space: 4 }) {
        Text($r('app.string.schedule_import_title')).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          .width('100%').textAlign(TextAlign.Start)
        Text($r('app.string.schedule_import_sub')).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          .width('100%').textAlign(TextAlign.Start).margin({ bottom: 8 })
        this.ImportOption('download', '导入我的课表', '内置示例：李仕炜 · 2025-2026 第二学期', () => { this.importBundled(); })
        this.ImportOption('file', '从文件导入', '选择教务导出的 .xlsx 课表文件', () => { this.importFromFile(); })
        this.ImportOption('time', '恢复示例课表', '清除导入，回到内置演示数据', () => { this.restoreSample(); })
      }
      .width('100%').padding(20)
      .backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: -6 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.End)
    .backgroundColor('#66000000')
    .onClick(() => { this.showImportSheet = false; })
  }

  @Builder ImportOption(icon: string, title: string, desc: string, onTap: () => void) {
    Row() {
      Stack() {
        AppIcon({ name: icon, iconSize: 22 })
      }
      .width(44).height(44).borderRadius(14)
      .backgroundColor(ElysiaTheme.SURFACE_GLOW)
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK)
        Text(desc).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 }).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
      AppIcon({ name: 'forward', iconSize: 14, dim: true })
    }
    .width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: ElysiaTheme.hairlineSoft() })
    .onClick(() => { onTap(); })
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
        TopBar({ title: $r('app.string.schedule_title'), subtitle: $r('app.string.schedule_subtitle'), showBack: false })

        // 周次切换
        Column() {
          Row() {
            Column() {
              Text(`第 ${this.currentWeek} 周`)
                .fontSize(18)
                .fontStyle(FontStyle.Italic)
                .fontColor(ElysiaTheme.ROSE_700)
                .fontFamily(ElysiaTheme.FONT_DISPLAY)
              Text(`2025–2026 第二学期 · 第 ${this.currentWeek} 周`)
                .fontSize(10)
                .fontColor(ElysiaTheme.INK_SOFT)
                .letterSpacing(2)
            }
            .alignItems(HorizontalAlign.Start)

            Blank().layoutWeight(1)

            Button('我的选课')
              .height(30)
              .padding({ left: 10, right: 10 })
              .fontSize(11).fontWeight(FontWeight.Medium)
              .fontColor(ElysiaTheme.ROSE_700)
              .backgroundColor(ElysiaTheme.glassSoft())
              .border({ width: 1, color: ElysiaTheme.hairline() })
              .borderRadius(999)
              .margin({ right: 8 })
              .onClick(() => { AppRoute.go(Routes.SelectionResult); })

            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'download', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor(ElysiaTheme.glassSoft())
              .border({ width: 1, color: ElysiaTheme.hairline() })
              .margin({ right: 6 })
              .enabled(!this.importing)
              .accessibilityText($r('app.string.schedule_import_title'))
              .onClick(() => { this.showImportSheet = true; })

            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'back', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor(ElysiaTheme.glassSoft())
              .border({ width: 1, color: ElysiaTheme.hairline() })
              .accessibilityText($r('app.string.schedule_prev_week'))
              .onClick(() => {
                if (this.currentWeek > 1) {
                  this.currentWeek--;
                  this.loadSchedule();
                }
              })
            Button({ type: ButtonType.Circle }) { AppIcon({ name: 'forward', iconSize: 16 }) }
              .width(34).height(34)
              .backgroundColor(ElysiaTheme.glassSoft())
              .border({ width: 1, color: ElysiaTheme.hairline() })
              .margin({ left: 6 })
              .accessibilityText($r('app.string.schedule_next_week'))
              .onClick(() => {
                if (this.currentWeek < 18) {
                  this.currentWeek++;
                  this.loadSchedule();
                }
              })
          }

          // 周次滚动条：List + Scroller，进入页面/切周时把选中周滚动到居中位置
          List({ space: 5, scroller: this.weekScroller }) {
            ForEach(generateWeekNumbers(), (w: number) => {
              ListItem() {
                Button(`${w}`)
                  .height(28)
                  .padding({ left: 10, right: 10 })
                  .fontSize(10)
                  .fontStyle(FontStyle.Italic)
                  .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  .fontColor(w === this.currentWeek ? Color.White : ElysiaTheme.ROSE_700)
                  .backgroundColor(w === this.currentWeek ? '' : ElysiaTheme.glassSoft())
                  .linearGradient(w === this.currentWeek ? {
                    angle: 135,
                    colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                  } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                  .borderRadius(999)
                  .border({ width: w === this.currentWeek ? 0 : 1, color: ElysiaTheme.hairline() })
                  .onClick(() => {
                    this.currentWeek = w;
                    this.weekScroller.scrollToIndex(w - 1, true, ScrollAlign.CENTER);
                    this.loadSchedule();
                  })
              }
            }, (w: number) => `week-${w}`)
          }
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(28)
          .margin({ top: 10 })
          .onAppear(() => {
            this.weekScroller.scrollToIndex(this.currentWeek - 1, false, ScrollAlign.CENTER);
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        if (this.loading) {
          LoadingState({ tip: $r('app.string.schedule_loading') })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadSchedule() })
        } else {
          // 课表网格
          Scroll() {
            Column() {
              // 表头
              Row() {
                Blank().width(24)
                ForEach(this.days, (d: string, i?: number) => {
                  Column() {
                    Text(d)
                      .fontSize(9)
                      .fontColor(ElysiaTheme.INK_MUTE)
                    Text(`${this.dayOfMonth(i ?? 0)}`)
                      .fontSize(13)
                      .fontStyle(FontStyle.Italic)
                      .fontColor((i === 0) ? ElysiaTheme.ROSE_500 : ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }, (d: string) => d)
              }
              .width('100%')
              .margin({ bottom: 6 })

              // 6 行 × 7 列 (weekday 1=Mon..7=Sun → col index 0=Mon..6=Sun)
              ForEach([0, 1, 2, 3, 4, 5], (row: number) => {
                Row() {
                  // 节次列
                  Column() {
                    Text(`${row * 2 + 1}`)
                      .fontSize(10)
                      .fontStyle(FontStyle.Italic)
                      .fontColor(ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                    Text('·')
                      .fontSize(10)
                      .fontColor(ElysiaTheme.ROSE_300)
                    Text(`${row * 2 + 2}`)
                      .fontSize(10)
                      .fontStyle(FontStyle.Italic)
                      .fontColor(ElysiaTheme.ROSE_700)
                      .fontFamily(ElysiaTheme.FONT_DISPLAY)
                  }
                  .width(24)
                  .justifyContent(FlexAlign.Center)

                  // 7 列 (col 0=Mon..6=Sun → weekday = col+1)
                  ForEach([0, 1, 2, 3, 4, 5, 6], (col: number) => {
                    Stack() {
                      this.LessonCell(row * 2 + 1, col + 1)
                    }
                    .layoutWeight(1)
                    .height(72)
                    .margin({ left: 2, right: 2 })
                  }, (col: number) => `col-${row}-${col}`)
                }
                .width('100%')
                .margin({ bottom: 4 })
                .alignItems(VerticalAlign.Center)
              }, (row: number) => `row-${row}`)
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 8 })
        }

        StudentTabBar({
          active: 'schedule',
          onTap: (id: string, route: string) => {
            if (id !== 'schedule') AppRoute.go(route, { replace: true });
          }
        })
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })

      if (this.showImportSheet) {
        this.ImportSheet()
      }
    }
    .width('100%').height('100%')
  }

  @Builder LessonCell(period: number, weekday: number) {
    if (this.findLesson(period, weekday) !== undefined) {
      Column() {
        Text(this.findLesson(period, weekday)!.courseName)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.findLesson(period, weekday)!.classroom)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .opacity(0.75)
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.findLesson(period, weekday)!.teacher)
          .fontSize(8)
          .fontColor(this.hueText(this.findLesson(period, weekday)!.courseType))
          .opacity(0.6)
          .margin({ top: 1 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 5, right: 5, top: 5, bottom: 5 })
      .borderRadius(10)
      .clip(true)
      .linearGradient({
        angle: 160,
        colors: this.hueBg(this.findLesson(period, weekday)!.courseType)
      })
      .onClick(() => {
        const lesson: ScheduleItem | undefined = this.findLesson(period, weekday);
        if (lesson !== undefined) {
          let p: Record<string, Object> = { 'id': lesson.courseId };
          let opts: NavigateOptions = { params: p };
          AppRoute.go(Routes.CourseDetail, opts);
        }
      })
    } else {
      Column()
        .width('100%').height('100%')
        .borderRadius(10)
        .backgroundColor('#66FFFFFF')
        .border({ width: 1, color: '#4DFFB3CE', style: BorderStyle.Dashed })
    }
  }

  // 课表表头日期：按 TermUtils 学期锚点与 currentWeek 推算每列的「日」。
  private dayOfMonth(dayIndex: number): number {
    const monday = TermUtils.weekMonday(this.currentWeek);
    monday.setDate(monday.getDate() + dayIndex);
    return monday.getDate();
  }

  // 区间匹配：跨节次课程（如 1-4 节）在其覆盖的每个时段行都可见，
  // 避免与已选课程同格时整门课从课表上消失。
  findLesson(period: number, weekday: number): ScheduleItem | undefined {
    return this.schedule.find(
      (s: ScheduleItem) => s.weekday === weekday && s.periodStart <= period && s.periodEnd >= period
    );
  }

  hueText(courseType: string): string {
    if (courseType === '选修') return '#6F47A8';
    if (courseType === '公选') return ElysiaTheme.GOLD_700;
    return ElysiaTheme.ROSE_700;
  }

  hueBg(courseType: string): Array<[string, number]> {
    if (courseType === '选修') return [[ElysiaTheme.LAV_200, 0], [ElysiaTheme.LAV_300, 1]];
    if (courseType === '公选') return [['#FFF1D6', 0], [ElysiaTheme.GOLD_300, 1]];
    return [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.ROSE_300, 1]];
  }
}

// 系统路由表构建函数
@Builder
export function SchedulePageBuilder() {
  NavDestination() {
    SchedulePage()
  }
  .hideTitleBar(true)
}
