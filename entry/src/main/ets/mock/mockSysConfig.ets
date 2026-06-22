// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，校历事件、审批节点、消息模板及安全策略均为人工编造。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下系统配置数据由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

// 系统配置 / 校历 Mock 数据

import { CalendarEvent, ApprovalNode, MsgTemplate, SecurityPolicy } from '../models/SysConfigModels';

// 真实校历：《景德镇艺术职业大学 2025-2026 学年校历》第二学期（与后端 calendar_events 同源）
export const mockCalendarEvents: CalendarEvent[] = [
  { id: 'sc2-01', date: '2026-03-05', title: '教工开学', type: 'term' },
  { id: 'sc2-02', date: '2026-03-06', title: '学生开学报到及教材发放（3月6日-8日）', type: 'term' },
  { id: 'sc2-03', date: '2026-03-09', title: '正式上课（第二学期）', type: 'term' },
  { id: 'sc2-04', date: '2026-03-09', title: '集中教学检查（3月9日-13日）', type: 'other' },
  { id: 'sc2-05', date: '2026-04-05', title: '清明节假期', type: 'holiday' },
  { id: 'sc2-06', date: '2026-05-01', title: '劳动节假期', type: 'holiday' },
  { id: 'sc2-07', date: '2026-06-19', title: '端午节假期', type: 'holiday' },
  { id: 'sc2-08', date: '2026-06-29', title: '期末集中考试（6月29日-7月1日）', type: 'exam' },
  { id: 'sc2-09', date: '2026-07-02', title: '校外实践教学周（7月2日-10日）', type: 'other' },
  { id: 'sc2-10', date: '2026-07-11', title: '学生暑假开始', type: 'holiday' },
  { id: 'sc2-11', date: '2026-07-18', title: '教工暑假开始', type: 'holiday' }
];

export const mockApprovalNodes: ApprovalNode[] = [
  { id: 'flow-1', name: '辅导员初审', approverRole: '辅导员', enabled: true, order: 1 },
  { id: 'flow-2', name: '院系审核', approverRole: '院系负责人', enabled: true, order: 2 },
  { id: 'flow-3', name: '教务处复核', approverRole: '教务处', enabled: true, order: 3 },
  { id: 'flow-4', name: '分管校领导审批', approverRole: '校领导', enabled: false, order: 4 }
];

export const mockMsgTemplates: MsgTemplate[] = [
  { id: 'tpl-1', name: '请假审批通过', channel: '站内信', content: '您的请假申请已通过审批，请按时返校。' },
  { id: 'tpl-2', name: '成绩发布提醒', channel: '短信', content: '本学期成绩已发布，请登录系统查看。' },
  { id: 'tpl-3', name: '选课开放通知', channel: '邮件', content: '新一轮选课已开放，请在截止日期前完成选课。' },
  { id: 'tpl-4', name: '缴费提醒', channel: '站内信', content: '请于本周内完成学费缴纳，逾期将影响注册。' }
];

export const mockSecurityPolicy: SecurityPolicy = {
  twoFactor: false,
  forceStrongPwd: true,
  lockOnFailure: true,
  autoLogout: true,
  auditLogging: true
};
