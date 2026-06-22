// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，所有数据均为人工编造，不代表任何真实选课轮次或冲突记录。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下选课轮次管理数据由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

// 选课轮次管理 · Mock 数据
// 提供 4 个不同状态的轮次以及若干冲突明细，作为本地存储的回退种子。

import { AdminRound, RoundConflict } from '../models/SelectionAdminModels';

export const mockAdminRounds: AdminRound[] = [
  {
    id: 'ar-1', name: '第一轮预选', status: 'ended',
    startTime: '2026-04-10 09:00', endTime: '2026-04-15 23:59',
    progressPercent: 100, participantCount: 11800, selectionCount: 38962,
    averageCredit: 22.4, conflictCount: 3
  },
  {
    id: 'ar-2', name: '第二轮正选', status: 'running',
    startTime: '2026-05-20 09:00', endTime: '2026-05-30 23:59',
    progressPercent: 68, participantCount: 8124, selectionCount: 21540,
    averageCredit: 19.8, conflictCount: 2
  },
  {
    id: 'ar-3', name: '第三轮补退选', status: 'paused',
    startTime: '2026-06-01 09:00', endTime: '2026-06-04 23:59',
    progressPercent: 32, participantCount: 3260, selectionCount: 7180,
    averageCredit: 15.2, conflictCount: 1
  },
  {
    id: 'ar-4', name: '暑期重修选课', status: 'notStarted',
    startTime: '2026-06-20 09:00', endTime: '2026-06-26 23:59',
    progressPercent: 0, participantCount: 0, selectionCount: 0,
    averageCredit: 0, conflictCount: 0
  }
];

export const mockRoundConflicts: RoundConflict[] = [
  {
    id: 'cf-1', roundId: 'ar-1', studentName: '林清浅', studentId: '2023010188',
    courseA: '高等数学(2) 周一 1-2 节', courseB: '大学物理 周一 1-2 节'
  },
  {
    id: 'cf-2', roundId: 'ar-1', studentName: '苏曼殊', studentId: '2023010204',
    courseA: '数据结构 周三 3-4 节', courseB: '离散数学 周三 3-4 节'
  },
  {
    id: 'cf-3', roundId: 'ar-1', studentName: '陈一鸣', studentId: '2022030771',
    courseA: '操作系统 周五 5-6 节', courseB: '编译原理 周五 5-6 节'
  },
  {
    id: 'cf-4', roundId: 'ar-2', studentName: '周墨白', studentId: '2023010312',
    courseA: '线性代数 周二 1-2 节', courseB: '概率统计 周二 1-2 节'
  },
  {
    id: 'cf-5', roundId: 'ar-2', studentName: '叶知秋', studentId: '2023011045',
    courseA: '计算机网络 周四 7-8 节', courseB: '软件工程 周四 7-8 节'
  },
  {
    id: 'cf-6', roundId: 'ar-3', studentName: '何向晚', studentId: '2024020559',
    courseA: '大学英语(4) 周一 3-4 节', courseB: '体育(羽毛球) 周一 3-4 节'
  }
];
