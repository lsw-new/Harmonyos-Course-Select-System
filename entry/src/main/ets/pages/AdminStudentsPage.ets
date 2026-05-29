// 学生管理 · Étudiants
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, ElysiaInput } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { StudentAdminItem } from '../models/Admin';
import { AppRoute } from '../app/AppRoute';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';

@Entry
@Component
struct AdminStudentsPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State query: string = '';
  @State students: StudentAdminItem[] = [];
  @State activeCollege: string = '全部';
  private colleges: string[] = ['全部', '人文与艺术学院', '计算机学院', '艺术学院', '数学学院'];

  aboutToAppear(): void { this.loadData(); }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    AdminRepository.get().getStudents(this.query, this.activeCollege).then((list: StudentAdminItem[]) => {
      this.students = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private statusColor(s: string): string {
    if (s === 'active') return '#7BB07B';
    if (s === 'graduating') return '#D9B675';
    if (s === 'suspended') return '#D8546B';
    return ElysiaTheme.INK_MUTE;
  }

  private statusLabel(s: string): string {
    if (s === 'active') return '在读';
    if (s === 'graduating') return '毕业班';
    if (s === 'suspended') return '休学';
    return '已毕业';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Students', subtitle: '学 生 管 理', showBack: false })

        Column({ space: 10 }) {
          TextInput({ placeholder: '搜索学号/姓名/班级', text: this.query })
            .height(40).fontSize(13).backgroundColor('#CCFFFFFF')
            .border({ width: 1, color: '#80FFB3CE' }).borderRadius(14)
            .onChange((v: string) => { this.query = v; this.loadData(); })

          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.colleges, (c: string) => {
                Text(c).fontSize(11)
                  .fontColor(this.activeCollege === c ? Color.White : ElysiaTheme.ROSE_700)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor(this.activeCollege === c ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                  .borderRadius(999)
                  .onClick(() => { this.activeCollege = c; this.loadData(); })
              }, (c: string) => c)
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }.padding({ left: 16, right: 16 })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.students.length === 0) {
          EmptyState({ title: '无匹配学生' })
        } else {
          List() {
            ForEach(this.students, (s: StudentAdminItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(s.name).fontSize(14).fontColor(ElysiaTheme.INK)
                    Text(`${s.studentId} · ${s.className}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                    Text(`${s.college} · GPA ${s.gpa ?? '—'}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Pill({ text: this.statusLabel(s.status), color: this.statusColor(s.status), bg: '#FFF6FA' })
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: '#66FFB3CE' })
              }.margin({ bottom: 8 })
            }, (s: StudentAdminItem) => s.studentId)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10 })
        }

        AdminTabBar({ active: 'students', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }
    }.width('100%').height('100%')
  }
}
