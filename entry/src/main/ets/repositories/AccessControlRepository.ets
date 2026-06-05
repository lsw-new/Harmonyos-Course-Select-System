// 访问控制仓储 · 角色 / 权限矩阵 / 操作日志（只读视图）

import { BaseRepository } from './BaseRepository';
import { AdminRoleView, AuditLogEntry, PermItem, AuditResult } from '../models/AccessControlModels';
import { mockRoles, mockAuditLogs } from '../mock/mockAccessControl';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AdminProfile, AdminPermission } from '../models/Admin';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteRole, RemoteAuditLog, RemotePermItem } from '../common/remote/RemoteApi';

const KEY_AUDIT_LOGS = 'local.auditLogs.v1';

export class AccessControlRepository extends BaseRepository {
  private static _instance?: AccessControlRepository;
  static get(): AccessControlRepository {
    if (!AccessControlRepository._instance) {
      AccessControlRepository._instance = new AccessControlRepository();
    }
    return AccessControlRepository._instance;
  }

  private roles: AdminRoleView[] = JSON.parse(JSON.stringify(mockRoles)) as AdminRoleView[];
  private logs: AuditLogEntry[] = JSON.parse(JSON.stringify(mockAuditLogs)) as AuditLogEntry[];
  private isLogsLoaded: boolean = false;

  private async getLogItems(): Promise<AuditLogEntry[]> {
    if (!this.isLogsLoaded) {
      this.logs = await LocalDataStore.loadArray<AuditLogEntry>(KEY_AUDIT_LOGS, mockAuditLogs);
      this.isLogsLoaded = true;
    }
    return this.logs;
  }

  private remoteToPerm(p: RemotePermItem): PermItem {
    const item: PermItem = { code: p.code, name: p.name, module: p.module, actions: p.actions.slice() };
    return item;
  }

  private remoteToRole(r: RemoteRole): AdminRoleView {
    const item: AdminRoleView = {
      id: r.id,
      name: r.name,
      description: r.description,
      memberCount: r.memberCount,
      permissions: r.permissions.map((p) => this.remoteToPerm(p))
    };
    return item;
  }

  private remoteToAuditLog(l: RemoteAuditLog): AuditLogEntry {
    const item: AuditLogEntry = {
      id: l.id,
      operatorName: l.operatorName,
      operatorId: l.operatorId,
      action: l.action,
      actionType: l.actionType,
      target: l.target,
      timestamp: l.timestamp,
      result: l.result as AuditResult,
      ip: l.ip
    };
    return item;
  }

  // 角色及其权限清单（深拷贝视图）
  async getRoles(): Promise<AdminRoleView[]> {
    if (AppConfig.useRemote) {
      const admin = SessionStorage.get().getAdmin();
      if (admin) {
        try {
          const remote = await RemoteApi.adminListRoles();
          return this.delayCopy<AdminRoleView[]>(remote.map((r) => this.remoteToRole(r)));
        } catch (e) {
          // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
          if (!AppConfig.allowMockFallbackInRemote) {
            throw new Error('远程服务异常，请稍后重试');
          }
          // 否则回退本地
        }
      }
    }
    return this.delayCopy<AdminRoleView[]>(this.roles);
  }

  // 操作日志（最新在前，可按操作类型筛选）。深拷贝返回。
  async getAuditLogs(typeFilter?: string): Promise<AuditLogEntry[]> {
    if (AppConfig.useRemote) {
      const admin = SessionStorage.get().getAdmin();
      if (admin) {
        try {
          const remote = await RemoteApi.adminListAuditLogs(typeFilter);
          return this.delayCopy<AuditLogEntry[]>(remote.map((l) => this.remoteToAuditLog(l)));
        } catch (e) {
          // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
          if (!AppConfig.allowMockFallbackInRemote) {
            throw new Error('远程服务异常，请稍后重试');
          }
          // 否则回退本地
        }
      }
    }
    const items = await this.getLogItems();
    const sorted = items.slice().sort((a: AuditLogEntry, b: AuditLogEntry): number => {
      if (a.timestamp < b.timestamp) return 1;
      if (a.timestamp > b.timestamp) return -1;
      return 0;
    });
    const filtered = (typeFilter !== undefined && typeFilter.length > 0 && typeFilter !== '全部')
      ? sorted.filter((log: AuditLogEntry): boolean => log.actionType === typeFilter)
      : sorted;
    return this.delayCopy<AuditLogEntry[]>(filtered);
  }

  // 当前管理员的权限（来源于会话），无则返回空数组。深拷贝返回。
  async getMyPermissions(): Promise<PermItem[]> {
    const admin: AdminProfile | undefined = SessionStorage.get().getAdmin();
    if (admin === undefined) {
      return this.delayCopy<PermItem[]>([]);
    }
    const source: AdminPermission[] = admin.permissions;
    const mapped: PermItem[] = source.map((p: AdminPermission): PermItem => {
      const item: PermItem = {
        code: p.code,
        name: p.name,
        module: p.module,
        actions: (p.actions as string[]).slice()
      };
      return item;
    });
    return this.delayCopy<PermItem[]>(mapped);
  }
}
