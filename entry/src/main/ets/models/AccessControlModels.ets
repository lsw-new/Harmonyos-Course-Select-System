// 访问控制模型 · 角色 / 权限 / 操作日志

// 单条权限项（与 models/Admin.ets 的 AdminPermission 形状一致，便于复用 SessionStorage 中的权限数据）
export interface PermItem {
  code: string;
  name: string;
  module: string;
  actions: string[];
}

// 角色视图（含成员数与权限清单）
export interface AdminRoleView {
  id: string;
  name: string;
  description: string;
  memberCount: number;
  permissions: PermItem[];
}

// 操作日志结果
export type AuditResult = 'success' | 'failed';

// 操作日志条目
export interface AuditLogEntry {
  id: string;
  operatorName: string;
  operatorId: string;
  action: string;
  actionType: string;
  target: string;
  timestamp: string;
  result: AuditResult;
  ip: string;
}

// 模块标签：将权限 module 键映射为中文展示名
export interface ModuleLabel {
  key: string;
  label: string;
}

// 按模块聚合后的权限分组（用于「我的权限 / 权限矩阵」展示）
export interface PermModuleGroup {
  module: string;
  moduleLabel: string;
  items: PermItem[];
}
