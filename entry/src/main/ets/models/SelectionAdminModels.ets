// 选课轮次管理 · 数据模型
// 独立于 models/Admin.ets 的轮次类型，承载状态机 + 冲突明细。

export type RoundStatus = 'notStarted' | 'running' | 'paused' | 'ended';

// 选课轮次（管理视角）
export interface AdminRound {
  id: string;
  name: string;
  status: RoundStatus;
  startTime: string;
  endTime: string;
  progressPercent: number;
  participantCount: number;
  selectionCount: number;
  averageCredit: number;
  conflictCount: number;
}

// 选课冲突明细：某学生选了两门时间冲突的课
export interface RoundConflict {
  id: string;
  roundId: string;
  studentName: string;
  studentId: string;
  courseA: string;
  courseB: string;
}

// 编辑起止时间的提交负载
export interface RoundTimePayload {
  id: string;
  startTime: string;
  endTime: string;
}
