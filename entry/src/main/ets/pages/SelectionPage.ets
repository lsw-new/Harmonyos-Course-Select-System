// 选课中心 · Selection
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { ErrorState, EmptyState } from '../common/widgets/StateViews';
import { SkeletonList } from '../common/widgets/Skeleton';
import { ArrayDataSource } from '../common/widgets/DataSource';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { CourseRepository } from '../repositories/CourseRepository';
import { SelectionCourse, SelectionRoundInfo } from '../models/Course';
import { SafeTop } from '../common/widgets/SafeArea';

const CATEGORIES: string[] = ['全部', '必修', '选修', '公选'];

function formatRemaining(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  return `${days}d ${hours}h`;
}

@Entry
@Component
struct SelectionPage {
  @State courses: SelectionCourse[] = [];
  @State round: SelectionRoundInfo | undefined = undefined;
  @State query: string = '';
  @State category: string = '全部';
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State actionError: string = '';
  @StorageProp('safeBottom') safeBottom: number = 0;
  @StorageProp('breakpoint') bp: string = 'sm';
  private coursesDs: ArrayDataSource<SelectionCourse> = new ArrayDataSource<SelectionCourse>();

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Selection)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    this.actionError = '';
    const repo = CourseRepository.get();
    Promise.all([
      repo.getSelectionRound(),
      repo.getSelectionCourses(this.query, this.category)
    ])
      .then((res: [SelectionRoundInfo, SelectionCourse[]]) => {
        this.round = res[0];
        this.courses = res[1];
        this.coursesDs.setData(res[1]);
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private reloadCourses(): void {
    this.actionError = '';
    CourseRepository.get().getSelectionCourses(this.query, this.category)
      .then((res: SelectionCourse[]) => {
        this.courses = res;
        this.coursesDs.setData(res);
      })
      .catch((e: object) => {
        this.actionError = e instanceof Error ? e.message : '操作失败';
      });
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
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: '选课中心', subtitle: '选 课 中 心', onBack: () => AppRoute.back() })

        if (this.loading) {
          SkeletonList({ count: 5 })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else {
          List() {
            ListItem() {
              Column() {
              // Hero 卡片
              if (this.round !== undefined) {
                Column() {
                  Row() {
                    Column() {
                      Pill({ text: this.round!.inProgress ? '正选阶段·进行中' : '选课未开放' })
                      Text(this.round!.roundName).fontSize(18).fontStyle(FontStyle.Italic)
                        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                        .margin({ top: 6 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                    Column() {
                      Text(formatRemaining(this.round!.remainingSeconds))
                        .fontSize(14).fontStyle(FontStyle.Italic)
                        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                      Text('剩余时间').fontSize(9).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
                    }.alignItems(HorizontalAlign.End)
                  }

                  // 进度条
                  Stack({ alignContent: Alignment.Start }) {
                    Stack().width('100%').height(6).borderRadius(3).backgroundColor(ElysiaTheme.glassSoft())
                    Stack()
                      .width(`${Math.min((this.round!.selectedCredits / this.round!.creditLimit) * 100, 100)}%`)
                      .height(6).borderRadius(3)
                      .linearGradient({ angle: 90, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]] })
                  }.margin({ top: 12 })

                  Row() {
                    Text(`已选 ${this.round!.selectedCredits} 学分`)
                      .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
                    Text(`上限 ${this.round!.creditLimit} 学分`)
                      .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  }.margin({ top: 8 })
                }
                .width('100%').padding(16).borderRadius(22)
                .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
                .margin({ bottom: 14 })
              }

              // 搜索框
              Row() {
                AppIcon({ name: 'search', iconSize: 16, mLeft: 10 })
                TextInput({ placeholder: '搜索课程名 / 教师 / 代码', text: this.query })
                  .height(40).fontSize(12)
                  .backgroundColor(Color.Transparent)
                  .placeholderColor(ElysiaTheme.INK_MUTE)
                  .fontColor(ElysiaTheme.INK)
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    this.query = v;
                    this.reloadCourses();
                  })
              }
              .width('100%').backgroundColor(ElysiaTheme.glass()).borderRadius(14)
              .border({ width: 1, color: ElysiaTheme.hairline() })
              .margin({ bottom: 10 })

              // 分类筛选
              Scroll() {
                Row({ space: 6 }) {
                  ForEach(CATEGORIES, (cat: string) => {
                    Button(cat).height(28).fontSize(11)
                      .padding({ left: 14, right: 14 })
                      .borderRadius(999)
                      .fontColor(cat === this.category ? Color.White : ElysiaTheme.ROSE_700)
                      .backgroundColor(cat === this.category ? '' : ElysiaTheme.glass())
                      .linearGradient(cat === this.category
                        ? { angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]] }
                        : { angle: 0, colors: [['#00FFFFFF', 0]] })
                      .border({ width: cat === this.category ? 0 : 1, color: ElysiaTheme.hairline() })
                      .onClick(() => {
                        this.category = cat;
                        this.reloadCourses();
                      })
                  }, (cat: string) => cat)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .margin({ bottom: 12 })

              // 操作错误提示
              if (this.actionError.length > 0) {
                Text(this.actionError)
                  .fontSize(12).fontColor(ElysiaTheme.ROSE_700)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .width('100%')
                  .backgroundColor('#FFEBEE').borderRadius(10)
                  .margin({ bottom: 10 })
              }
              }
            }

            if (this.courses.length === 0) {
              ListItem() {
                EmptyState({ icon: 'petal', title: '没有找到相关课程' })
              }
            } else {
              LazyForEach(this.coursesDs, (c: SelectionCourse) => {
                ListItem() {
                  Row() {
                      Column() {
                        Row() {
                          Text(c.course.name).fontSize(13).fontWeight(FontWeight.Bold)
                            .fontColor(ElysiaTheme.INK)
                          Text('  ' + c.course.code).fontSize(10).fontStyle(FontStyle.Italic)
                            .fontColor(ElysiaTheme.INK_MUTE).fontFamily(ElysiaTheme.FONT_DISPLAY)
                        }
                        Text(c.course.teacher + ' · ' + (c.course.capacity !== undefined
                          ? `${c.course.selectedCount ?? 0}/${c.course.capacity}`
                          : '—'))
                          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
                        Row({ space: 6 }) {
                          Pill({ text: c.course.category })
                          Pill({ text: `${c.course.credit} 学分`, bg: '#FBE6C2', color: ElysiaTheme.GOLD_700 })
                          if (c.conflictWith !== undefined && c.conflictWith!.length > 0) {
                            Pill({ text: c.conflictWith!, bg: '#FFEBEE', color: ElysiaTheme.ROSE_700 })
                          }
                        }.margin({ top: 6 })
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                      if (c.status === 'available') {
                        Button('选 课')
                          .height(34).fontSize(11).fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)
                          .backgroundColor('')
                          .linearGradient({ angle: 135, colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]] })
                          .borderRadius(999)
                          .padding({ left: 14, right: 14 })
                          .onClick(() => {
                            CourseRepository.get().selectCourse(c.course.id)
                              .then(() => { this.reloadCourses(); })
                              .catch((e: object) => {
                                this.actionError = e instanceof Error ? e.message : '选课失败';
                              });
                          })
                      } else if (c.status === 'selected') {
                        Button('退 选')
                          .height(34).fontSize(11).fontWeight(FontWeight.Bold)
                          .fontColor(ElysiaTheme.ROSE_700)
                          .backgroundColor(ElysiaTheme.glass())
                          .border({ width: 1, color: ElysiaTheme.hairline() })
                          .borderRadius(999)
                          .padding({ left: 14, right: 14 })
                          .onClick(() => {
                            CourseRepository.get().dropCourse(c.course.id)
                              .then(() => { this.reloadCourses(); })
                              .catch((e: object) => {
                                this.actionError = e instanceof Error ? e.message : '退选失败';
                              });
                          })
                      } else if (c.status === 'full') {
                        Button('已 满')
                          .height(34).fontSize(11).fontWeight(FontWeight.Bold)
                          .fontColor(ElysiaTheme.INK_MUTE)
                          .backgroundColor(ElysiaTheme.glass())
                          .border({ width: 1, color: ElysiaTheme.hairline() })
                          .borderRadius(999)
                          .padding({ left: 14, right: 14 })
                          .enabled(false)
                      } else {
                        Button('冲 突')
                          .height(34).fontSize(11).fontWeight(FontWeight.Bold)
                          .fontColor(ElysiaTheme.INK_MUTE)
                          .backgroundColor(ElysiaTheme.glass())
                          .border({ width: 1, color: ElysiaTheme.hairline() })
                          .borderRadius(999)
                          .padding({ left: 14, right: 14 })
                          .enabled(false)
                      }
                    }
                    .width('100%').padding(14)
                    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
                  }.margin({ bottom: 10 })
                }, (c: SelectionCourse) => c.course.id)
            }
          }
          .layoutWeight(1)
          .cachedCount(6)
          .padding({ left: 16, right: 16, bottom: this.safeBottom + 16 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }
}
