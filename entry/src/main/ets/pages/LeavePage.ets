// 请假申请 · Leave
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, PrimaryButton, ElysiaInput, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { LeaveRequest } from '../models/Misc';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute } from '../app/AppRoute';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct LeavePage {
  @State activeTab: number = 0;
  @State leaveType: string = 'sick';
  @State startDate: string = '';
  @State endDate: string = '';
  @State reason: string = '';
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @State loading: boolean = true;
  @State historyErrorMsg: string = '';
  @State history: LeaveRequest[] = [];
  @StorageProp('darkMode') darkMode: boolean = false;

  private typeLabels: string[] = ['病假', '事假', '公假', '其他'];
  private typeKeys: string[] = ['sick', 'personal', 'public', 'other'];

  aboutToAppear(): void {
    this.loadHistory();
  }

  private loadHistory(): void {
    this.loading = true;
    this.historyErrorMsg = '';
    ProfileRepository.get().getLeaveRequests().then((list: LeaveRequest[]) => {
      this.history = list;
      this.loading = false;
    }).catch((e: object) => {
      this.historyErrorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private submit(): void {
    if (this.submitting) return;
    if (this.startDate.length === 0 || this.endDate.length === 0) {
      this.errorMsg = '请填写起止日期';
      return;
    }
    if (this.reason.trim().length === 0) {
      this.errorMsg = '请填写请假事由';
      return;
    }
    this.errorMsg = '';
    this.successMsg = '';
    this.submitting = true;
    ProfileRepository.get().submitLeave({
      type: this.leaveType as 'sick' | 'personal' | 'public' | 'other',
      startDate: this.startDate,
      endDate: this.endDate,
      reason: this.reason,
      attachments: []
    }).then(() => {
      this.submitting = false;
      this.successMsg = '申请已提交';
      this.reason = '';
      this.startDate = '';
      this.endDate = '';
      this.loadHistory();
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '提交失败';
    });
  }

  private stateColor(state: string): string {
    if (state === 'approved') return '#7BB07B';
    if (state === 'rejected') return '#D8546B';
    if (state === 'pending') return '#D9B675';
    return ElysiaTheme.INK_MUTE;
  }

  private stateLabel(state: string): string {
    if (state === 'approved') return '已通过';
    if (state === 'rejected') return '已驳回';
    if (state === 'pending') return '审批中';
    return '已撤回';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient(this.darkMode) })

      Column() {
        SafeTop()
        TopBar({ title: 'Leave', subtitle: '请 假 申 请', onBack: () => AppRoute.back() })

        Row({ space: 0 }) {
          Text('新建申请').fontSize(13)
            .fontColor(this.activeTab === 0 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 0 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => {
              this.activeTab = 0;
              this.successMsg = '';
            })
          Text('我的申请').fontSize(13)
            .fontColor(this.activeTab === 1 ? ElysiaTheme.ROSE_700 : ElysiaTheme.INK_MUTE)
            .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .border({ width: { bottom: 2 }, color: this.activeTab === 1 ? ElysiaTheme.ROSE_500 : '#00000000' })
            .onClick(() => {
              this.activeTab = 1;
              this.successMsg = '';
            })
        }.width('100%').padding({ left: 16 })

        Scroll() {
          Column({ space: 14 }) {
            if (this.activeTab === 0) {
              Row({ space: 8 }) {
                ForEach(this.typeLabels, (label: string, idx: number) => {
                  Text(label).fontSize(12)
                    .fontColor(this.leaveType === this.typeKeys[idx] ? Color.White : ElysiaTheme.ROSE_700)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.leaveType === this.typeKeys[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                    .borderRadius(999)
                    .onClick(() => { this.leaveType = this.typeKeys[idx]; })
                }, (label: string, idx: number) => `type-${idx}`)
              }.width('100%').margin({ top: 4 })

              ElysiaInput({ placeholder: '开始日期 (YYYY-MM-DD)', value: $startDate, leadingIcon: 'calendar' })
              ElysiaInput({ placeholder: '结束日期 (YYYY-MM-DD)', value: $endDate, leadingIcon: 'calendar' })

              TextArea({ placeholder: '请假事由', text: this.reason })
                .height(100).fontSize(13).fontColor(ElysiaTheme.INK)
                .backgroundColor(ElysiaTheme.glass(this.darkMode)).border({ width: 1, color: ElysiaTheme.hairline(this.darkMode) }).borderRadius(14)
                .onChange((v: string) => { this.reason = v; })

              if (this.errorMsg.length > 0) {
                Text(this.errorMsg).fontSize(12).fontColor('#D8546B')
              }
              if (this.successMsg.length > 0) {
                Text(this.successMsg).fontSize(12).fontColor('#7BB07B')
              }

              PrimaryButton({ text: this.submitting ? '提交中...' : '提交申请', onTap: () => this.submit() })
            } else {
              if (this.loading) {
                LoadingState({ tip: '正在加载...' })
              } else if (this.historyErrorMsg.length > 0) {
                ErrorState({ message: this.historyErrorMsg, onRetry: () => this.loadHistory() })
              } else if (this.history.length === 0) {
                EmptyState({ title: '暂无申请记录' })
              } else {
                ForEach(this.history, (item: LeaveRequest) => {
                  Row() {
                    Column() {
                      Text(`${item.startDate} ~ ${item.endDate}`).fontSize(13).fontColor(ElysiaTheme.INK)
                      Text(item.reason).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 }).maxLines(2)
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Pill({ text: this.stateLabel(item.state), color: this.stateColor(item.state), bg: '#FFF6FA' })
                  }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) })
                }, (item: LeaveRequest) => item.id)
              }
            }
            SafeBottom()
          }.padding({ left: 16, right: 16, top: 12 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
