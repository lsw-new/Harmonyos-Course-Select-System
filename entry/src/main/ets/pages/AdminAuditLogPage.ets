// 操作日志 · Audit Log（按操作类型筛选的操作流水）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { HttpError } from '../common/http/HttpError';
import { AccessControlRepository } from '../repositories/AccessControlRepository';
import { AuditLogEntry } from '../models/AccessControlModels';
import { AUDIT_ACTION_TYPES } from '../mock/mockAccessControl';

@Entry
@Component
struct AdminAuditLogPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State logs: AuditLogEntry[] = [];
  @State activeType: string = '全部';
  // 底部手势条避让（vp）：List 无 TabBar 兜底，需自行留出底部安全区。
  @StorageProp('safeBottom') safeBottom: number = 0;

  private filters: string[] = ['全部'].concat(AUDIT_ACTION_TYPES);

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminAuditLog)) return;
    this.loadLogs();
  }

  private loadLogs(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const filter = this.activeType;
    AccessControlRepository.get().getAuditLogs(filter).then((list: AuditLogEntry[]) => {
      this.logs = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.loading = false;
    });
  }

  private actionTypeColor(type: string): string {
    if (type === '删除') return '#D8546B';
    if (type === '审批') return '#7BB07B';
    if (type === '发布') return ElysiaTheme.GOLD_700;
    if (type === '编辑') return ElysiaTheme.LAV_500;
    if (type === '登录') return ElysiaTheme.ROSE_700;
    return ElysiaTheme.INK_SOFT;
  }

  private actionTypeBg(type: string): string {
    if (type === '删除') return '#FFF0F0';
    if (type === '审批') return '#EAF6EA';
    if (type === '发布') return '#FBF3E2';
    if (type === '编辑') return '#F3ECFF';
    if (type === '登录') return '#FFE9F1';
    return ElysiaTheme.SURFACE_GLOW;
  }

  @Builder FilterChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.filters, (label: string) => {
          Text(label).fontSize(11)
            .fontColor(this.activeType === label ? Color.White : ElysiaTheme.ROSE_700)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(this.activeType === label ? ElysiaTheme.ROSE_500 : '#FFE9F1')
            .borderRadius(999)
            .onClick(() => {
              if (this.activeType === label) return;
              this.activeType = label;
              this.loadLogs();
            })
        }, (label: string, idx: number) => `f-${idx}`)
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    .padding({ left: 16, right: 16 }).margin({ top: 8 })
  }

  @Builder LogRow(log: AuditLogEntry) {
    Column() {
      Row() {
        Pill({ text: log.actionType, color: this.actionTypeColor(log.actionType), bg: this.actionTypeBg(log.actionType) })
        Blank()
        Pill({
          text: log.result === 'success' ? '成功' : '失败',
          color: log.result === 'success' ? '#7BB07B' : '#D8546B',
          bg: log.result === 'success' ? '#EAF6EA' : '#FFF0F0'
        })
      }.width('100%')

      Text(log.action).fontSize(14).fontColor(ElysiaTheme.INK).margin({ top: 8 })
      Text(`对象：${log.target}`).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })

      Row() {
        AppIcon({ name: 'mine', iconSize: 12, dim: true, mRight: 4 })
        Text(`${log.operatorName} · ${log.operatorId}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
        Text(log.ip).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%').margin({ top: 8 })

      Row() {
        AppIcon({ name: 'time', iconSize: 12, dim: true, mRight: 4 })
        Text(log.timestamp).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%').margin({ top: 4 })
    }
    .width('100%').alignItems(HorizontalAlign.Start).padding(14)
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
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
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '操作日志', subtitle: '操 作 日 志', onBack: () => { AppRoute.back(); } })

        this.FilterChips()

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadLogs() })
        } else if (this.logs.length === 0) {
          EmptyState({ icon: 'file', title: '暂无操作日志', hint: '该筛选条件下没有记录' })
        } else {
          List() {
            ForEach(this.logs, (log: AuditLogEntry) => {
              ListItem() {
                this.LogRow(log)
              }.margin({ bottom: 8 })
            }, (log: AuditLogEntry) => `log-${log.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10, bottom: this.safeBottom + 24 }).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%')
    }.width('100%').height('100%')
  }
}
