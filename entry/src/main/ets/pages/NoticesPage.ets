// 通知公告 · Notices
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseIcon } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { StudentTabBar } from '../common/widgets/TabBars';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { CourseRepository } from '../repositories/CourseRepository';
import { Notice } from '../models/Notice';

// EXACT category values from mockNotices.ets
const CATEGORIES: string[] = ['全部', '教务', '学工', '生活'];

@Entry
@Component
struct NoticesPage {
  @State activeFilter: number = 0;
  @State notices: Notice[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Notices)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const cat = this.activeFilter === 0 ? undefined : CATEGORIES[this.activeFilter];
    CourseRepository.get().getNotices(cat).then((res: Notice[]) => {
      this.notices = res;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
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
        TopBar({ title: '通知公告', subtitle: '通 知 公 告' })

        Scroll() {
          Row({ space: 6 }) {
            ForEach(CATEGORIES, (t: string, i?: number) => {
              Button(t)
                .height(28)
                .padding({ left: 12, right: 12 })
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor((i === this.activeFilter) ? Color.White : ElysiaTheme.ROSE_700)
                .backgroundColor((i === this.activeFilter) ? '' : ElysiaTheme.glass())
                .linearGradient((i === this.activeFilter) ? {
                  angle: 135,
                  colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                .borderRadius(999)
                .border({ width: (i === this.activeFilter) ? 0 : 1, color: ElysiaTheme.hairline() })
                .onClick(() => {
                  this.activeFilter = i ?? 0;
                  this.loadData();
                })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, bottom: 10 })

        Column() {
          if (this.loading) {
            LoadingState({ tip: '正在加载通知...' })
          } else if (this.errorMsg.length > 0) {
            ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
          } else if (this.notices.length === 0) {
            EmptyState({ title: '暂无通知' })
          } else {
            List({ space: 10 }) {
              ForEach(this.notices, (n: Notice) => {
                ListItem() {
                  this.NoticeCard(n)
                }
              }, (n: Notice) => n.id)
            }
            .listDirection(Axis.Vertical)
            .scrollBar(BarState.Off)
            .padding({ left: 16, right: 16 })
            .layoutWeight(1)
          }
        }
        .width('100%').layoutWeight(1)

        StudentTabBar({
          active: 'pub',
          onTap: (id: string, route: string) => {
            if (id !== 'pub') AppRoute.go(route, { replace: true });
          }
        })
      }
      .width('100%').height('100%')
    }
    .width('100%').height('100%')
  }

  @Builder NoticeCard(n: Notice) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Stack() {
          RoseIcon({ iconSize: 22 })
        }
        .width(44).height(44)
        .borderRadius(14)
        .linearGradient({
          angle: 135,
          colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]]
        })
        .border({ width: 1, color: ElysiaTheme.hairline() })

        Column() {
          Row() {
            Pill({ text: n.category })
            Text('  ' + n.publishedAt.slice(5, 10))
              .fontSize(10)
              .fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.INK_MUTE)
              .fontFamily(ElysiaTheme.FONT_DISPLAY)
          }
          Text(n.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ElysiaTheme.INK)
            .margin({ top: 5 })
            .maxLines(2)
          Text(n.summary)
            .fontSize(11)
            .fontColor(ElysiaTheme.INK_SOFT)
            .margin({ top: 4 })
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .layoutWeight(1)
      }
      .width('100%')
      .padding(14)

      if (!n.isRead) {
        Stack()
          .width(8).height(8)
          .borderRadius(4)
          .backgroundColor(ElysiaTheme.ROSE_500)
          .margin({ top: 14, right: 14 })
      }
    }
    .width('100%')
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(22)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      let p: Record<string, Object> = { 'id': n.id };
      let opts: NavigateOptions = { params: p };
      AppRoute.go(Routes.NoticeDetail, opts);
    })
  }
}
