// 消息中心 · 个人系统消息（请假/成绩/选课/评教 回执）。
// 与公告（NoticesPage）彻底区分：这里只显示与本人事务相关的系统消息，点开跳到对应页面。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { MessageRepository } from '../repositories/MessageRepository';
import { Message } from '../models/Message';
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
  @State messages: Message[] = [];
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.MessageCenter)) {
      return;
    }
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    MessageRepository.get().getMessages().then((list: Message[]) => {
      this.messages = list;
      this.loading = false;
      AppStorage.setOrCreate<number>('home.unreadMessage', this.unreadCount());
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private unreadCount(): number {
    let count: number = 0;
    this.messages.forEach((m: Message) => {
      if (!m.isRead) {
        count += 1;
      }
    });
    return count;
  }

  private kindCount(): number {
    const kinds: string[] = [];
    this.messages.forEach((m: Message) => {
      if (kinds.indexOf(m.kind) < 0) {
        kinds.push(m.kind);
      }
    });
    return kinds.length;
  }

  private kindLabel(kind: string): string {
    if (kind === 'leave') {
      return '请假';
    }
    if (kind === 'grade') {
      return '成绩';
    }
    if (kind === 'selection') {
      return '选课';
    }
    if (kind === 'eval') {
      return '评教';
    }
    return '消息';
  }

  private setReadFlag(id: string): void {
    this.messages = this.messages.map((m: Message): Message => {
      if (m.id !== id) {
        return m;
      }
      const copy: Message = {
        id: m.id, kind: m.kind, title: m.title, body: m.body,
        timestamp: m.timestamp, isRead: true, route: m.route, param: m.param
      };
      return copy;
    });
    AppStorage.setOrCreate<number>('home.unreadMessage', this.unreadCount());
  }

  private openMessage(item: Message): void {
    MessageRepository.get().markRead(item.id);
    this.setReadFlag(item.id);
    if (item.param !== undefined) {
      const opts: NavigateOptions = { params: item.param };
      AppRoute.go(item.route, opts);
    } else {
      AppRoute.go(item.route);
    }
  }

  private markAll(): void {
    MessageRepository.get().markAllRead().then(() => {
      this.messages = this.messages.map((m: Message): Message => {
        const copy: Message = {
          id: m.id, kind: m.kind, title: m.title, body: m.body,
          timestamp: m.timestamp, isRead: true, route: m.route, param: m.param
        };
        return copy;
      });
      Toast.show(this.getUIContext(), '已标记全部为已读');
    }).catch(() => {
      Toast.show(this.getUIContext(), '操作失败，请稍后重试');
    });
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

  @Builder MessageRow(item: Message) {
    Row({ space: 10 }) {
      Column()
        .width(10).height(44).borderRadius(6)
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
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Pill({ text: this.kindLabel(item.kind) })
        }
        Text(item.body)
          .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.timestamp.length > 0) {
          Text(item.timestamp).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
    .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      this.openMessage(item);
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
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区
              Column({ space: 6 }) {
                Text(this.unreadCount() > 0 ? `未读消息 ${this.unreadCount()} 条` : $r('app.string.messagecenter_no_unread'))
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text($r('app.string.messagecenter_hero_sub'))
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡
              Row({ space: 10 }) {
                this.MetricCol(`${this.messages.length}`, '全部', ElysiaTheme.ROSE_500)
                this.MetricCol(`${this.unreadCount()}`, '未读', '#D9B675')
                this.MetricCol(`${this.kindCount()}`, '类型', '#B589FF')
              }.width('100%')

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({
                  text: $r('app.string.messagecenter_btn_settings'),
                  onTap: () => Toast.show(this.getUIContext(), '消息设置功能暂未开放')
                })
                PrimaryButton({
                  text: $r('app.string.messagecenter_btn_mark_all'),
                  onTap: () => this.markAll()
                })
              }.width('100%')

              // 消息列表
              if (this.messages.length === 0) {
                EmptyState({ title: $r('app.string.messagecenter_empty') })
              } else {
                Column({ space: 10 }) {
                  ForEach(this.messages, (item: Message) => {
                    this.MessageRow(item)
                  }, (item: Message) => item.id)
                }.width('100%')
              }

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
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
