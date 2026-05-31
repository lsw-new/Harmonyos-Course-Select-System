// 访问控制 Mock 数据 · 角色 / 权限 / 操作日志
import { AdminRoleView, AuditLogEntry, ModuleLabel } from '../models/AccessControlModels';

// 模块键 -> 中文展示名（权限矩阵列 / 我的权限分组标题）
export const MODULE_LABELS: ModuleLabel[] = [
  { key: 'students', label: '学生管理' },
  { key: 'courses', label: '课程管理' },
  { key: 'selection', label: '选课管理' },
  { key: 'grades', label: '成绩管理' },
  { key: 'notices', label: '通知公告' },
  { key: 'evaluation', label: '教学评价' },
  { key: 'approvals', label: '审批处理' },
  { key: 'system', label: '系统设置' }
];

// 操作类型筛选项（含「全部」由页面拼接，这里仅列出真实类型）
export const AUDIT_ACTION_TYPES: string[] = ['登录', '审批', '编辑', '删除', '发布', '导出'];

// 约 4 个角色：教务管理员 / 院系管理员 / 教师 / 审计员
export const mockRoles: AdminRoleView[] = [
  {
    id: 'role-academic-admin',
    name: '教务管理员',
    description: '统筹全校教务运行，拥有课程、成绩、通知与审批的完整管理权限。',
    memberCount: 6,
    permissions: [
      { code: 'students.manage', name: '\u5b66\u7c4d\u7ba1\u7406', module: 'students', actions: ['view', 'update'] },
      { code: 'evaluation.manage', name: '\u8bc4\u6559\u7ba1\u7406', module: 'evaluation', actions: ['view', 'create', 'update', 'delete'] },
      { code: 'system.config', name: '\u7cfb\u7edf\u914d\u7f6e', module: 'system', actions: ['view', 'create', 'update', 'delete'] },
      { code: 'students.view', name: '学生查看', module: 'students', actions: ['view'] },
      { code: 'courses.manage', name: '课程管理', module: 'courses', actions: ['view', 'create', 'update', 'delete'] },
      { code: 'selection.manage', name: '选课管理', module: 'selection', actions: ['view', 'update'] },
      { code: 'grades.approve', name: '成绩审核', module: 'grades', actions: ['view', 'create', 'update', 'approve'] },
      { code: 'notices.publish', name: '通知发布', module: 'notices', actions: ['view', 'create', 'publish'] },
      { code: 'evaluation.view', name: '评教查看', module: 'evaluation', actions: ['view'] },
      { code: 'approvals.handle', name: '审批处理', module: 'approvals', actions: ['view', 'approve'] }
    ]
  },
  {
    id: 'role-college-admin',
    name: '院系管理员',
    description: '负责本院系教学事务，可维护院内学生、课程与成绩录入审核。',
    memberCount: 18,
    permissions: [
      { code: 'students.view', name: '学生查看', module: 'students', actions: ['view'] },
      { code: 'courses.manage', name: '课程管理', module: 'courses', actions: ['view', 'create', 'update'] },
      { code: 'grades.approve', name: '成绩审核', module: 'grades', actions: ['view', 'approve'] },
      { code: 'notices.publish', name: '通知发布', module: 'notices', actions: ['view', 'create', 'publish'] },
      { code: 'approvals.handle', name: '审批处理', module: 'approvals', actions: ['view', 'approve'] }
    ]
  },
  {
    id: 'role-teacher',
    name: '教师',
    description: '面向授课教师，可查看任教学生与课程，录入并提交成绩。',
    memberCount: 836,
    permissions: [
      { code: 'students.view', name: '学生查看', module: 'students', actions: ['view'] },
      { code: 'courses.manage', name: '课程查看', module: 'courses', actions: ['view'] },
      { code: 'grades.approve', name: '成绩录入', module: 'grades', actions: ['view', 'create', 'update'] },
      { code: 'evaluation.view', name: '评教查看', module: 'evaluation', actions: ['view'] }
    ]
  },
  {
    id: 'role-auditor',
    name: '审计员',
    description: '只读监督角色，可查看全量数据与操作日志，但不可执行写操作。',
    memberCount: 3,
    permissions: [
      { code: 'students.view', name: '学生查看', module: 'students', actions: ['view'] },
      { code: 'courses.manage', name: '课程查看', module: 'courses', actions: ['view'] },
      { code: 'grades.approve', name: '成绩查看', module: 'grades', actions: ['view'] },
      { code: 'notices.publish', name: '通知查看', module: 'notices', actions: ['view'] },
      { code: 'evaluation.view', name: '评教查看', module: 'evaluation', actions: ['view'] },
      { code: 'approvals.handle', name: '审批查看', module: 'approvals', actions: ['view'] },
      { code: 'system.audit', name: '审计日志', module: 'system', actions: ['view'] }
    ]
  }
];

