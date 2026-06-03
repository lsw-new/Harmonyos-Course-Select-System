// 审批中心 · Approbations
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AppIcon } from '../common/widgets/AppIcon';
import { AdminRepository } from '../repositories/AdminRepository';
import { ApprovalItem, ApprovalDetail, ApprovalFlowNode } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminApprovalsPage {
  @State loading: boolean = true;
  @State approvals: ApprovalItem[] = [];
  @State activeStatus: string = '全部';
  @State activeId: string = '';
  @State detail: ApprovalDetail | null = null;
  @State detailLoading: boolean = false;
  @State detailError: string = '';
  @State comment: string = '';
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State successMsg: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private statuses: string[] = ['全部', 'pending', 'approved', 'rejected', 'withdrawn'];
  private statusLabels: string[] = ['全部', '待审', '通过', '驳回', '撤回'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminApprovals)) return;
    this.loadList();
  }

  private loadList(): void {
    this.loading = true;
    AppRoute.showLoading();
    const s = this.activeStatus === '全部' ? '全部' : this.activeStatus;
    AdminRepository.get().getApprovals(s as 'pending' | 'approved' | 'rejected' | 'withdrawn' | '全部').then((list: ApprovalItem[]) => {
      this.approvals = list;
      this.loading = false;
      // Deep-link: open detail if an id param was passed
      const id: string = AppRoute.getParam<string>('id', '');
      if (id.length > 0) {
        this.openDetail(id);
      }
    }).catch(() => { this.loading = false; });
  }

  private openDetail(id: string): void {
    this.activeId = id;
    this.detailLoading = true;
    this.detailError = '';
    this.comment = '';
    this.errorMsg = '';
    this.successMsg = '';
    AdminRepository.get().getApprovalDetail(id).then((d: ApprovalDetail) => {
      this.detail = d;
      this.detailLoading = false;
    }).catch((e: object) => {
      this.detailError = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.detailLoading = false;
    });
  }

  private doApprove(): void {
    if (this.comment.trim().length === 0) { this.errorMsg = '请填写审批意见'; return; }
    this.submitting = true;
    AdminRepository.get().approve(this.activeId, this.comment).then(() => {
      this.submitting = false;
      this.successMsg = '已通过';
      Toast.show(this.getUIContext(), '已通过');
      this.activeId = '';
      this.loadList();
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
    });
  }

  private doReject(): void {
    if (this.comment.trim().length === 0) { this.errorMsg = '请填写驳回意见'; return; }
    this.submitting = true;
    AdminRepository.get().rejectApproval(this.activeId, this.comment).then(() => {
      this.submitting = false;
      this.successMsg = '已驳回';
      Toast.show(this.getUIContext(), '已驳回');
      this.activeId = '';
      this.loadList();
    }).catch((e: object) => {
      this.submitting = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
    });
  }

  private statusColor(s: string): string {
    if (s === 'pending') return '#D9B675';
    if (s === 'approved') return ElysiaTheme.SUCCESS;
    if (s === 'rejected') return ElysiaTheme.ROSE_ACCENT;
    return ElysiaTheme.INK_MUTE;
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '审批中心', subtitle: '审 批 中 心', showBack: this.activeId.length > 0,
          onBack: () => { this.activeId = ''; } })

        if (this.activeId.length === 0) {
          // 列表视图
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.statusLabels, (label: string, idx: number) => {
                Text(label).fontSize(11)
                  .fontColor(this.activeStatus === this.statuses[idx] ? Color.White : ElysiaTheme.ROSE_700)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor(this.activeStatus === this.statuses[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                  .borderRadius(999)
                  .onClick(() => { this.activeStatus = this.statuses[idx]; this.loadList(); })
              }, (label: string, idx: number) => `s-${idx}`)
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).padding({ left: 16, right: 16 }).margin({ top: 8 })

          if (this.loading) {
            LoadingState({})
          } else if (this.approvals.length === 0) {
            EmptyState({ title: '暂无审批' })
          } else {
            List() {
              ForEach(this.approvals, (a: ApprovalItem) => {
                ListItem() {
                  Row() {
                    Column() {
                      Row({ space: 6 }) {
                        Pill({ text: a.type, color: ElysiaTheme.ROSE_700, bg: '#FFE9F1' })
                        if (a.isUrgent) { Pill({ text: '紧急', color: ElysiaTheme.ROSE_ACCENT, bg: '#FFF0F0' }) }
                      }
                      Text(a.title).fontSize(14).fontColor(ElysiaTheme.INK).margin({ top: 6 })
                      Text(`${a.applicantName} · ${a.submittedAt}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    AppIcon({ name: 'forward', iconSize: 16 })
                  }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                  .onClick(() => { this.openDetail(a.id); })
                }.margin({ bottom: 8 })
              }, (a: ApprovalItem) => a.id)
            }.layoutWeight(1).padding({ left: 16, right: 16, top: 10 })
          }

          AdminTabBar({ active: 'approvals', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
        } else {
          // 详情视图
          if (this.detailLoading) {
            LoadingState({})
          } else if (this.detailError.length > 0) {
            ErrorState({ message: this.detailError, onRetry: () => this.openDetail(this.activeId) })
          } else if (this.detail !== null) {
            Scroll() {
              Column({ space: 14 }) {
                Column() {
                  Pill({ text: this.detail!.type })
                  Text(this.detail!.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).margin({ top: 8 })
                  Text(`申请人：${this.detail!.applicantName} (${this.detail!.applicantId})`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
                  Text(`事由：${this.detail!.reason}`).fontSize(13).fontColor(ElysiaTheme.INK).margin({ top: 8 }).lineHeight(20)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

                // 流程时间线
                Column() {
                  Text('审批流程').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                  ForEach(this.detail!.flow, (node: ApprovalFlowNode) => {
                    Row({ space: 10 }) {
                      Column().width(10).height(10).borderRadius(5)
                        .backgroundColor(this.statusColor(node.status))
                      Column() {
                        Text(node.nodeName).fontSize(13).fontColor(ElysiaTheme.INK)
                        if (node.operatorName) {
                          Text(`${node.operatorName} · ${node.handledAt ?? ''}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                        }
                        if (node.comment) {
                          Text(node.comment).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
                        }
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    }.width('100%').padding({ top: 8, bottom: 8 })
                    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
                  }, (node: ApprovalFlowNode) => node.id)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

                // 审批操作
                if (this.detail!.status === 'pending') {
                  Column({ space: 10 }) {
                    TextArea({ placeholder: '审批意见（必填）', text: this.comment })
                      .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
                      .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                      .onChange((v: string) => { this.comment = v; })
                    if (this.errorMsg.length > 0) {
                      Text(this.errorMsg).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
                    }
                    Row({ space: 12 }) {
                      GhostButton({ text: '驳回', onTap: () => this.doReject() })
                      PrimaryButton({ text: this.submitting ? '处理中...' : '同意通过', onTap: () => this.doApprove() })
                    }.width('100%')
                  }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                  .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                }

                SafeBottom()
              }.padding({ left: 16, right: 16 })
            }.scrollBar(BarState.Off).layoutWeight(1)
          }
        }
      }.width('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminApprovalsPageBuilder() {
  NavDestination() {
    AdminApprovalsPage()
  }
  .hideTitleBar(true)
}
