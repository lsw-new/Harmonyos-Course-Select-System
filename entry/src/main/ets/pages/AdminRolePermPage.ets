// 角色与权限 · Roles & Permissions（角色 / 权限矩阵 / 我的权限）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { HttpError } from '../common/http/HttpError';
import { AccessControlRepository } from '../repositories/AccessControlRepository';
import { AdminRoleView, PermItem, PermModuleGroup, ModuleLabel } from '../models/AccessControlModels';
import { MODULE_LABELS } from '../mock/mockAccessControl';

// 操作键 -> 中文标签
const ACTION_LABELS: Record<string, string> = {
  'view': '查看',
  'create': '新增',
  'update': '编辑',
  'delete': '删除',
  'approve': '审批',
  'publish': '发布'
};

@Entry
@Component
struct AdminRolePermPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State roles: AdminRoleView[] = [];
  @State myPerms: PermItem[] = [];
  @StorageProp('darkMode') darkMode: boolean = false;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminRolePerm)) return;
    this.loadAll();
  }

  private loadAll(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = AccessControlRepository.get();
    Promise.all([repo.getRoles(), repo.getMyPermissions()])
      .then((res: [AdminRoleView[], PermItem[]]) => {
        this.roles = res[0];
        this.myPerms = res[1];
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
        this.loading = false;
      });
  }

  private moduleLabel(key: string): string {
    const found = MODULE_LABELS.find((m): boolean => m.key === key);
    return found !== undefined ? found.label : key;
  }

  private actionLabel(action: string): string {
    const label: string | undefined = ACTION_LABELS[action];
    return label !== undefined ? label : action;
  }

  private actionColor(action: string): string {
    if (action === 'delete') return '#D8546B';
    if (action === 'approve') return '#7BB07B';
    if (action === 'publish') return ElysiaTheme.GOLD_700;
    if (action === 'create' || action === 'update') return ElysiaTheme.LAV_500;
    return ElysiaTheme.ROSE_700;
  }

  private actionBg(action: string): string {
    if (action === 'delete') return '#FFF0F0';
    if (action === 'approve') return '#EAF6EA';
    if (action === 'publish') return '#FBF3E2';
    if (action === 'create' || action === 'update') return '#F3ECFF';
    return '#FFE9F1';
  }

  // 将权限列表按模块聚合，便于「我的权限」分组展示
  private groupByModule(perms: PermItem[]): PermModuleGroup[] {
    const groups: PermModuleGroup[] = [];
    perms.forEach((perm: PermItem) => {
      const existing = groups.find((g): boolean => g.module === perm.module);
      if (existing !== undefined) {
        existing.items.push(perm);
      } else {
        const group: PermModuleGroup = {
          module: perm.module,
          moduleLabel: this.moduleLabel(perm.module),
          items: [perm]
        };
        groups.push(group);
      }
    });
    return groups;
  }

  // 角色在某模块下拥有的去重操作集合（用于权限矩阵）
  private actionsForModule(role: AdminRoleView, moduleKey: string): string[] {
    const result: string[] = [];
    role.permissions.forEach((perm: PermItem) => {
      if (perm.module !== moduleKey) return;
      perm.actions.forEach((a: string) => {
        if (result.indexOf(a) < 0) result.push(a);
      });
    });
    return result;
  }

  @Builder SectionHeader(icon: string, title: string, hint: string) {
    Row() {
      AppIcon({ name: icon, iconSize: 18, mRight: 8 })
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
      if (hint.length > 0) {
        Text(hint).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }
    }.width('100%').padding({ left: 2, right: 2, bottom: 4 })
  }

  @Builder ActionPills(actions: string[]) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(actions, (action: string) => {
        Row() {
          Pill({ text: this.actionLabel(action), color: this.actionColor(action), bg: this.actionBg(action) })
        }.margin({ right: 6, bottom: 6 })
      }, (action: string, idx: number) => `act-${action}-${idx}`)
    }.width('100%')
  }

  @Builder RoleCard(role: AdminRoleView) {
    Column() {
      Row() {
        Column() {
          Text(role.name).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Text(role.description).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 }).lineHeight(17)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Pill({ text: `${role.memberCount} 人`, color: ElysiaTheme.ROSE_700, bg: '#FFF6FA' })
      }.width('100%').alignItems(VerticalAlign.Top)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(role.permissions, (perm: PermItem) => {
          Row() {
            Pill({ text: perm.name, color: ElysiaTheme.ROSE_700, bg: '#FFE9F1' })
          }.margin({ right: 6, bottom: 6 })
        }, (perm: PermItem) => `${role.id}-${perm.code}`)
      }.width('100%').margin({ top: 10 })
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) }).margin({ bottom: 10 })
  }

  // 权限矩阵：逐角色列出其各模块拥有的操作（移动端友好，避免过宽的真表格）
  @Builder MatrixRoleBlock(role: AdminRoleView) {
    Column() {
      Text(role.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700).margin({ bottom: 6 })
      ForEach(MODULE_LABELS, (mod: ModuleLabel) => {
        Row() {
          Text(mod.label).fontSize(12).fontColor(ElysiaTheme.INK).width(78)
          if (this.actionsForModule(role, mod.key).length > 0) {
            Row() {
              this.ActionPills(this.actionsForModule(role, mod.key))
            }.layoutWeight(1)
          } else {
            Row() {
              AppIcon({ name: 'close', iconSize: 12, dim: true, mRight: 4 })
              Text('无权限').fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
            }.layoutWeight(1)
          }
        }.width('100%').padding({ top: 8, bottom: 8 }).alignItems(VerticalAlign.Top)
        .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
      }, (mod: ModuleLabel, idx: number) => `${role.id}-mod-${mod.key}`)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) }).margin({ bottom: 10 })
  }

  @Builder MyPermGroup(group: PermModuleGroup) {
    Column() {
      Row() {
        AppIcon({ name: 'check', iconSize: 14, mRight: 6 })
        Text(group.moduleLabel).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Text(`${group.items.length} 项`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.width('100%')
      ForEach(group.items, (perm: PermItem) => {
        Column() {
          Text(perm.name).fontSize(12).fontColor(ElysiaTheme.INK)
          this.ActionPills(perm.actions)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 2 })
        .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
      }, (perm: PermItem) => `my-${group.module}-${perm.code}`)
    }
    .width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) }).margin({ bottom: 10 })
  }

  @Builder Body() {
    Scroll() {
      Column() {
        // 角色
        this.SectionHeader('students', '角色', `${this.roles.length} 个角色`)
        ForEach(this.roles, (role: AdminRoleView) => {
          this.RoleCard(role)
        }, (role: AdminRoleView) => `role-${role.id}`)

        // 权限矩阵
        Column().height(8)
        this.SectionHeader('dashboard', '权限矩阵', '角色 × 模块')
        ForEach(this.roles, (role: AdminRoleView) => {
          this.MatrixRoleBlock(role)
        }, (role: AdminRoleView) => `mx-${role.id}`)

        // 我的权限
        Column().height(8)
        this.SectionHeader('star', '我的权限', `${this.myPerms.length} 项`)
        if (this.myPerms.length === 0) {
          EmptyState({ icon: 'lock', title: '暂无授权', hint: '当前账号未分配任何权限' })
        } else {
          ForEach(this.groupByModule(this.myPerms), (group: PermModuleGroup) => {
            this.MyPermGroup(group)
          }, (group: PermModuleGroup) => `mg-${group.module}`)
        }

        SafeBottom()
      }.padding({ left: 16, right: 16, top: 8 })
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient(this.darkMode) })

      Column() {
        SafeTop()
        TopBar({ title: 'Roles', subtitle: '角 色 权 限', onBack: () => { AppRoute.back(); } })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadAll() })
        } else if (this.roles.length === 0) {
          EmptyState({ title: '暂无角色数据' })
        } else {
          this.Body()
        }
      }.width('100%').height('100%')
    }.width('100%').height('100%')
  }
}
