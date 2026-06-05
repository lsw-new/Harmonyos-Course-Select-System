// 成绩 / 考试 / 学籍

import { BaseRepository } from './BaseRepository';
import { GradeRecord, GradeSummary, ExamArrangement, StudentRecord, GradePublishStatus } from '../models/Academic';
import { mockGrades, mockGradeSummary, mockExams, mockStudentRecord } from '../mock/mockAcademic';
import { AppDatabase } from '../common/storage/AppDatabase';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteGrade } from '../common/remote/RemoteApi';

export class AcademicRepository extends BaseRepository {
  private static _instance?: AcademicRepository;
  static get(): AcademicRepository {
    if (!AcademicRepository._instance) {
      AcademicRepository._instance = new AcademicRepository();
    }
    return AcademicRepository._instance;
  }

  // 从 RDB grades 表读取当前学生已发布成绩（JOIN courses 取课程信息）
  private async getGradesFromRdb(studentId: string, term?: string): Promise<GradeRecord[]> {
    let termWhere = '';
    if (term && term !== '全部') {
      termWhere = `AND g.term = ${AppDatabase.sqlText(term)}`;
    }
    const resultSet = await AppDatabase.query(
      `SELECT
         g.grade_id,
         g.term,
         COALESCE(c.code, '') AS course_code,
         COALESCE(c.teaching_class_no, '') AS teaching_class_no,
         COALESCE(c.name, '') AS course_name,
         COALESCE(c.category, '') AS course_category,
         COALESCE(c.credit, 0) AS credit,
         g.score,
         g.grade_point,
         g.status,
         COALESCE(g.published_at, '') AS published_at
       FROM grades g
       LEFT JOIN courses c ON c.course_id = g.course_id
       WHERE g.student_id = ${AppDatabase.sqlText(studentId)}
         AND g.status = 'published'
         ${termWhere}
       ORDER BY g.created_at DESC`
    );
    const items: GradeRecord[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const status = resultSet.getString(resultSet.getColumnIndex('status')) as GradePublishStatus;
        const publishedAt = resultSet.getString(resultSet.getColumnIndex('published_at'));
        const item: GradeRecord = {
          id: resultSet.getString(resultSet.getColumnIndex('grade_id')),
          term: resultSet.getString(resultSet.getColumnIndex('term')),
          courseCode: resultSet.getString(resultSet.getColumnIndex('course_code')),
          teachingClassNo: resultSet.getString(resultSet.getColumnIndex('teaching_class_no')),
          courseName: resultSet.getString(resultSet.getColumnIndex('course_name')),
          courseCategory: resultSet.getString(resultSet.getColumnIndex('course_category')),
          credit: resultSet.getDouble(resultSet.getColumnIndex('credit')),
          totalScore: resultSet.getDouble(resultSet.getColumnIndex('score')),
          finalScore: resultSet.getDouble(resultSet.getColumnIndex('score')),
          gradePoint: resultSet.getDouble(resultSet.getColumnIndex('grade_point')),
          status: status
        };
        if (publishedAt.length > 0) {
          item.publishedAt = publishedAt;
        }
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  private mapGradeCategory(c: string): string {
    if (c === 'required') {
      return '必修';
    }
    if (c === 'elective') {
      return '选修';
    }
    if (c === 'public') {
      return '公选';
    }
    if (c === 'practice') {
      return '实践';
    }
    return c;
  }

  private remoteToGrade(g: RemoteGrade): GradeRecord {
    const item: GradeRecord = {
      id: g.id,
      term: g.term,
      courseCode: g.courseCode,
      teachingClassNo: g.teachingClassNo,
      courseName: g.courseName,
      courseCategory: this.mapGradeCategory(g.courseCategory),
      credit: g.credit,
      totalScore: g.score,
      finalScore: g.score,
      gradePoint: g.gradePoint,
      rank: g.rank,
      status: 'published'
    };
    if (g.publishedAt.length > 0) {
      item.publishedAt = g.publishedAt;
    }
    return item;
  }

  async getGrades(term?: string): Promise<GradeRecord[]> {
    if (AppConfig.useRemote) {
      const remoteStudent = SessionStorage.get().getStudent();
      if (remoteStudent) {
        try {
          const remote = await RemoteApi.listGrades(remoteStudent.studentId, term);
          const remoteItems: GradeRecord[] = remote.map((g) => this.remoteToGrade(g));
          return this.delayCopy<GradeRecord[]>(remoteItems);
        } catch (e) {
          // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
          if (!AppConfig.allowMockFallbackInRemote) {
            throw new Error('远程服务异常，请稍后重试');
          }
          // 否则回退本地
        }
      }
    }
    if (AppDatabase.isReady()) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        const rdbItems = await this.getGradesFromRdb(student.studentId, term);
        // RDB 分支：若成绩表已有数据则直接返回；否则降级到 mock（成绩可能尚未录入）
        if (rdbItems.length > 0) {
          return rdbItems;
        }
      }
    }
    // mock 兜底：只返回 status === 'published' 的成绩
    let items = mockGrades.filter((g) => g.status === 'published');
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
