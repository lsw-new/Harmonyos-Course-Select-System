// 学生管理 · Étudiants
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, ElysiaInput } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { StudentAdminRepository } from '../repositories/StudentAdminRepository';
import { StudentAdminItem } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { EmptyState, ErrorState } from '../common/widgets/StateViews';
import { SkeletonList } from '../common/widgets/Skeleton';
import { ArrayDataSource } from '../common/widgets/DataSource';
import { AppIcon } from '../common/widgets/AppIcon';
import { SafeTop } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminStudentsPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State query: string = '';
  @State students: StudentAdminItem[] = [];
  @State activeCollege: string = '全部';
  @StorageProp('breakpoint') bp: string = 'sm';
  private colleges: string[] = ['全部', '电子信息工程学院', '陶瓷艺术学院', '设计艺术学院', '美术学院', '音乐舞蹈学院'];
  private studentsDs: ArrayDataSource<StudentAdminItem> = new ArrayDataSource<StudentAdminItem>();

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminStudents)) return;
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    StudentAdminRepository.get().getStudents(this.query, this.activeCollege).then((list: StudentAdminItem[]) => {
      this.students = list;
      this.studentsDs.setData(list);
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private statusColor(s: string): string {
    if (s === 'active') return ElysiaTheme.SUCCESS;
    if (s === 'graduating') return '#D9B675';
    if (s === 'suspended') return ElysiaTheme.ROSE_ACCENT;
    return ElysiaTheme.INK_MUTE;
  }

  private statusLabel(s: string): string {
    if (s === 'active') return '在读';
    if (s === 'graduating') return '毕业班';
    if (s === 'suspended') return '休学';
    return '已毕业';
  }

  private openDetail(item: StudentAdminItem): void {
    const p: Record<string, Object> = { 'studentId': item.studentId };
    AppRoute.go(Routes.AdminStudentDetail, { params: p });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '学生管理', subtitle: '学 生 管 理', showBack: false })

        Column({ space: 10 }) {
          TextInput({ placeholder: '搜索学号/姓名/班级', text: this.query })
            .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
            .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
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
          SkeletonList({ count: 6 })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.students.length === 0) {
          EmptyState({ title: '无匹配学生' })
        } else {
          List() {
            LazyForEach(this.studentsDs, (s: StudentAdminItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(s.name).fontSize(14).fontColor(ElysiaTheme.INK)
                    Text(`${s.studentId} · ${s.className}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                    Text(`${s.college} · 绩点 ${s.gpa ?? '—'}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Pill({ text: this.statusLabel(s.status), color: this.statusColor(s.status), bg: '#FFF6FA' })
                  AppIcon({ name: 'forward', iconSize: 16, mLeft: 8, dim: true })
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                .onClick(() => { this.openDetail(s); })
              }.margin({ bottom: 8 })
            }, (s: StudentAdminItem) => s.studentId)
          }.layoutWeight(1).cachedCount(6).padding({ left: 16, right: 16, top: 10 })
        }

        AdminTabBar({ active: 'students', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }.width('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminStudentsPageBuilder() {
  NavDestination() {
    AdminStudentsPage()
  }
  .hideTitleBar(true)
}