// 约 12 条操作日志，覆盖多种操作类型与成功 / 失败两种结果（按时间倒序）
export const mockAuditLogs: AuditLogEntry[] = [
  { id: 'log-12', operatorName: '爱莉希雅', operatorId: 'A20251001', action: '登录管理控制台', actionType: '登录', target: '管理后台', timestamp: '2026-05-29 09:02:11', result: 'success', ip: '10.21.4.18' },
  { id: 'log-11', operatorName: '爱莉希雅', operatorId: 'A20251001', action: '通过请假审批', actionType: '审批', target: '审批单 ap-1 · 李仕炜', timestamp: '2026-05-29 09:15:43', result: 'success', ip: '10.21.4.18' },
  { id: 'log-10', operatorName: '陆清和', operatorId: 'A20250087', action: '编辑课程信息', actionType: '编辑', target: '课程 CS101 · 数据结构与算法', timestamp: '2026-05-29 10:31:07', result: 'success', ip: '10.21.7.66' },
  { id: 'log-09', operatorName: '韩予', operatorId: 'A20250112', action: '发布教学通知', actionType: '发布', target: '通知 · 期末考试安排', timestamp: '2026-05-29 11:08:22', result: 'success', ip: '10.21.7.91' },
  { id: 'log-08', operatorName: '岳明远', operatorId: 'A20251033', action: '删除重复课程', actionType: '删除', target: '课程 CS401 · 操作系统原理', timestamp: '2026-05-29 11:46:50', result: 'failed', ip: '10.21.5.40' },
  { id: 'log-07', operatorName: '审计员·郑舟', operatorId: 'A20250003', action: '导出操作日志', actionType: '导出', target: '操作日志 2026-05 全量', timestamp: '2026-05-28 16:20:09', result: 'success', ip: '10.21.9.12' },
  { id: 'log-06', operatorName: '林婉如', operatorId: 'A20250214', action: '驳回成绩复核', actionType: '审批', target: '审批单 ap-3 · 陆清和', timestamp: '2026-05-28 15:02:33', result: 'success', ip: '10.21.7.30' },
  { id: 'log-05', operatorName: '宋衍', operatorId: 'A20250455', action: '登录管理控制台', actionType: '登录', target: '管理后台', timestamp: '2026-05-28 08:55:01', result: 'failed', ip: '203.0.113.77' },
  { id: 'log-04', operatorName: '爱莉希雅', operatorId: 'A20251001', action: '编辑学生培养信息', actionType: '编辑', target: '学生 2023307020941 · 李仕炜', timestamp: '2026-05-27 14:12:46', result: 'success', ip: '10.21.4.18' },
  { id: 'log-03', operatorName: '韩予', operatorId: 'A20250112', action: '发布选课提醒', actionType: '发布', target: '通知 · 第二轮正选开放', timestamp: '2026-05-27 09:40:18', result: 'success', ip: '10.21.7.91' },
  { id: 'log-02', operatorName: '岳明远', operatorId: 'A20251033', action: '删除草稿通知', actionType: '删除', target: '通知草稿 · 校历调整', timestamp: '2026-05-26 17:55:24', result: 'success', ip: '10.21.5.40' },
  { id: 'log-01', operatorName: '审计员·郑舟', operatorId: 'A20250003', action: '登录管理控制台', actionType: '登录', target: '管理后台', timestamp: '2026-05-26 08:30:00', result: 'success', ip: '10.21.9.12' }
];
