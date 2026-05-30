// 访问控制仓储 · 角色 / 权限矩阵 / 操作日志（只读视图）

import { BaseRepository } from './BaseRepository';
import { AdminRoleView, AuditLogEntry, PermItem } from '../models/AccessControlModels';
import { mockRoles, mockAuditLogs } from '../mock/mockAccessControl';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AdminProfile, AdminPermission } from '../models/Admin';

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

  // 角色及其权限清单（深拷贝视图）
  async getRoles(): Promise<AdminRoleView[]> {
    return this.delayCopy<AdminRoleView[]>(this.roles);
  }

  // 操作日志（最新在前，可按操作类型筛选）。深拷贝返回。
  async getAuditLogs(typeFilter?: string): Promise<AuditLogEntry[]> {
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
