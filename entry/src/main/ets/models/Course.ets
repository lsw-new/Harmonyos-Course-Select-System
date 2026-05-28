// 课程与课表 / 选课模型

export interface CourseAssessment {
  usual: number;
  experiment: number;
  finalDefense: number;
}

export interface Course {
  id: string;
  code: string;
  teachingClassNo: string;
  name: string;
  category: string;
  credit: number;
  teacher: string;
  college: string;
  campus?: string;
  classroom: string;
  weeks: string;
  periodStart: number;
  periodEnd: number;
  weekday: number;
  capacity?: number;
  selectedCount?: number;
  description?: string;
  assessment?: CourseAssessment;
}

export interface ScheduleItem {
  id: string;
  term: string;
  type: 'normal' | 'practice';
  courseId: string;
  courseName: string;
  teacher: string;
  weekday: number;
  periodStart: number;
  periodEnd: number;
  startTime: string;
  endTime: string;
  classroom: string;
  campus?: string;
  weeks: number[];
  weekText: string;
  courseType: string;
}

export type SelectionStatus = 'available' | 'selected' | 'full' | 'conflict';

export interface SelectionCourse {
  course: Course;
  status: SelectionStatus;
  conflictWith?: string;
}

export interface SelectionRoundInfo {
  roundName: string;
  startTime: string;
  endTime: string;
  remainingSeconds: number;
  selectedCredits: number;
  creditLimit: number;
  inProgress: boolean;
}
