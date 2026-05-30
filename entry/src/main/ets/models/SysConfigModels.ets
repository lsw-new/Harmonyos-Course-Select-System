// 系统配置 / 校历 模型

// 校历事件类型：开学 / 考试周 / 假期 / 选课 / 补缓考 / 其他
export type CalendarEventType = 'term' | 'exam' | 'holiday' | 'selection' | 'makeup' | 'other';

export interface CalendarEvent {
  id: string;
  date: string;
  title: string;
  type: CalendarEventType;
}

export interface CalendarEventPayload {
  date: string;
  title: string;
  type: CalendarEventType;
}

// 审批流节点
export interface ApprovalNode {
  id: string;
  name: string;
  approverRole: string;
  enabled: boolean;
  order: number;
}

// 消息模板
export interface MsgTemplate {
  id: string;
  name: string;
  channel: string;
  content: string;
}

export interface MsgTemplatePayload {
  name: string;
  channel: string;
  content: string;
}

// 安全策略开关
export interface SecurityPolicy {
  twoFactor: boolean;
  forceStrongPwd: boolean;
  lockOnFailure: boolean;
  autoLogout: boolean;
  auditLogging: boolean;
}

// 管理员修改密码请求
export interface AdminPasswordPayload {
  oldPwd: string;
  newPwd: string;
}
