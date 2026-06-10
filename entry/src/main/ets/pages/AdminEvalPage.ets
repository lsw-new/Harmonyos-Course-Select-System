// 评教管理 · Évaluation
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput, RoseDivider } from '../common/Components';
import { EvalAdminRepository } from '../repositories/EvalAdminRepository';
import {
  EvalAdminStats, RatingBucket, QuestionnaireTemplate, TemplateWritePayload, TemplateStatus
} from '../models/EvalAdminModels';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { BreakpointManager } from '../common/widgets/Breakpoint';

const BAR_LABELS: string[] = ['5 星', '4 星', '3 星', '2 星', '1 星'];

@Component
struct AdminEvalPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State periodSubmitting: boolean = false;
  @State errorMsg: string = '';
  @State formError: string = '';
  @State stats: EvalAdminStats | null = null;
  @State templates: QuestionnaireTemplate[] = [];
  @State isEditing: boolean = false;
  @State editingId: string = '';
  @State name: string = '';
  @State description: string = '';
  @State questionCountText: string = '10';
  @State status: string = 'enabled';
  @State pendingDeleteId: string = '';
  private statuses: string[] = ['enabled', 'disabled'];
  private statusLabels: string[] = ['启用', '停用'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminEval)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const repo = EvalAdminRepository.get();
    Promise.all([repo.getStats(), repo.getTemplates()]).then((res: [EvalAdminStats, QuestionnaireTemplate[]]) => {
      this.stats = res[0];
      this.templates = res[1];
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private templateStatusLabel(s: string): string {
    return s === 'enabled' ? '启用' : '停用';
  }

  private templateStatusColor(s: string): string {
    return s === 'enabled' ? ElysiaTheme.SUCCESS : ElysiaTheme.INK_MUTE;
  }

  private resetForm(): void {
    this.editingId = '';
    this.name = '';
    this.description = '';
    this.questionCountText = '10';
    this.status = 'enabled';
    this.formError = '';
  }

  private openCreate(): void {
    this.pendingDeleteId = '';
    this.resetForm();
    this.isEditing = true;
  }

  private openEdit(t: QuestionnaireTemplate): void {
    this.pendingDeleteId = '';
    this.editingId = t.id;
    this.name = t.name;
    this.description = t.description;
    this.questionCountText = `${t.questionCount}`;
    this.status = t.status;
    this.formError = '';
    this.isEditing = true;
  }

  private cancelEdit(): void {
    this.isEditing = false;
    this.resetForm();
  }

  private toCount(value: string): number {
    const parsed = Number(value.trim());
    if (parsed !== parsed || parsed === Infinity || parsed === -Infinity) {
      return -1;
    }
    return parsed;
  }

  private buildPayload(): TemplateWritePayload | null {
    const count = this.toCount(this.questionCountText);
    if (count < 1 || count > 50 || Math.floor(count) !== count) {
      this.formError = '题目数量需为 1-50 的整数';
      return null;
    }
    const payload: TemplateWritePayload = {
      name: this.name,
      description: this.description,
      questionCount: count,
      status: this.status as TemplateStatus
    };
    return payload;
  }

  private saveTemplate(): void {
    if (this.submitting) {
      return;
    }
    const payload = this.buildPayload();
    if (payload === null) {
      return;
    }
    this.submitting = true;
    this.formError = '';
    const repo = EvalAdminRepository.get();
    const action = this.editingId.length > 0 ? repo.updateTemplate(this.editingId, payload) : repo.createTemplate(payload);
    action.then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), this.editingId.length > 0 ? '问卷已更新' : '问卷已新增');
      this.cancelEdit();
      this.loadTemplates();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  private loadTemplates(): void {
    EvalAdminRepository.get().getTemplates().then((list: QuestionnaireTemplate[]) => {
      this.templates = list;
    }).catch((e: object) => {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  private requestDelete(t: QuestionnaireTemplate): void {
    if (this.submitting) {
      return;
    }
    this.pendingDeleteId = t.id;
  }

  private cancelDelete(): void {
    this.pendingDeleteId = '';
  }

  private deleteTemplate(t: QuestionnaireTemplate): void {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    EvalAdminRepository.get().deleteTemplate(t.id).then(() => {
      this.submitting = false;
      this.pendingDeleteId = '';
      Toast.show(this.getUIContext(), '问卷已删除');
      if (this.editingId === t.id) {
        this.cancelEdit();
      }
      this.loadTemplates();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '删除失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  private setPeriod(open: boolean): void {
    if (this.periodSubmitting) {
      return;
    }
    const current = this.stats;
    if (current === null || current.periodOpen === open) {
      return;
    }
    this.periodSubmitting = true;
    EvalAdminRepository.get().setPeriodOpen(open).then(() => {
      this.periodSubmitting = false;
      const s = this.stats;
      if (s !== null) {
        const next: EvalAdminStats = {
          term: s.term,
          periodOpen: open,
          participationRate: s.participationRate,
          completionRate: s.completionRate,
          averageScore: s.averageScore,
          ratingDistribution: s.ratingDistribution
        };
        this.stats = next;
      }
      Toast.show(this.getUIContext(), open ? '评教期已开放' : '评教期已关闭');
    }).catch((e: object) => {
      this.periodSubmitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '操作失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  private totalRatings(buckets: RatingBucket[]): number {
    let total = 0;
    for (let i = 0; i < buckets.length; i++) {
      total += buckets[i].count;
    }
    return total;
  }

  private barWidth(count: number, total: number): string {
    if (total <= 0) {
      return '0%';
    }
    const pct = Math.round(count / total * 100);
    return `${pct}%`;
  }

  private barColor(star: number): string {
    if (star >= 5) return ElysiaTheme.ROSE_500;
    if (star === 4) return ElysiaTheme.LAV_500;
    if (star === 3) return ElysiaTheme.GOLD_500;
    if (star === 2) return '#C9A2B3';
    return ElysiaTheme.INK_MUTE;
  }

  private starLabel(star: number): string {
    const idx = 5 - star;
    if (idx >= 0 && idx < BAR_LABELS.length) {
      return BAR_LABELS[idx];
    }
    return `${star} 星`;
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.admineval_title'), subtitle: $r('app.string.admineval_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.stats !== null) {
          Scroll() {
            Column({ space: 14 }) {
              this.PeriodCard()
              RoseDivider({ label: $r('app.string.admineval_divider_dist') })
              this.DistributionCard()
              this.TemplatesCard()
              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }

  // 评教期卡片：状态 Pill + 指标 + 开放/关闭控制
  @Builder PeriodCard() {
    Column({ space: 10 }) {
      Row() {
        Column() {
          Text($r('app.string.admineval_current_period')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Text(this.stats!.term).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Pill({
          text: this.stats!.periodOpen ? $r('app.string.admineval_ongoing') : $r('app.string.admineval_closed'),
          color: this.stats!.periodOpen ? ElysiaTheme.SUCCESS : ElysiaTheme.INK_MUTE,
          bg: '#FFF6FA'
        })
      }.width('100%').alignItems(VerticalAlign.Center)

      Row({ space: 0 }) {
        Column() {
          Text(`${this.stats!.participationRate.toFixed(1)}%`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
          Text($r('app.string.admineval_participation')).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column() {
          Text(`${this.stats!.completionRate.toFixed(1)}%`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.LAV_500)
          Text($r('app.string.admineval_completion')).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        Column() {
          Text(this.stats!.averageScore.toFixed(2)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.GOLD_500)
          Text($r('app.string.admineval_avg_score')).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
      }.width('100%').margin({ top: 4 })

      Row({ space: 10 }) {
        Text(this.stats!.periodOpen ? $r('app.string.admineval_keep_open') : $r('app.string.admineval_open_eval'))
          .fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.stats!.periodOpen ? ElysiaTheme.INK_MUTE : Color.White)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .layoutWeight(1)
          .backgroundColor(this.stats!.periodOpen ? '#F5F2F4' : ElysiaTheme.ROSE_500)
          .borderRadius(999)
          .onClick(() => { this.setPeriod(true); })
        Text(this.stats!.periodOpen ? $r('app.string.admineval_close_eval') : $r('app.string.admineval_closed'))
          .fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(this.stats!.periodOpen ? ElysiaTheme.ROSE_ACCENT : ElysiaTheme.INK_MUTE)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .layoutWeight(1)
          .backgroundColor(this.stats!.periodOpen ? '#FFF0F3' : '#F5F2F4')
          .borderRadius(999)
          .border({ width: 1, color: this.stats!.periodOpen ? '#33D8546B' : '#22000000' })
          .onClick(() => { this.setPeriod(false); })
      }.width('100%').margin({ top: 4 })
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  // 评分分布卡片：从 stats.ratingDistribution 计算的水平柱条
  @Builder DistributionCard() {
    Column() {
      Row() {
        Text($r('app.string.admineval_rating_dist')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
        Text(`共 ${this.totalRatings(this.stats!.ratingDistribution)} 份`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%').margin({ bottom: 10 })

      ForEach(this.stats!.ratingDistribution, (b: RatingBucket) => {
        Row({ space: 8 }) {
          Text(this.starLabel(b.star)).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width(40)
          Row() {
            Row()
              .height(14)
              .width(this.barWidth(b.count, this.totalRatings(this.stats!.ratingDistribution)))
              .backgroundColor(this.barColor(b.star))
              .borderRadius(7)
          }.layoutWeight(1).height(14).backgroundColor('#FFE9F1').borderRadius(7)
          Text(`${b.count}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width(48).textAlign(TextAlign.End)
        }.width('100%').margin({ top: 6, bottom: 6 }).alignItems(VerticalAlign.Center)
      }, (b: RatingBucket) => `${b.star}`)
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  // 问卷模板卡片：列表 + 内联编辑/删除 + 新增表单
  @Builder TemplatesCard() {
    Column() {
      Row() {
        Text($r('app.string.admineval_templates')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
        Text(this.isEditing ? $r('app.string.admineval_collapse') : $r('app.string.admineval_add')).fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.isEditing ? ElysiaTheme.INK_MUTE : ElysiaTheme.ROSE_500).borderRadius(999)
          .onClick(() => { if (this.isEditing) { this.cancelEdit(); } else { this.openCreate(); } })
      }.width('100%').margin({ bottom: 8 })

      if (this.isEditing) {
        this.EditorForm()
      }

      if (this.templates.length === 0) {
        EmptyState({ title: $r('app.string.admineval_empty'), hint: '点击右上角新增' })
      } else {
        ForEach(this.templates, (t: QuestionnaireTemplate) => {
          Column({ space: 6 }) {
            Row() {
              Text(t.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).layoutWeight(1)
              Pill({ text: this.templateStatusLabel(t.status), color: this.templateStatusColor(t.status), bg: '#FFF6FA' })
            }.width('100%').alignItems(VerticalAlign.Center)
            if (t.description.length > 0) {
              Text(t.description).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Row() {
              if (this.pendingDeleteId === t.id) {
                Text(`确认删除「${t.name}」`).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
                Text($r('app.string.common_cancel')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor('#F5F2F4').borderRadius(999).margin({ right: 10 })
                  .onClick(() => { this.cancelDelete(); })
                Text($r('app.string.admineval_confirm_delete')).fontSize(12).fontColor(Color.White)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
                  .onClick(() => { this.deleteTemplate(t); })
              } else {
                Text(`${t.questionCount} 题`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                Text($r('app.string.admineval_edit_btn')).fontSize(12).fontColor(ElysiaTheme.ROSE_700)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor('#FFE9F1').borderRadius(999).margin({ right: 12 })
                  .onClick(() => { this.openEdit(t); })
                Text($r('app.string.admineval_delete_btn')).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor('#FFF0F3').borderRadius(999)
                  .onClick(() => { this.requestDelete(t); })
              }
            }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 2 })
          }.width('100%').padding(12).margin({ bottom: 8 })
          .backgroundColor('#FFFDFE').borderRadius(14)
          .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
        }, (t: QuestionnaireTemplate) => t.id)
      }
    }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  // 新增/编辑表单
  @Builder EditorForm() {
    Column({ space: 10 }) {
      Text(this.editingId.length > 0 ? $r('app.string.admineval_edit_tpl') : $r('app.string.admineval_add_tpl'))
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
      ElysiaInput({ placeholder: $r('app.string.admineval_ph_name'), value: $name, leadingIcon: 'evaluation' })
      ElysiaInput({ placeholder: $r('app.string.admineval_ph_desc'), value: $description, leadingIcon: 'file' })
      Row({ space: 8 }) {
        Text($r('app.string.admineval_question_count')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        TextInput({ placeholder: '1-50', text: this.questionCountText })
          .type(InputType.Number)
          .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
          .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
          .layoutWeight(1)
          .onChange((v: string) => { this.questionCountText = v; })
      }.width('100%').alignItems(VerticalAlign.Center)

      Column({ space: 6 }) {
        Text($r('app.string.admineval_tpl_status')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        Row({ space: 8 }) {
          ForEach(this.statusLabels, (label: string, idx: number) => {
            Text(label).fontSize(12)
              .fontColor(this.status === this.statuses[idx] ? Color.White : ElysiaTheme.ROSE_700)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.status === this.statuses[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
              .borderRadius(999)
              .onClick(() => { this.status = this.statuses[idx]; })
          }, (label: string, idx: number) => `tpl-status-${idx}`)
        }
      }.width('100%').alignItems(HorizontalAlign.Start)

      if (this.formError.length > 0) {
        Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
      }

      Row({ space: 10 }) {
        GhostButton({ text: $r('app.string.common_cancel'), onTap: () => this.cancelEdit() }).layoutWeight(1)
        PrimaryButton({ text: this.submitting ? $r('app.string.common_saving') : $r('app.string.admineval_save_tpl'), onTap: () => this.saveTemplate() }).layoutWeight(1)
      }
    }.width('100%').padding(14).margin({ bottom: 10 })
    .backgroundColor('#FFFDFE').borderRadius(16)
    .border({ width: 1, color: '#4DFFB3CE' })
  }
}

// 系统路由表构建函数
@Builder
export function AdminEvalPageBuilder() {
  NavDestination() {
    AdminEvalPage()
  }
  .hideTitleBar(true)
}
