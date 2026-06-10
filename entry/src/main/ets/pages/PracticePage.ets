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

@Component
struct PracticePage {
  @State projects: PracticeProject[] = [];
  @State category: string = '';
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State actionError: string = '';
  @State busyId: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';
  // 报名状态变更信号：详情页/报名页提交后回写，本页据此重新拉取，保持列表与详情同步
  @StorageProp('practice.refreshTick') @Watch('onPracticeRefresh') practiceTick: number = 0;

  onPracticeRefresh(): void {
    // 首屏加载完成后才响应跨页变更，避免初始化期间空刷
    if (!this.loading) {
      this.reloadProjects();
    }
  }

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
    action.then((updated: PracticeProject) => {
      this.busyId = '';
      Toast.show(this.getUIContext(), isCancel ? '已取消报名' : '报名成功');
      // 只替换被操作的那一项：其余卡片 key 不变不重建，避免整列表刷新引起其他项按钮闪动
      const idx = this.projects.findIndex((p: PracticeProject) => p.id === updated.id);
      if (idx >= 0) {
        this.projects.splice(idx, 1, updated);
      } else {
        this.reloadProjects();
      }
    }).catch((e: object) => {
      this.busyId = '';
      const msg = (e instanceof HttpError) ? (e as HttpError).message : (isCancel ? '取消失败' : '报名失败');
      this.actionError = msg;
      Toast.show(this.getUIContext(), msg);
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
        TopBar({ title: $r('app.string.practice_title'), subtitle: $r('app.string.practice_subtitle'), showBack: false })

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
        .margin({ top: 6, bottom: 4 })

        // 「我的实践」快捷入口
        Row() {
          Blank().layoutWeight(1)
          Button('我的实践')
            .height(30)
            .padding({ left: 14, right: 14 })
            .fontSize(11).fontWeight(FontWeight.Medium)
            .fontColor(ElysiaTheme.ROSE_700)
            .backgroundColor(ElysiaTheme.glassSoft())
            .border({ width: 1, color: ElysiaTheme.hairline() })
            .borderRadius(999)
            .onClick(() => { AppRoute.go(Routes.MyPractice); })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })

        if (this.loading) {
          // 状态视图撑满内容区：避免加载期间底部 TabBar 上浮、布局跳动
          Column() { LoadingState({ tip: $r('app.string.practice_loading') }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.projects.length === 0) {
          Column() { EmptyState({ icon: 'practice', title: $r('app.string.practice_empty') }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
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
                  // key 编码报名状态与名额：报名/取消后字段变化即触发卡片重建，避免 ForEach 复用旧卡导致按钮/名额不刷新
                }, (project: PracticeProject) => `${project.id}-${project.signedUp ? 1 : 0}-${project.slotsTaken}/${project.slotsTotal}`)
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
      Pill({ text: $r('app.string.practice_signed'), bg: '#E6F5EC', color: '#3E8E5E' })
    } else if (project.slotsTaken >= project.slotsTotal) {
      Pill({ text: $r('app.string.practice_full'), bg: '#F0F0F0', color: ElysiaTheme.INK_MUTE })
    } else {
      Pill({ text: $r('app.string.practice_open') })
    }
  }

  @Builder ActionButton(project: PracticeProject) {
    if (project.signedUp) {
      Button(this.busyId === project.id ? $r('app.string.practice_processing') : $r('app.string.common_cancel'))
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.ROSE_700)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(this.busyId !== project.id)
        .onClick(() => { this.toggleSignUp(project); })
    } else if (project.slotsTaken >= project.slotsTotal) {
      Button($r('app.string.practice_btn_full'))
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.INK_MUTE)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(false)
    } else {
      Button(this.busyId === project.id ? $r('app.string.practice_processing') : $r('app.string.practice_btn_signup'))
        .height(34).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor('')
        .linearGradient({ angle: 135, colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]] })
        .borderRadius(999)
        .padding({ left: 14, right: 14 })
        .enabled(this.busyId !== project.id)
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

// 系统路由表构建函数
@Builder
export function PracticePageBuilder() {
  NavDestination() {
    PracticePage()
  }
  .hideTitleBar(true)
}
