// 成绩 / 考试 / 学籍

import { BaseRepository } from './BaseRepository';
import { GradeRecord, GradeSummary, ExamArrangement, StudentRecord, GradePublishStatus } from '../models/Academic';
import { mockGrades, mockGradeSummary, mockExams, mockStudentRecord } from '../mock/mockAcademic';
import { AppDatabase } from '../common/storage/AppDatabase';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteGrade, RemoteExam, RemoteStudentRecord } from '../common/remote/RemoteApi';

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

  // number|string 联合字段取数值（'合格' 等文字成绩返回 NaN 不参与计算）
  private static asNumeric(value: number | string | undefined): number {
    if (typeof value === 'number') {
      return value;
    }
    return Number.NaN;
  }

  async getGradeSummary(term?: string): Promise<GradeSummary> {
    // 联机模式：汇总由真实成绩单实时计算（学分/加权均分/绩点与成绩列表恒一致）
    if (AppConfig.useRemote && SessionStorage.get().getStudent()) {
      try {
        const grades = await this.getGrades(term);
        let credits = 0;
        let weightedSum = 0;
        let creditSum = 0;
        let gpaSum = 0;
        let gpaCredits = 0;
        grades.forEach((g) => {
          const score = AcademicRepository.asNumeric(g.finalScore ?? g.totalScore);
          if (!Number.isFinite(score)) {
            return;
          }
          if (score >= 60) {
            credits += g.credit;
          }
          weightedSum += score * g.credit;
          creditSum += g.credit;
          const point = AcademicRepository.asNumeric(g.gradePoint);
          if (Number.isFinite(point)) {
            gpaSum += point * g.credit;
            gpaCredits += g.credit;
          }
        });
        const avg = creditSum > 0 ? Math.round((weightedSum / creditSum) * 10) / 10 : 0;
        const gpa = gpaCredits > 0 ? Math.round((gpaSum / gpaCredits) * 100) / 100 : 0;
        const computed: GradeSummary = {
          term: term ?? '2025-2026-2',
          earnedCredits: credits,
          weightedAverage: avg,
          termGpa: gpa,
          totalGpa: gpa
        };
        return this.delayCopy<GradeSummary>(computed);
      } catch (e) {
        // 远程失败回退本地汇总
      }
    }
    const t = term ?? '2025-2026-2';
    const found = mockGradeSummary.find((s) => s.term === t) ?? mockGradeSummary[0];
    return this.delayCopy<GradeSummary>(found);
  }

  async getExams(term?: string): Promise<ExamArrangement[]> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.listExams(student.studentId, term);
          return this.delayCopy<ExamArrangement[]>(remote.map((e: RemoteExam): ExamArrangement => {
            const item: ExamArrangement = {
              id: e.examId,
              term: e.term,
              courseName: e.courseName,
              examType: e.examType,
              date: e.examDate,
              startTime: e.startTime,
              endTime: e.endTime,
              classroom: e.location,
              seatNo: e.seatNo
            };
            return item;
          }));
        } catch (e) {
          if (!AppConfig.allowMockFallbackInRemote) {
            throw new Error('远程服务异常，请稍后重试');
          }
        }
      }
    }
    let items = mockExams;
    if (term && term !== '全部') {
      items = items.filter((e) => e.term === term);
    }
    return this.delayCopy<ExamArrangement[]>(items);
  }

  // 提交成绩申诉（gradeId = 成绩行 id）。remote 模式走后端，失败按配置抛错。
  async submitAppeal(gradeId: string, reason: string): Promise<boolean> {
    if (reason.trim().length === 0) {
      return this.reject('请填写复核理由');
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.submitGradeAppeal(gradeId, reason.trim());
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    // 非 remote：本地无申诉存储，按演示直接视为已提交
    return this.delay<boolean>(true);
  }

  async getStudentRecord(): Promise<StudentRecord> {
    // 基础学籍字段与会话真实资料同源（姓名/学号/学院/专业/班级/年级），
    // 其余档案字段（学制/类别等）后端暂无，沿用演示模板。
    const record = await this.delayCopy<StudentRecord>(mockStudentRecord);
    const student = SessionStorage.get().getStudent();
    if (student) {
      record.studentId = student.studentId;
      record.name = student.name;
      record.college = student.college;
      record.administrativeCollege = student.college;
      record.major = student.major;
      record.className = student.className;
      record.grade = student.grade;
      const year = student.grade.replace('级', '').trim();
      if (year.length === 4) {
        record.entranceDate = `${year}-09-01`;
      }
    }
    // remote：补真实身份与 GPA/已修学分/门数（后端按已发布成绩实时聚合）；
    // 失败时不阻断学籍页（保留 session/mock 兜底，GPA 行显示「—」）。
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.studentRecord();
        record.studentId = remote.studentId;
        record.name = remote.name;
        record.college = remote.college;
        record.administrativeCollege = remote.college;
        record.major = remote.major;
        record.className = remote.className;
        record.grade = remote.grade;
        record.gpaText = (remote.gpa !== null) ? remote.gpa.toFixed(2) : '—';
        record.earnedCredits = remote.earnedCredits;
        record.passedCount = remote.passedCount;
      } catch (e) {
        // 远程失败：保留兜底，学籍页仍可展示身份字段
      }
    }
    return record;
  }
}
