// 系统配置（审批流 / 消息模板 / 安全策略）· Config
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { SysConfigRepository } from '../repositories/SysConfigRepository';
import {
  ApprovalNode, MsgTemplate, MsgTemplatePayload, SecurityPolicy
} from '../models/SysConfigModels';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

// 安全策略开关项（用于驱动 ForEach 渲染）
class SecurityToggleDef {
  key: string = '';
  label: string = '';
  desc: string = '';
  value: boolean = false;
  constructor(key: string, label: string, desc: string, value: boolean) {
    this.key = key;
    this.label = label;
    this.desc = desc;
    this.value = value;
  }
}

@Entry
@Component
struct AdminSysConfigPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State submitting: boolean = false;

  // 审批流
  @State flow: ApprovalNode[] = [];
  // 消息模板
  @State templates: MsgTemplate[] = [];
  // 安全策略
  @State policy: SecurityPolicy = {
    twoFactor: false, forceStrongPwd: true, lockOnFailure: true, autoLogout: true, auditLogging: true
  };

  // 模板编辑器
  @State isEditingTpl: boolean = false;
  @State editingTplId: string = '';
  @State tplName: string = '';
  @State tplChannel: string = '';
  @State tplContent: string = '';
  @State tplFormError: string = '';
  @State pendingDeleteTplId: string = '';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminSysConfig)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const repo = SysConfigRepository.get();
    Promise.all([repo.getApprovalFlow(), repo.getMsgTemplates(), repo.getSecurityPolicy()])
      .then((results: [ApprovalNode[], MsgTemplate[], SecurityPolicy]) => {
        this.flow = results[0];
        this.templates = results[1];
        this.policy = results[2];
        this.loading = false;
      }).catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  // ---------- 审批流 ----------
  private toggleNode(id: string, enabled: boolean): void {
    const current = this.flow;
    const next: ApprovalNode[] = current.map((node) => {
      const copy: ApprovalNode = {
        id: node.id,
        name: node.name,
        approverRole: node.approverRole,
        enabled: node.id === id ? enabled : node.enabled,
        order: node.order
      };
      return copy;
    });
    this.flow = next;
    SysConfigRepository.get().updateApprovalFlow(next).then((saved: ApprovalNode[]) => {
      this.flow = saved;
      Toast.show(this.getUIContext(), enabled ? '已启用节点' : '已停用节点');
    }).catch((e: object) => {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '更新失败';
      Toast.show(this.getUIContext(), msg);
      this.loadData();
    });
  }

  // ---------- 安全策略 ----------
  private securityDefs(): SecurityToggleDef[] {
    const p = this.policy;
    return [
      new SecurityToggleDef('twoFactor', '双因素认证', '登录时需二次验证', p.twoFactor),
      new SecurityToggleDef('forceStrongPwd', '强制强密码', '要求字母+数字组合', p.forceStrongPwd),
      new SecurityToggleDef('lockOnFailure', '失败锁定', '多次失败后锁定账号', p.lockOnFailure),
      new SecurityToggleDef('autoLogout', '自动登出', '空闲超时自动退出', p.autoLogout),
      new SecurityToggleDef('auditLogging', '审计日志', '记录关键操作日志', p.auditLogging)
    ];
  }

  private applyPolicy(key: string, value: boolean): SecurityPolicy {
    const p = this.policy;
    const next: SecurityPolicy = {
      twoFactor: key === 'twoFactor' ? value : p.twoFactor,
      forceStrongPwd: key === 'forceStrongPwd' ? value : p.forceStrongPwd,
      lockOnFailure: key === 'lockOnFailure' ? value : p.lockOnFailure,
      autoLogout: key === 'autoLogout' ? value : p.autoLogout,
      auditLogging: key === 'auditLogging' ? value : p.auditLogging
    };
    return next;
  }

  private toggleSecurity(key: string, value: boolean): void {
    this.policy = this.applyPolicy(key, value);
    SysConfigRepository.get().setSecurityToggle(key, value).then(() => {
      Toast.show(this.getUIContext(), '安全策略已更新');
    }).catch((e: object) => {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '更新失败';
      Toast.show(this.getUIContext(), msg);
      this.loadData();
    });
  }

  // ---------- 消息模板 ----------
  private resetTplForm(): void {
    this.editingTplId = '';
    this.tplName = '';
    this.tplChannel = '';
    this.tplContent = '';
    this.tplFormError = '';
  }

  private openCreateTpl(): void {
    this.pendingDeleteTplId = '';
    this.resetTplForm();
    this.isEditingTpl = true;
  }

  private openEditTpl(t: MsgTemplate): void {
    this.pendingDeleteTplId = '';
    this.editingTplId = t.id;
    this.tplName = t.name;
    this.tplChannel = t.channel;
    this.tplContent = t.content;
    this.tplFormError = '';
    this.isEditingTpl = true;
  }

  private cancelTplEdit(): void {
    this.isEditingTpl = false;
    this.resetTplForm();
  }

  private saveTpl(): void {
    if (this.submitting) return;
    const payload: MsgTemplatePayload = {
      name: this.tplName.trim(),
      channel: this.tplChannel.trim(),
      content: this.tplContent.trim()
    };
    if (payload.name.length === 0) {
      this.tplFormError = '模板名称不能为空';
      return;
    }
    if (payload.channel.length === 0) {
      this.tplFormError = '渠道不能为空';
      return;
    }
    if (payload.content.length === 0) {
      this.tplFormError = '模板内容不能为空';
      return;
    }
    this.submitting = true;
    this.tplFormError = '';
    const repo = SysConfigRepository.get();
    const id = this.editingTplId;
    const action = id.length > 0 ? repo.updateMsgTemplate(id, payload) : repo.createMsgTemplate(payload);
    action.then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), id.length > 0 ? '模板已更新' : '模板已新增');
      this.cancelTplEdit();
      this.reloadTemplates();
    }).catch((e: object) => {
      this.submitting = false;
      this.tplFormError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  private requestDeleteTpl(t: MsgTemplate): void {
    if (this.submitting) return;
    this.pendingDeleteTplId = t.id;
  }

  private cancelDeleteTpl(): void {
    this.pendingDeleteTplId = '';
  }

  private deleteTpl(t: MsgTemplate): void {
    if (this.submitting) return;
    this.submitting = true;
    SysConfigRepository.get().deleteMsgTemplate(t.id).then(() => {
      this.submitting = false;
      this.pendingDeleteTplId = '';
      Toast.show(this.getUIContext(), '模板已删除');
      if (this.editingTplId === t.id) {
        this.cancelTplEdit();
      }
      this.reloadTemplates();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '删除失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  private reloadTemplates(): void {
    SysConfigRepository.get().getMsgTemplates().then((list: MsgTemplate[]) => {
      this.templates = list;
    }).catch((e: object) => {
      Toast.show(this.getUIContext(), e instanceof Error ? e.message : '刷新失败');
    });
  }

  // ---------- Builders ----------
  @Builder
  SectionHeader(icon: string, title: string, subtitle: string) {
    Row({ space: 10 }) {
      AppIcon({ name: icon, iconSize: 20 })
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text(subtitle).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').margin({ top: 6, bottom: 8 }).alignItems(VerticalAlign.Center)
  }

  @Builder
  ApprovalFlowSection() {
    this.SectionHeader('approve', '审批流配置', '按顺序启用 / 停用审批节点')
    Column({ space: 0 }) {
      if (this.flow.length === 0) {
        EmptyState({ title: '暂无审批节点' })
      } else {
        ForEach(this.flow, (node: ApprovalNode, idx: number) => {
          Row() {
            Text(`${idx + 1}`).fontSize(12).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
              .width(24).height(24).textAlign(TextAlign.Center)
              .backgroundColor('#FFE9F1').borderRadius(12).margin({ right: 10 })
            Column() {
              Text(node.name).fontSize(14).fontColor(ElysiaTheme.INK)
              Text(`审批角色：${node.approverRole}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: node.enabled })
              .selectedColor(ElysiaTheme.ROSE_500)
              .onChange((on: boolean) => {
                if (on !== node.enabled) {
                  this.toggleNode(node.id, on);
                }
              })
          }.width('100%').padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
        }, (node: ApprovalNode) => node.id)
      }
    }.width('100%').padding({ left: 14, right: 14 })
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  @Builder
  TplEditorPanel() {
    Column({ space: 10 }) {
      Text(this.editingTplId.length > 0 ? '编辑模板' : '新增模板')
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
      ElysiaInput({ placeholder: '模板名称', value: $tplName, leadingIcon: 'mail' })
      ElysiaInput({ placeholder: '渠道，如：站内信/短信/邮件', value: $tplChannel, leadingIcon: 'bell' })
      ElysiaInput({ placeholder: '模板内容', value: $tplContent, leadingIcon: 'file' })
      if (this.tplFormError.length > 0) {
        Text(this.tplFormError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
      }
      Row({ space: 10 }) {
        GhostButton({ text: '取消', onTap: () => this.cancelTplEdit() }).layoutWeight(1)
        PrimaryButton({ text: this.submitting ? '保存中...' : '保存模板', onTap: () => this.saveTpl() }).layoutWeight(1)
      }
    }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(16)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).margin({ top: 10 })
  }

  @Builder
  TplCard(t: MsgTemplate) {
    Column({ space: 8 }) {
      Row() {
        Text(t.name).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Pill({ text: t.channel, color: ElysiaTheme.LAV_500, bg: '#F3ECFF' })
      }.width('100%')
      Text(t.content).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        if (this.pendingDeleteTplId === t.id) {
          Text('确认删除该模板？').fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
          Text('取消').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F5F2F4').borderRadius(999).margin({ right: 10 })
            .onClick(() => { this.cancelDeleteTpl(); })
          Text('确认删除').fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
            .onClick(() => { this.deleteTpl(t); })
        } else {
          Blank().layoutWeight(1)
          Text('编辑').fontSize(12).fontColor(ElysiaTheme.ROSE_700)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFE9F1').borderRadius(999).margin({ right: 12 })
            .onClick(() => { this.openEditTpl(t); })
          Text('删除').fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFF0F3').borderRadius(999)
            .onClick(() => { this.requestDeleteTpl(t); })
        }
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).margin({ bottom: 8 })
  }

  @Builder
  MsgTemplateSection() {
    Row() {
      Blank().layoutWeight(1)
      Text('新增模板').fontSize(12).fontColor(Color.White).fontWeight(FontWeight.Bold)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
        .onClick(() => { this.openCreateTpl(); })
    }.width('100%')

    this.SectionHeader('mail', '消息模板', '管理通知推送模板')

    if (this.isEditingTpl) {
      this.TplEditorPanel()
    }

    if (this.templates.length === 0) {
      EmptyState({ title: '暂无消息模板', hint: '点击新增模板' })
    } else {
      Column() {
        ForEach(this.templates, (t: MsgTemplate) => {
          this.TplCard(t)
        }, (t: MsgTemplate) => t.id)
      }.width('100%').margin({ top: 10 })
    }
  }

  @Builder
  SecurityRow(def: SecurityToggleDef) {
    Row() {
      Column() {
        Text(def.label).fontSize(14).fontColor(ElysiaTheme.INK)
        Text(def.desc).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: def.value })
        .selectedColor(ElysiaTheme.ROSE_500)
        .onChange((on: boolean) => {
          if (on !== def.value) {
            this.toggleSecurity(def.key, on);
          }
        })
    }.width('100%').padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  @Builder
  SecurityPolicySection() {
    this.SectionHeader('lock', '安全策略', '账号安全相关开关')
    Column({ space: 0 }) {
      ForEach(this.securityDefs(), (def: SecurityToggleDef) => {
        this.SecurityRow(def)
      }, (def: SecurityToggleDef) => def.key)
    }.width('100%').padding({ left: 14, right: 14 })
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
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
        TopBar({ title: '系统配置', subtitle: '系 统 配 置', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else {
          Scroll() {
            Column({ space: 16 }) {
              this.ApprovalFlowSection()
              this.MsgTemplateSection()
              this.SecurityPolicySection()
              SafeBottom()
            }.width('100%').padding({ left: 16, right: 16, top: 6 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}
