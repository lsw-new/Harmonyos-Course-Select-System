// 成绩审核 · Notes
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { GradeAuditItem } from '../models/Admin';
import { LoadingState, EmptyState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';

@Entry
@Component
struct AdminGradesPage {
  @State loading: boolean = true;
  @State items: GradeAuditItem[] = [];
  @State activeStatus: string = '全部';
  @State errorMsg: string = '';
  private statuses: string[] = ['全部', 'pendingAudit', 'inputting', 'published', 'appealed'];
  private statusLabels: string[] = ['全部', '待审核', '录入中', '已发布', '异议'];

  aboutToAppear(): void { this.loadData(); }

  private loadData(): void {
    this.loading = true;
    const s = this.activeStatus === '全部' ? undefined : this.activeStatus;
    AdminRepository.get().getGradeAudits(s).then((list: GradeAuditItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch(() => { this.loading = false; });
  }

  private approve(id: string): void {
    AdminRepository.get().approveGrade(id).then(() => {
      this.loadData();
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '审核失败';
    });
  }

  private statusColor(s: string): string {
    if (s === 'pendingAudit') return '#D9B675';
    if (s === 'inputting') return ElysiaTheme.ROSE_500;
    if (s === 'published') return '#7BB07B';
    return '#D8546B';
  }

  private statusText(s: string): string {
    if (s === 'pendingAudit') return '待审核';
    if (s === 'inputting') return '录入中';
    if (s === 'published') return '已发布';
    return '异议';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Notes', subtitle: '成 绩 管 理', onBack: () => router.back() })

        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.statusLabels, (label: string, idx: number) => {
              Text(label).fontSize(11)
                .fontColor(this.activeStatus === this.statuses[idx] ? Color.White : ElysiaTheme.ROSE_700)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.activeStatus === this.statuses[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                .borderRadius(999)
                .onClick(() => { this.activeStatus = this.statuses[idx]; this.loadData(); })
            }, (label: string, idx: number) => `gs-${idx}`)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).padding({ left: 16, right: 16 }).margin({ top: 8 })

        if (this.errorMsg.length > 0) {
          Text(this.errorMsg).fontSize(12).fontColor('#D8546B').padding({ left: 16, top: 6 })
        }

        if (this.loading) {
          LoadingState({})
        } else if (this.items.length === 0) {
          EmptyState({ title: '暂无成绩记录' })
        } else {
          List() {
            ForEach(this.items, (item: GradeAuditItem) => {
              ListItem() {
                Column({ space: 6 }) {
                  Row() {
                    Text(item.courseName).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: this.statusText(item.status), color: this.statusColor(item.status), bg: '#FFF6FA' })
                  }.width('100%')
                  Text(`${item.teachingClassName} · ${item.teacherName}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  Row() {
                    Column().height(6).width(`${item.inputProgress}%`).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(3)
                  }.width('100%').height(6).backgroundColor('#FFE9F1').borderRadius(3)
                  Row() {
                    Text(`录入 ${item.inputProgress}%`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                    if (item.status === 'pendingAudit') {
                      Text('审核通过').fontSize(11).fontColor(Color.White)
                        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                        .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                        .onClick(() => { this.approve(item.id); })
                    }
                  }.width('100%')
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: '#66FFB3CE' })
              }.margin({ bottom: 8 })
            }, (item: GradeAuditItem) => item.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10 })
        }
      }
    }.width('100%').height('100%')
  }
}
