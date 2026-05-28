// 成绩 / 考试 / 学籍

import { BaseRepository } from './BaseRepository';
import { GradeRecord, GradeSummary, ExamArrangement, StudentRecord } from '../models/Academic';
import { mockGrades, mockGradeSummary, mockExams, mockStudentRecord } from '../mock/mockAcademic';

export class AcademicRepository extends BaseRepository {
  private static _instance?: AcademicRepository;
  static get(): AcademicRepository {
    if (!AcademicRepository._instance) {
      AcademicRepository._instance = new AcademicRepository();
    }
    return AcademicRepository._instance;
  }

  async getGrades(term?: string): Promise<GradeRecord[]> {
    let items = mockGrades;
    if (term && term !== '全部') {
      items = items.filter((g) => g.term === term);
    }
    return this.delayCopy<GradeRecord[]>(items);
  }

  async getGradeSummary(term?: string): Promise<GradeSummary> {
    const t = term ?? '2025-2026-1';
    const found = mockGradeSummary.find((s) => s.term === t) ?? mockGradeSummary[0];
    return this.delayCopy<GradeSummary>(found);
  }

  async getExams(term?: string): Promise<ExamArrangement[]> {
    let items = mockExams;
    if (term && term !== '全部') {
      items = items.filter((e) => e.term === term);
    }
    return this.delayCopy<ExamArrangement[]>(items);
  }

  async getStudentRecord(): Promise<StudentRecord> {
    return this.delayCopy<StudentRecord>(mockStudentRecord);
  }
}
