// 消息中心 · Message Center
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { Notice } from '../models/Notice';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Component
struct MessageCenterPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State notices: Notice[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.MessageCenter)) {
      return;
    }
    CourseRepository.get().getNotices().then((list: Notice[]) => {
      this.notices = list;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private unreadCount(): number {
    let count: number = 0;
    this.notices.forEach((n: Notice) => {
      if (!n.isRead) {
        count += 1;
      }
    });
    return count;
  }

  private categoryCount(): number {
    const cats: string[] = [];
    this.notices.forEach((n: Notice) => {
      if (cats.indexOf(n.category) < 0) {
        cats.push(n.category);
      }
    });
    return cats.length;
  }

  @Builder MetricCol(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(22).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
    }.layoutWeight(1).height(70).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(18)
  }

  @Builder MessageRow(item: Notice) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(38).borderRadius(6)
        .linearGradient({
          angle: 180,
          colors: item.isRead
            ? [['#E0E0E0', 0], ['#C8C8C8', 1]]
            : [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]]
        })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.title)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            .layoutWeight(1).maxLines(1)
          Pill({ text: item.category })
        }
        Text(item.publishedAt).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      const p: Record<string, Object> = { 'id': item.id };
      const opts: NavigateOptions = { params: p };
      AppRoute.go(Routes.NoticeDetail, opts);
    })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.messagecenter_title'), subtitle: $r('app.string.messagecenter_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区
              Column({ space: 6 }) {
                Text(this.unreadCount() > 0 ? `今日未读 ${this.unreadCount()} 条` : $r('app.string.messagecenter_no_unread'))
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text($r('app.string.messagecenter_hero_sub'))
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                this.MetricCol(`${this.notices.length}`, '全部', ElysiaTheme.ROSE_500)
                this.MetricCol(`${this.unreadCount()}`, '未读', '#D9B675')
                this.MetricCol(`${this.categoryCount()}`, '分类数', '#B589FF')
              }.width('100%')

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({
                  text: $r('app.string.messagecenter_btn_settings'),
                  onTap: () => Toast.show(this.getUIContext(), '消息设置功能暂未开放')
                })
                PrimaryButton({
                  text: $r('app.string.messagecenter_btn_mark_all'),
                  onTap: () => Toast.show(this.getUIContext(), '已标记全部为已读')
                })
              }.width('100%')

              // 消息列表
              if (this.notices.length === 0) {
                EmptyState({ title: $r('app.string.messagecenter_empty') })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.notices, (item: Notice) => {
                    this.MessageRow(item)
                  }, (item: Notice) => item.id)
                }.width('100%')
              }

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
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
export function MessageCenterPageBuilder() {
  NavDestination() {
    MessageCenterPage()
  }
  .hideTitleBar(true)
}
