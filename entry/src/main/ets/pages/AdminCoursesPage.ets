// 课程管理 · Cours
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, ElysiaInput } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminCourseItem } from '../models/Admin';
import { AppRoute } from '../app/AppRoute';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';

@Entry
@Component
struct AdminCoursesPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State query: string = '';
  @State courses: AdminCourseItem[] = [];
  @State activeCategory: string = '全部';
  private categories: string[] = ['全部', 'required', 'elective', 'public', 'practice'];
  private catLabels: string[] = ['全部', '必修', '选修', '公选', '实践'];

  aboutToAppear(): void { this.loadData(); }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    const cat = this.activeCategory === '全部' ? undefined : this.activeCategory;
    AdminRepository.get().getCourses(this.query, cat).then((list: AdminCourseItem[]) => {
      this.courses = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private statusLabel(s: string): string {
    if (s === 'open') return '开课中';
    if (s === 'closed') return '已关闭';
    if (s === 'draft') return '草稿';
    return '归档';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Cours', subtitle: '课 程 管 理', showBack: false })

        Column({ space: 10 }) {
          TextInput({ placeholder: '搜索课程/课号/教师', text: this.query })
            .height(40).fontSize(13).backgroundColor('#CCFFFFFF')
            .border({ width: 1, color: '#80FFB3CE' }).borderRadius(14)
            .onChange((v: string) => { this.query = v; this.loadData(); })

          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.catLabels, (label: string, idx: number) => {
                Text(label).fontSize(11)
                  .fontColor(this.activeCategory === this.categories[idx] ? Color.White : ElysiaTheme.ROSE_700)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor(this.activeCategory === this.categories[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                  .borderRadius(999)
                  .onClick(() => { this.activeCategory = this.categories[idx]; this.loadData(); })
              }, (label: string, idx: number) => this.categories[idx])
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }.padding({ left: 16, right: 16 })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.courses.length === 0) {
          EmptyState({ title: '无匹配课程' })
        } else {
          List() {
            ForEach(this.courses, (c: AdminCourseItem) => {
              ListItem() {
                Column({ space: 6 }) {
                  Row() {
                    Text(c.name).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: this.statusLabel(c.status), color: c.status === 'open' ? '#7BB07B' : ElysiaTheme.INK_MUTE, bg: '#FFF6FA' })
                  }.width('100%')
                  Text(`${c.code} · ${c.teacher} · ${c.credit} 学分 · ${c.timeText}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  // 容量进度条
                  Row() {
                    Column().height(6).width(`${Math.min(c.selectedCount / c.capacity * 100, 100)}%`)
                      .backgroundColor(c.selectedCount >= c.capacity ? '#D8546B' : ElysiaTheme.ROSE_500).borderRadius(3)
                  }.width('100%').height(6).backgroundColor('#FFE9F1').borderRadius(3)
                  Text(`${c.selectedCount}/${c.capacity}`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: '#66FFB3CE' })
              }.margin({ bottom: 8 })
            }, (c: AdminCourseItem) => c.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10 })
        }

        AdminTabBar({ active: 'courses', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }
    }.width('100%').height('100%')
  }
}
