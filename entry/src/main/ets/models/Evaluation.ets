// 量化评教

export type EvaluationStatus = 'open' | 'submitted' | 'closed';

export interface EvaluationOption {
  id: string;
  label: string;
  score?: number;
}

export interface EvaluationTask {
  id: string;
  term: string;
  courseCode: string;
  courseName: string;
  courseCategory: string;
  teacherName: string;
  questionnaireName: string;
  status: EvaluationStatus;
  openTime?: string;
  closeTime?: string;
  closedReason?: string;
}

export interface EvaluationQuestion {
  id: string;
  type: 'single' | 'multiple' | 'rating' | 'text';
  title: string;
  required: boolean;
  options?: EvaluationOption[];
  maxLength?: number;
}

export interface EvaluationAnswer {
  questionId: string;
  value: string | string[] | number;
}

export interface EvaluationQuestionnaire {
  taskId: string;
  title: string;
  description?: string;
  questions: EvaluationQuestion[];
}
