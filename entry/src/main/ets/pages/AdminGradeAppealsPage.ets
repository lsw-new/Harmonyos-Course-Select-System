// 成绩申诉受理 · Admin Grade Appeals
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { AdminRepository } from '../repositories/AdminRepository';
import { GradeAppealItem, GradeAppealStatus } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

interface AppealFilterChip {
  value: string;
  label: string;
}

@Component
struct AdminGradeAppealsPage {
  @State loading: boolean = true;
  @State items: GradeAppealItem[] = [];
  @State errorMsg: string = '';
  @State statusFilter: string = '';
  @State activeId: string = '';
  @State reply: string = '';
  @State decision: string = '';
  @State submitting: boolean = false;
  @State formError: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  private statusChips: AppealFilterChip[] = [
    { value: '', label: '全部' },
    { value: 'pending', label: '待处理' },
    { value: 'accepted', label: '已受理' },
    { value: 'rejected', label: '已驳回' }
  ];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminGradeAppeals)) return;
    this.loadList();
  }

  private loadList(): void {
    this.loading = true;
    this.errorMsg = '';
    AppRoute.showLoading();
    AdminRepository.get().getGradeAppeals(this.statusFilter).then((list: GradeAppealItem[]) => {
      this.items = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      this.loading = false;
    });
  }

  private openHandler(item: GradeAppealItem): void {
    this.activeId = item.appealId;
    this.reply = item.reply.length > 0 ? item.reply : '';
    this.decision = '';
    this.formError = '';
  }

  private closeHandler(): void {
    this.activeId = '';
    this.reply = '';
    this.decision = '';
    this.formError = '';
  }

  private doSave(): void {
    if (this.decision.length === 0) {
      this.formError = '请选择受理或驳回';
      return;
    }
    this.submitting = true;
    AdminRepository.get().handleGradeAppeal(this.activeId, this.decision, this.reply.trim()).then((updated: GradeAppealItem) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '已处理申诉');
      const merged: GradeAppealItem[] = this.items.map((it: GradeAppealItem) => it.appealId === updated.appealId ? updated : it);
      this.items = merged;
      this.closeHandler();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
    });
  }

  private statusLabel(s: GradeAppealStatus): string {
    if (s === 'pending') return '待处理';
    if (s === 'accepted') return '已受理';
    return '已驳回';
  }

  private statusColor(s: GradeAppealStatus): string {
    if (s === 'pending') return ElysiaTheme.ROSE_500;
    if (s === 'accepted') return ElysiaTheme.SUCCESS;
    return ElysiaTheme.INK_MUTE;
  }

  @Builder ChipRow(groupLabel: string, chips: AppealFilterChip[], active: string, onPick: (v: string) => void, keyPrefix: string) {
    Row({ space: 10 }) {
      Text(groupLabel).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width(28)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(chips, (c: AppealFilterChip) => {
            Text(c.label).fontSize(12)
              .fontWeight(active === c.value ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(active === c.value ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(active === c.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.pillBg())
              .border({ width: 1, color: active === c.value ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
              .borderRadius(999)
              .onClick(() => onPick(c.value))
          }, (c: AppealFilterChip) => `${keyPrefix}-${c.value}-${active === c.value}`)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
    }.width('100%')
  }

  @Builder AppealCard(item: GradeAppealItem) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Pill({ text: this.statusLabel(item.status), color: this.statusColor(item.status), bg: '#FFF0F4' })
        Blank()
        Text(item.submittedAt).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%')

      Text(`${item.studentName.length > 0 ? item.studentName : '学生'} · ${item.studentId.length > 0 ? item.studentId : '—'}`)
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')

      Text(`课程 ${item.courseId.length > 0 ? item.courseId : '—'} · ${item.term.length > 0 ? item.term : '—'}`)
        .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width('100%')

      Text(item.reason).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

      if (item.reply.length > 0) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            AppIcon({ name: 'chat', iconSize: 12 })
            Text(`${item.handledBy.length > 0 ? item.handledBy : '管理员'}处理 · ${item.handledAt}`)
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
          }
          Text(item.reply).fontSize(12).fontColor(ElysiaTheme.INK).lineHeight(18)
        }.width('100%').padding(10).backgroundColor('#FFF7FA').borderRadius(10).alignItems(HorizontalAlign.Start)
      }

      Row({ space: 10 }) {
        Blank()
        Text(item.status === 'pending' ? '受理 / 驳回' : '查看')
          .fontSize(12).fontColor(ElysiaTheme.ROSE_500)
          .onClick(() => this.openHandler(item))
      }.width('100%')
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder HandlerPanel(item: GradeAppealItem) {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Pill({ text: this.statusLabel(item.status), color: this.statusColor(item.status), bg: '#FFF0F4' })
        Text(`${item.studentName.length > 0 ? item.studentName : '学生'} · ${item.studentId.length > 0 ? item.studentId : '—'}`)
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(`课程 ${item.courseId.length > 0 ? item.courseId : '—'} · ${item.term.length > 0 ? item.term : '—'} · ${item.submittedAt}`)
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(18)
      .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      Column({ space: 6 }) {
        Text('申诉理由').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        Text(item.reason).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(ElysiaTheme.SURFACE)
      .borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })

      if (item.reply.length > 0) {
        Column({ space: 6 }) {
          Text(`上次处理 · ${item.handledBy.length > 0 ? item.handledBy : '管理员'} · ${item.handledAt}`)
            .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
          Text(item.reply).fontSize(13).fontColor(ElysiaTheme.INK).lineHeight(20)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor('#FFF7FA').borderRadius(14)
        .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
      }

      if (item.status === 'pending') {
        Column({ space: 8 }) {
          Text('处理回复（可选）').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
          TextArea({ placeholder: '请输入处理说明，会同步给学生', text: this.reply })
            .height(110).fontSize(13).fontColor(ElysiaTheme.INK)
            .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
            .onChange((v: string) => { this.reply = v; })

          Text('处理结果').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
          Row({ space: 8 }) {
            Text('受理').fontSize(12)
              .fontWeight(this.decision === 'accepted' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.decision === 'accepted' ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.decision === 'accepted' ? ElysiaTheme.SUCCESS : ElysiaTheme.pillBg())
              .border({ width: 1, color: this.decision === 'accepted' ? ElysiaTheme.SUCCESS : ElysiaTheme.hairline() })
              .borderRadius(999)
              .onClick(() => { this.decision = 'accepted'; })
            Text('驳回').fontSize(12)
              .fontWeight(this.decision === 'rejected' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.decision === 'rejected' ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.decision === 'rejected' ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.pillBg())
              .border({ width: 1, color: this.decision === 'rejected' ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.hairline() })
              .borderRadius(999)
              .onClick(() => { this.decision = 'rejected'; })
          }

          if (this.formError.length > 0) {
            Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
          }

          Row({ space: 12 }) {
            GhostButton({ text: '取消', onTap: () => this.closeHandler() })
            PrimaryButton({ text: this.submitting ? '提交中...' : '提交处理', onTap: () => this.doSave() })
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(ElysiaTheme.SURFACE)
        .borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
      } else {
        Row({ space: 12 }) {
          GhostButton({ text: '返回', onTap: () => this.closeHandler() })
        }.width('100%')
      }

      SafeBottom()
    }.padding({ left: 16, right: 16 })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({
          title: '成绩申诉',
          subtitle: '受理学生成绩申诉',
          showBack: true,
          onBack: () => {
            if (this.activeId.length > 0) {
              this.closeHandler();
            } else {
              AppRoute.back();
            }
          }
        })

        if (this.activeId.length === 0) {
          Column({ space: 10 }) {
            this.ChipRow('状态', this.statusChips, this.statusFilter, (v: string) => {
              this.statusFilter = v;
              this.loadList();
            }, 'gast')
          }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor(ElysiaTheme.SURFACE).borderRadius(16)
          .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
          .shadow({ radius: 10, color: '#14D8546B', offsetX: 0, offsetY: 3 })
          .margin({ left: 16, right: 16, top: 8 })

          if (this.loading) {
            Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.errorMsg.length > 0) {
            Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadList() }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else if (this.items.length === 0) {
            Column() { EmptyState({ title: '暂无申诉' }) }
              .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            List({ space: 10 }) {
              ForEach(this.items, (item: GradeAppealItem) => {
                ListItem() {
                  this.AppealCard(item)
                }
              }, (item: GradeAppealItem) => item.appealId)
            }.layoutWeight(1).padding({ left: 16, right: 16, top: 6, bottom: 16 })
          }
        } else {
          Scroll() {
            this.HandlerPanel(this.items.find((it: GradeAppealItem) => it.appealId === this.activeId) ?? this.items[0])
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }.width('100%').height('100%').constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminGradeAppealsPageBuilder() {
  NavDestination() {
    AdminGradeAppealsPage()
  }
  .hideTitleBar(true)
}
