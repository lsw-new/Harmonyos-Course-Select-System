// 课程详情（管理端） · Admin Course Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminCourseItem } from '../models/Admin';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct AdminCourseDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State course: AdminCourseItem | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminCourseDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少课程 ID';
      this.loading = false;
      return;
    }
    AdminRepository.get().getCourses().then((list: AdminCourseItem[]) => {
      const found = list.find((c: AdminCourseItem) => c.id === id);
      if (!found) {
        this.errorMsg = '课程不存在';
      } else {
        this.course = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private categoryLabel(c: string): string {
    if (c === 'required') return '必修';
    if (c === 'elective') return '选修';
    if (c === 'public') return '公选';
    if (c === 'practice') return '实践';
    return c;
  }

  private statusLabel(s: string): string {
    if (s === 'open') return '开课中';
    if (s === 'closed') return '已关闭';
    if (s === 'draft') return '草稿';
    if (s === 'archived') return '归档';
    return s;
  }

  private statusColor(s: string): string {
    if (s === 'open') return ElysiaTheme.SUCCESS;
    if (s === 'closed') return ElysiaTheme.ROSE_ACCENT;
    if (s === 'draft') return '#D9B675';
    return ElysiaTheme.INK_MUTE;
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.admincoursedetail_title'), subtitle: $r('app.string.admincoursedetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.course !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero：容量/状态/学分指标卡
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Pill({ text: this.categoryLabel(this.course!.category) })
                  Pill({ text: this.statusLabel(this.course!.status), color: this.statusColor(this.course!.status), bg: ElysiaTheme.SURFACE_GLOW })
                }
                Text(this.course!.name)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(`${this.course!.code} · ${this.course!.teacher}`)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 三指标
              Row({ space: 10 }) {
                Column() {
                  Text(`${this.course!.selectedCount}/${this.course!.capacity}`)
                    .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(ElysiaTheme.ROSE_500).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text('容量').fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(this.statusLabel(this.course!.status))
                    .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor(this.statusColor(this.course!.status)).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text('状态').fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)

                Column() {
                  Text(`${this.course!.credit}`)
                    .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
                    .fontColor('#D9B675').fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text('学分').fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
              }.width('100%')

              // 课程基础信息
              Column() {
                Text('课程基础信息').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('课程代码', this.course!.code)
                this.InfoRow('课程名称', this.course!.name)
                this.InfoRow('授课教师', this.course!.teacher)
                this.InfoRow('课程类型', this.categoryLabel(this.course!.category))
                this.InfoRow('上课时间', this.course!.timeText)
                this.InfoRow('学分', `${this.course!.credit}`)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 选课名单概况
              Column() {
                Text('选课名单概况').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                Row() {
                  Column().height(8).width(`${Math.min(this.course!.selectedCount / this.course!.capacity * 100, 100)}%`)
                    .backgroundColor(this.course!.selectedCount >= this.course!.capacity ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.ROSE_500)
                    .borderRadius(4)
                }.width('100%').height(8).backgroundColor('#FFE9F1').borderRadius(4).margin({ bottom: 8 })
                Text(`已选 ${this.course!.selectedCount} 人 / 容量 ${this.course!.capacity} 人`)
                  .fontSize(13).fontColor(ElysiaTheme.INK)
                Text(this.course!.selectedCount >= this.course!.capacity ? '已满员' : `剩余 ${this.course!.capacity - this.course!.selectedCount} 个名额`)
                  .fontSize(12).fontColor(this.course!.selectedCount >= this.course!.capacity ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.INK_SOFT)
                  .margin({ top: 4 })
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: '导出名单', onTap: () => Toast.show(this.getUIContext(), '导出功能敬请期待') })
                PrimaryButton({ text: '编辑课程', onTap: () => AppRoute.go(Routes.AdminCourses) })
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
}

// 系统路由表构建函数
@Builder
export function AdminCourseDetailPageBuilder() {
  NavDestination() {
    AdminCourseDetailPage()
  }
  .hideTitleBar(true)
}
