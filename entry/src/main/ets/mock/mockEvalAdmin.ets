// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，所有数据均为人工编造，不代表任何真实用户、机构或业务结果。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下评教管理数据由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

// 评教管理 Mock 数据 · Évaluation Admin
// 独立于 mock/mockAdmin.ets（共享文件），为评教管理子页提供专属 mock。

import { EvalAdminStats, RatingBucket, QuestionnaireTemplate } from '../models/EvalAdminModels';

// 真实评分分布（5★..1★），由此计算柱状图，而非页面写死。
export const mockRatingDistribution: RatingBucket[] = [
  { star: 5, count: 1842 },
  { star: 4, count: 1536 },
  { star: 3, count: 658 },
  { star: 2, count: 219 },
  { star: 1, count: 131 }
];

// 评教统计基线（periodOpen 由本地持久化覆盖）
export const mockEvalAdminStats: EvalAdminStats = {
  term: '2025-2026-2',
  periodOpen: true,
  participationRate: 62.4,
  completionRate: 38.7,
  averageScore: 4.32,
  ratingDistribution: mockRatingDistribution
};

// 问卷模板基线（持久化 key 缺省时回退到此）
export const mockEvalTemplates: QuestionnaireTemplate[] = [
  { id: 'qt-1', name: '理工类课程通用评教问卷', description: '面向理工科课程的教学质量评价。', questionCount: 18, status: 'enabled' },
  { id: 'qt-2', name: '人文社科类课程评教问卷', description: '侧重课堂互动与思辨引导的评价维度。', questionCount: 16, status: 'enabled' },
  { id: 'qt-3', name: '语言类课程评教问卷', description: '聚焦听说读写训练与语言环境营造。', questionCount: 14, status: 'enabled' },
  { id: 'qt-4', name: '实践类课程评教问卷（草稿）', description: '面向实验、实训与社会实践环节。', questionCount: 12, status: 'disabled' }
];
