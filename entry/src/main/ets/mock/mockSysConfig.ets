// 系统配置 / 校历 Mock 数据

import { CalendarEvent, ApprovalNode, MsgTemplate, SecurityPolicy } from '../models/SysConfigModels';

export const mockCalendarEvents: CalendarEvent[] = [
  { id: 'cal-1', date: '2026-02-23', title: '春季学期开学', type: 'term' },
  { id: 'cal-2', date: '2026-03-02', title: '春季选课开放', type: 'selection' },
  { id: 'cal-3', date: '2026-04-05', title: '清明假期', type: 'holiday' },
  { id: 'cal-4', date: '2026-05-01', title: '劳动节假期', type: 'holiday' },
  { id: 'cal-5', date: '2026-06-22', title: '期末考试周', type: 'exam' },
  { id: 'cal-6', date: '2026-09-08', title: '补缓考报名', type: 'makeup' }
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
