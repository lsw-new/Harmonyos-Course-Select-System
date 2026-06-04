// 审计日志详情 · Audit Log Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AccessControlRepository } from '../repositories/AccessControlRepository';
import { AuditLogEntry } from '../models/AccessControlModels';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct AuditLogDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State log: AuditLogEntry | null = null;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AuditLogDetail)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少日志 ID';
      this.loading = false;
      return;
    }
    AccessControlRepository.get().getAuditLogs().then((list: AuditLogEntry[]) => {
      const found = list.find((l: AuditLogEntry) => l.id === id);
      if (!found) {
        this.errorMsg = '日志记录不存在';
      } else {
        this.log = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private resultColor(r: string): string {
    return r === 'success' ? ElysiaTheme.SUCCESS : ElysiaTheme.ROSE_ACCENT;
  }

  private resultLabel(r: string): string {
    return r === 'success' ? '成功' : '失败';
  }

  private actionTypeColor(type: string): string {
    if (type === '删除') return ElysiaTheme.ROSE_ACCENT;
    if (type === '审批') return ElysiaTheme.SUCCESS;
    if (type === '发布') return ElysiaTheme.GOLD_700;
    if (type === '编辑') return ElysiaTheme.LAV_500;
    if (type === '登录') return ElysiaTheme.ROSE_700;
    return ElysiaTheme.INK_SOFT;
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
        TopBar({ title: $r('app.string.auditlogdetail_title'), subtitle: $r('app.string.auditlogdetail_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.log !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 区
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Pill({ text: this.log!.actionType, color: this.actionTypeColor(this.log!.actionType), bg: ElysiaTheme.SURFACE_GLOW })
                  Pill({
                    text: this.resultLabel(this.log!.result),
                    color: this.resultColor(this.log!.result),
                    bg: this.log!.result === 'success' ? '#EAF6EA' : '#FFF0F0'
                  })
                }
                Text(this.log!.action)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(`操作时间：${this.log!.timestamp}`)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 操作者信息
              Column() {
                Text('操作者').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('姓名', this.log!.operatorName)
                this.InfoRow('账号', this.log!.operatorId)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 操作详情
              Column() {
                Text('操作详情').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('操作对象', this.log!.target)
                this.InfoRow('操作类型', this.log!.actionType)
                this.InfoRow('IP 地址', this.log!.ip)
                this.InfoRow('执行结果', this.resultLabel(this.log!.result))
                this.InfoRow('操作时间', this.log!.timestamp)
                this.InfoRow('日志编号', this.log!.id)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 变更差异说明：AuditLogEntry 无变更前/后字段，此处不显示差异块。
              Column() {
                Row({ space: 8 }) {
                  Column()
                    .width(10).height(38).borderRadius(6)
                    .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
                  Column({ space: 4 }) {
                    Row({ space: 6 }) {
                      Text($r('app.string.auditlogdetail_diff_title')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                      Pill({ text: $r('app.string.auditlogdetail_diff_na') })
                    }
                    Text($r('app.string.auditlogdetail_diff_hint'))
                      .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(18)
                .shadow({ radius: 12, color: '#18D85487', offsetX: 0, offsetY: 4 })
              }.width('100%')

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.auditlogdetail_back'), onTap: () => AppRoute.back() })
                PrimaryButton({ text: $r('app.string.auditlogdetail_copy_id'), onTap: () => Toast.show(this.getUIContext(), '已复制') })
              }.width('100%')

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
export function AuditLogDetailPageBuilder() {
  NavDestination() {
    AuditLogDetailPage()
  }
  .hideTitleBar(true)
}
