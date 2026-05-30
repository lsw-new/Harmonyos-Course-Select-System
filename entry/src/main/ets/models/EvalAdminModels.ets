// 评教管理模型 · Évaluation Admin
// 独立于 models/Admin.ets（共享文件），为评教管理子页定义专属类型。

// 单个评分档位（5★..1★）及其计数
export interface RatingBucket {
  star: number;
  count: number;
}

// 评教统计：含真实评分分布、参与/完成率、平均分、评教期开关
export interface EvalAdminStats {
  term: string;
  periodOpen: boolean;
  participationRate: number;
  completionRate: number;
  averageScore: number;
  ratingDistribution: RatingBucket[];
}

// 问卷模板状态
export type TemplateStatus = 'enabled' | 'disabled';

// 问卷模板
export interface QuestionnaireTemplate {
  id: string;
  name: string;
  description: string;
  questionCount: number;
  status: TemplateStatus;
}

// 新建/编辑问卷模板入参
export interface TemplateWritePayload {
  name: string;
  description: string;
  questionCount: number;
  status: TemplateStatus;
}
