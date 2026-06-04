// 审批详情 · Approval Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { ApprovalDetail, ApprovalFlowNode } from '../models/Admin';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct AdminApprovalDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State detail: ApprovalDetail | null = null;
  @State comment: string = '';
  @State submitting: boolean = false;
  @State actionError: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private approvalId: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminApprovalDetail)) {
      return;
    }
    this.approvalId = AppRoute.getParam<string>('id', '');
    if (this.approvalId.length === 0) {
      this.errorMsg = '缺少审批 ID';
      this.loading = false;
      return;
    }
    AdminRepository.get().getApprovalDetail(this.approvalId).then((d: ApprovalDetail) => {
      this.detail = d;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private doApprove(): void {
    if (this.comment.trim().length === 0) {
      this.actionError = '请填写处理意见';
      Toast.show(this.getUIContext(), '请填写处理意见');
      return;
    }
    if (this.submitting) return;
    this.submitting = true;
    this.actionError = '';
    AdminRepository.get().approve(this.approvalId, this.comment).then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '已通过');
      AppRoute.back();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
      this.actionError = msg;
      Toast.show(this.getUIContext(), msg);
    });
  }

  private doReject(): void {
    if (this.comment.trim().length === 0) {
      this.actionError = '请填写处理意见';
      Toast.show(this.getUIContext(), '请填写处理意见');
      return;
    }
    if (this.submitting) return;
    this.submitting = true;
    this.actionError = '';
    AdminRepository.get().rejectApproval(this.approvalId, this.comment).then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '已驳回');
      AppRoute.back();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
      this.actionError = msg;
      Toast.show(this.getUIContext(), msg);
    });
  }

  private statusColor(s: string): string {
    if (s === 'pending') return '#D9B675';
    if (s === 'approved') return ElysiaTheme.SUCCESS;
    if (s === 'rejected') return ElysiaTheme.ROSE_ACCENT;
    return ElysiaTheme.INK_MUTE;
  }

  private statusLabel(s: string): string {
    if (s === 'pending') return '待审批';
    if (s === 'approved') return '已通过';
    if (s === 'rejected') return '已驳回';
    if (s === 'withdrawn') return '已撤回';
    return s;
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.adminapprovaldetail_title'), subtitle: $r('app.string.adminapprovaldetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.detail !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Pill({ text: this.detail!.type })
                  if (this.detail!.isUrgent) {
                    Pill({ text: '紧急', color: ElysiaTheme.ROSE_ACCENT, bg: '#FFF0F0' })
                  }
                  Pill({ text: this.statusLabel(this.detail!.status), color: this.statusColor(this.detail!.status), bg: ElysiaTheme.SURFACE_GLOW })
                }
                Text(this.detail!.title)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(`申请时间：${this.detail!.submittedAt}`)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 申请人信息
              Column() {
                Text('申请人信息').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('姓名', this.detail!.applicantName)
                this.InfoRow('学号', this.detail!.applicantId)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 申请内容
              Column() {
                Text('申请内容').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                Text(this.detail!.reason)
                  .fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20).width('100%')
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 审批流程时间线
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

              // 处理意见 + 操作按钮（仅待审状态显示）
              if (this.detail!.status === 'pending') {
                Column({ space: 10 }) {
                  Text('处理意见').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                  TextArea({ placeholder: '请填写处理意见（必填）', text: this.comment })
                    .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
                    .backgroundColor(ElysiaTheme.glass())
                    .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                    .onChange((v: string) => { this.comment = v; this.actionError = ''; })
                  if (this.actionError.length > 0) {
                    Text(this.actionError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
                  }
                  Row({ space: 12 }) {
                    GhostButton({ text: '驳回申请', onTap: () => this.doReject() })
                    PrimaryButton({ text: this.submitting ? '处理中…' : '同意通过', onTap: () => this.doApprove() })
                  }.width('100%')
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              SafeBottom()
            }.padding({ left: 16, right: 16 })
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
export function AdminApprovalDetailPageBuilder() {
  NavDestination() {
    AdminApprovalDetailPage()
  }
  .hideTitleBar(true)
}
