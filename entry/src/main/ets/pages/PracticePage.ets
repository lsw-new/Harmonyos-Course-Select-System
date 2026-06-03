// 实践与公服 · Practice（Tab 页）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { StudentTabBar } from '../common/widgets/TabBars';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { PracticeRepository } from '../repositories/PracticeRepository';
import { PracticeProject, PracticeCategory } from '../models/PracticeModels';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';

// 分类筛选项：value 为空字符串表示「全部」。
class PracticeFilter {
  value: string = '';
  label: string = '';
  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

const FILTERS: PracticeFilter[] = [
  new PracticeFilter('', '全部'),
  new PracticeFilter('internship', '企业实习'),
  new PracticeFilter('research', '科研训练'),
  new PracticeFilter('social', '社会实践'),
  new PracticeFilter('volunteer', '志愿服务')
];

function categoryLabel(c: PracticeCategory): string {
  if (c === 'internship') return '企业实习';
  if (c === 'research') return '科研训练';
  if (c === 'social') return '社会实践';
  return '志愿服务';
}

@Entry
@Component
struct PracticePage {
  @State projects: PracticeProject[] = [];
  @State category: string = '';
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State actionError: string = '';
  @State busyId: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Practice)) {
      return;
    }
    this.loadData();
  }

  private currentCategory(): PracticeCategory | undefined {
    return this.category.length > 0 ? this.category as PracticeCategory : undefined;
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    this.actionError = '';
    PracticeRepository.get().getProjects(this.currentCategory()).then((list: PracticeProject[]) => {
      this.projects = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private reloadProjects(): void {
    this.actionError = '';
    PracticeRepository.get().getProjects(this.currentCategory()).then((list: PracticeProject[]) => {
      this.projects = list;
    }).catch((e: object) => {
      this.actionError = e instanceof Error ? e.message : '操作失败';
    });
  }

  private openDetail(project: PracticeProject): void {
    const p: Record<string, Object> = { 'id': project.id };
    AppRoute.go(Routes.PracticeDetail, { params: p });
  }

  private toggleSignUp(project: PracticeProject): void {
    if (this.busyId.length > 0) {
      return;
    }
    if (!project.signedUp && project.slotsTaken >= project.slotsTotal) {
      this.actionError = '该项目名额已满';
      Toast.show(this.getUIContext(), '该项目名额已满');
      return;
    }
    this.busyId = project.id;
    this.actionError = '';
    const repo = PracticeRepository.get();
    const isCancel = project.signedUp;
    const action: Promise<PracticeProject> = isCancel ? repo.cancelSignUp(project.id) : repo.signUp(project.id);
    action.then(() => {
      this.busyId = '';
      Toast.show(this.getUIContext(), isCancel ? '已取消报名' : '报名成功');
      this.reloadProjects();
    }).catch((e: object) => {
      this.busyId = '';
      const msg = (e instanceof HttpError) ? (e as HttpError).message : (isCancel ? '取消失败' : '报名失败');
      this.actionError = msg;
      Toast.show(this.getUIContext(), msg);
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
        TopBar({ title: '实践', subtitle: '实 践 与 公 服', showBack: false })

        // 分类筛选
        Scroll() {
          Row({ space: 6 }) {
            ForEach(FILTERS, (f: PracticeFilter) => {
              Button(f.label).height(28).fontSize(11)
                .padding({ left: 14, right: 14 })
                .borderRadius(999)
                .fontColor(f.value === this.category ? Color.White : ElysiaTheme.ROSE_700)
                .backgroundColor(f.value === this.category ? '' : ElysiaTheme.glass())
                .linearGradient(f.value === this.category
                  ? { angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]] }
                  : { angle: 0, colors: [['#00FFFFFF', 0]] })
                .border({ width: f.value === this.category ? 0 : 1, color: ElysiaTheme.hairline() })
                .onClick(() => {
                  this.category = f.value;
                  this.loadData();
                })
            }, (f: PracticeFilter) => f.value.length > 0 ? f.value : 'all')
          }.padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .margin({ top: 6, bottom: 8 })

        if (this.loading) {
          LoadingState({ tip: '正在加载实践项目...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.projects.length === 0) {
          EmptyState({ icon: 'practice', title: '暂无实践项目' })
        } else {
          Scroll() {
            Column() {
              if (this.actionError.length > 0) {
                Text(this.actionError)
                  .fontSize(12).fontColor(ElysiaTheme.ROSE_700)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .width('100%')
                  .backgroundColor('#FFEBEE').borderRadius(10)
                  .margin({ bottom: 10 })
              }

              Column({ space: 10 }) {
                ForEach(this.projects, (project: PracticeProject) => {
                  this.ProjectCard(project)
                }, (project: PracticeProject) => project.id)
              }
              .margin({ bottom: 20 })
              SafeBottom()
            }
            .padding({ left: 16, right: 16 })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }

        StudentTabBar({ active: 'prac', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }

  // 项目状态 Pill：可报名 / 已报名 / 已满。
  @Builder StatusPill(project: PracticeProject) {
    if (project.signedUp) {
      Pill({ text: '已报名', bg: '#E6F5EC', color: '#3E8E5E' })
    } else if (project.slotsTaken >= project.slotsTotal) {
      Pill({ text: '已满', bg: '#F0F0F0', color: ElysiaTheme.INK_MUTE })
    } else {
      Pill({ text: '可报名' })
    }
  }

  @Builder ActionButton(project: PracticeProject) {
    if (project.signedUp) {
      Button(this.busyId === project.id ? '处理中' : '取消')
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.ROSE_700)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(this.busyId.length === 0)
        .onClick(() => { this.toggleSignUp(project); })
    } else if (project.slotsTaken >= project.slotsTotal) {
      Button('已 满')
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.INK_MUTE)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(false)
    } else {
      Button(this.busyId === project.id ? '处理中' : '报 名')
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor('')
        .linearGradient({ angle: 135, colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]] })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(this.busyId.length === 0)
        .onClick(() => { this.toggleSignUp(project); })
    }
  }

  @Builder ProjectCard(project: PracticeProject) {
    Column({ space: 8 }) {
      Row() {
        Column() {
          Text(project.title).fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor(ElysiaTheme.INK).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(project.org).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        this.StatusPill(project)
      }.width('100%').alignItems(VerticalAlign.Top)

      Row({ space: 6 }) {
        Pill({ text: categoryLabel(project.category), bg: '#EFE4FF', color: ElysiaTheme.LAV_500 })
        Pill({ text: `${project.credits} 学分`, bg: '#FBE6C2', color: ElysiaTheme.GOLD_700 })
      }.width('100%')

      Row() {
        AppIcon({ name: 'time', iconSize: 14, mRight: 4 })
        Text(project.period).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').alignItems(VerticalAlign.Center)

      Row() {
        Text(`已报名 ${project.slotsTaken}/${project.slotsTotal}`)
          .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
        this.ActionButton(project)
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
    .onClick(() => { this.openDetail(project); })
  }
}
