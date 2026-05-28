// 通知公告 · Notices
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseIcon } from '../common/Components';

interface NoticeItem {
  tag: string;
  unread: boolean;
  title: string;
  body: string;
  time: string;
}

@Entry
@Component
struct NoticesPage {
  @State activeFilter: number = 0;
  private filters: string[] = ['全部·12', '教务·5', '学生处·3', '图书馆·2', '学院·2'];

  private notices: NoticeItem[] = [
    { tag: '教务处', unread: true, title: '2025-2026 学年第一学期期中教学检查通知',
      body: '各教学单位、全体同学：根据校历安排，本周起开展期中教学检查工作...', time: '10·18 · 09:24' },
    { tag: '学生处', unread: true, title: '关于做好秋季校园安全自查的通知',
      body: '秋冬交替时节，宿舍用电安全尤为重要，请同学们...', time: '10·15 · 14:00' },
    { tag: '图书馆', unread: false, title: '《玫瑰与少女》主题书展开放借阅',
      body: '十月馆藏新品 56 册已上架二楼东厅，欢迎品鉴...', time: '10·12' },
    { tag: '软件学院', unread: false, title: '鸿蒙开发综合实践项目验收说明',
      body: '第十周起项目验收正式开始，请各小组按时提交...', time: '10·10' },
    { tag: '教务处', unread: false, title: '重修与缓考申请提交截止提醒',
      body: '本学期缓考申请将于 10·25 24:00 关闭通道...', time: '10·08' }
  ];

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Notices', subtitle: '通 知 公 告' })

        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.filters, (t: string, i?: number) => {
              Button(t)
                .height(28)
                .padding({ left: 12, right: 12 })
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor((i === this.activeFilter) ? Color.White : ElysiaTheme.ROSE_700)
                .backgroundColor((i === this.activeFilter) ? '' : '#B3FFFFFF')
                .linearGradient((i === this.activeFilter) ? {
                  angle: 135,
                  colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
                } : { angle: 0, colors: [['#00FFFFFF', 0]] })
                .borderRadius(999)
                .border({ width: (i === this.activeFilter) ? 0 : 1, color: '#80FFB3CE' })
                .onClick(() => { this.activeFilter = i ?? 0; })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, bottom: 10 })

        List({ space: 10 }) {
          ForEach(this.notices, (n: NoticeItem) => {
            ListItem() {
              this.NoticeCard(n)
            }
          })
        }
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }

  @Builder NoticeCard(n: NoticeItem) {
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
        .border({ width: 1, color: '#80FFB3CE' })

        Column() {
          Row() {
            Pill({ text: n.tag })
            Text('  ' + n.time)
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
          Text(n.body)
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

      if (n.unread) {
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
    .border({ width: 1, color: '#66FFB3CE' })
    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
  }
}
