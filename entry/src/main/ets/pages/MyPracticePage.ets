// 我的实践 · My Practice
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { PracticeRepository } from '../repositories/PracticeRepository';
import { PracticeProject, PracticeCategory } from '../models/PracticeModels';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

function categoryLabel(c: PracticeCategory): string {
  if (c === 'internship') {
    return '企业实习';
  }
  if (c === 'research') {
    return '科研训练';
  }
  if (c === 'social') {
    return '社会实践';
  }
  return '志愿服务';
}

@Component
struct MyPracticePage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State projects: PracticeProject[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.MyPractice)) {
      return;
    }
    PracticeRepository.get().getProjects().then((all: PracticeProject[]) => {
      this.projects = all.filter((p: PracticeProject) => p.signedUp);
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.mypractice_title'), subtitle: $r('app.string.mypractice_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 汇总卡
              Column({ space: 10 }) {
                Pill({ text: '报名记录' })
                Text('实践进度中心')
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(`已报名 ${this.projects.length} 个项目`)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 项目列表
              if (this.projects.length === 0) {
                EmptyState({ title: '暂无报名记录' })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.projects, (project: PracticeProject) => {
                    this.ProjectCard(project)
                  }, (project: PracticeProject) => project.id)
                }.width('100%')
              }

              // 底部操作按钮
              Row({ space: 12 }) {
                GhostButton({
                  text: '导出证明',
                  onTap: () => { Toast.show(this.getUIContext(), '导出功能即将上线'); }
                })
                PrimaryButton({
                  text: '查看全部记录',
                  onTap: () => { Toast.show(this.getUIContext(), '全部记录功能即将上线'); }
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

  @Builder ProjectCard(project: PracticeProject) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(48).borderRadius(6)
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })

      Column({ space: 6 }) {
        Text(project.title)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(project.org)
          .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Pill({ text: categoryLabel(project.category), bg: '#EFE4FF', color: ElysiaTheme.LAV_500 })
          Pill({ text: `${project.credits} 学分`, bg: '#FBE6C2', color: ElysiaTheme.GOLD_700 })
          Pill({ text: '已报名', bg: '#E6F5EC', color: '#3E8E5E' })
        }
        Text(`已报名 ${project.slotsTaken}/${project.slotsTotal} · ${project.period}`)
          .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      const p: Record<string, Object> = { 'id': project.id };
      AppRoute.go(Routes.PracticeDetail, { params: p });
    })
  }
}

@Builder
export function MyPracticePageBuilder() {
  NavDestination() {
    MyPracticePage()
  }
  .hideTitleBar(true)
}
