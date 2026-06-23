// 学籍管理仓储 · 拥有学生名册（单一数据源）
// 列表与详情共享同一份 StudentDetail 名册，学籍状态变更后两端即时一致。
// 名册经 LocalDataStore 持久化（key: local.adminStudents.v1），重启后保留。
// 无权限门禁；所有返回值均为深拷贝。

import { BaseRepository } from './BaseRepository';
import { StudentAdminItem, StudentAdminStatus, StudentEducationLevel } from '../models/Admin';
import { StudentDetail, StudentStatus } from '../models/StudentDetailModels';
import { mockStudentDetails } from '../mock/mockStudentDetail';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { AuthorizationService } from '../common/security/AuthorizationService';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteStudent, RemoteStudentDetail } from '../common/remote/RemoteApi';

const KEY_ADMIN_STUDENTS = 'local.adminStudents.v1';
const STUDENT_STATUSES: string[] = ['active', 'suspended', 'graduating', 'graduated'];

export class StudentAdminRepository extends BaseRepository {
  private static _instance?: StudentAdminRepository;
  static get(): StudentAdminRepository {
    if (!StudentAdminRepository._instance) {
      StudentAdminRepository._instance = new StudentAdminRepository();
    }
    return StudentAdminRepository._instance;
  }

  private roster: StudentDetail[] = JSON.parse(JSON.stringify(mockStudentDetails)) as StudentDetail[];
  private isLoaded: boolean = false;

  private cloneSeed(): StudentDetail[] {
    return JSON.parse(JSON.stringify(mockStudentDetails)) as StudentDetail[];
  }

  private isAllowedStatus(value: string): boolean {
    return STUDENT_STATUSES.indexOf(value) >= 0;
  }

  private isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  private isNonEmptyString(value: string): boolean {
    return typeof value === 'string' && value.trim().length > 0;
  }

  private isValidStored(item: StudentDetail): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isNonEmptyString(item.studentId) || !this.isNonEmptyString(item.name)) {
      return false;
    }
    if (!this.isAllowedStatus(item.status)) {
      return false;
    }
    if (!this.isFiniteNumber(item.gpa) || !this.isFiniteNumber(item.earnedCredits) || !this.isFiniteNumber(item.totalCredits)) {
      return false;
    }
    return true;
  }

  private sanitize(items: StudentDetail[]): StudentDetail[] {
    const ids: string[] = [];
    const result: StudentDetail[] = [];
    items.forEach((item) => {
      if (!this.isValidStored(item)) {
        return;
      }
      const id = item.studentId.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      result.push(item);
    });
    return result;
  }

  private async getRoster(): Promise<StudentDetail[]> {
    if (!this.isLoaded) {
      const stored = await LocalDataStore.loadArray<StudentDetail>(KEY_ADMIN_STUDENTS, mockStudentDetails);
      const sanitized = this.sanitize(stored);
      this.roster = sanitized.length > 0 ? sanitized : this.cloneSeed();
      this.isLoaded = true;
    }
    return this.roster;
  }

  private async saveRoster(next: StudentDetail[]): Promise<void> {
    this.roster = next;
    this.isLoaded = true;
    await LocalDataStore.saveArray<StudentDetail>(KEY_ADMIN_STUDENTS, next);
  }

  private toListItem(detail: StudentDetail): StudentAdminItem {
    const level: StudentEducationLevel = detail.grade.indexOf('研') >= 0 ? 'postgraduate' : 'undergraduate';
    const item: StudentAdminItem = {
      studentId: detail.studentId,
      name: detail.name,
      college: detail.college,
      major: detail.major,
      className: detail.className,
      gpa: detail.gpa,
      status: detail.status as StudentAdminStatus,
      educationLevel: level
    };
    return item;
  }

  // 远程列表行 → 学籍列表项（status/educationLevel 后端词表与本地一致）
  private remoteToListItem(r: RemoteStudent): StudentAdminItem {
    const item: StudentAdminItem = {
      studentId: r.studentId,
      name: r.name,
      college: r.college,
      major: r.major,
      className: r.className,
      status: r.status as StudentAdminStatus,
      educationLevel: r.educationLevel as StudentEducationLevel
    };
    return item;
  }

  // 远程档案 → 学籍详情（后端 student_profiles 暂无 GPA/学分/宿舍/导师字段，相关字段以默认值填充展示）
  // 待办：待后端扩展档案字段后，从响应中读取真实值（前置条件：后端 /api/admin/students/:id 返回完整档案）
  private remoteToDetail(r: RemoteStudentDetail): StudentDetail {
    const yearText = r.grade.replace('级', '').trim();
    const detail: StudentDetail = {
      studentId: r.studentId,
      name: r.name,
      gender: '—',
      college: r.college,
      major: r.major,
      className: r.className,
      grade: r.grade,
      gpa: 0,
      earnedCredits: 0,
      totalCredits: 0,
      phone: r.phone,
      email: r.email,
      dormitory: '—',
      advisor: '—',
      status: 'active',
      enrollDate: yearText.length === 4 ? `${yearText}-09-01` : '—'
    };
    return detail;
  }

  async getStudents(query?: string, college?: string): Promise<StudentAdminItem[]> {
    if (AppConfig.useRemote) {
      try {
        // 后端 student_profiles 为唯一名单来源：只显示真实注册的学生
        const remote = await RemoteApi.adminListStudents(query, college);
        return this.delayCopy<StudentAdminItem[]>(remote.map((r) => this.remoteToListItem(r)));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 远程失败回退本地名册
      }
    }
    const roster = await this.getRoster();
    let items: StudentAdminItem[] = roster.map((detail) => this.toListItem(detail));
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.name.toLowerCase().includes(q) ||
        s.studentId.toLowerCase().includes(q) ||
        s.className.toLowerCase().includes(q)
      );
    }
    if (college && college !== '全部') {
      items = items.filter((s) => s.college === college);
    }
    return this.delayCopy<StudentAdminItem[]>(items);
  }

  async getDetail(studentId: string): Promise<StudentDetail> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminStudentDetail(studentId);
        return this.delayCopy<StudentDetail>(this.remoteToDetail(remote));
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e), 'notFound');
      }
    }
    const roster = await this.getRoster();
    const target = roster.find((s) => s.studentId === studentId);
    if (!target) {
      return this.reject('学生不存在', 'notFound');
    }
    return this.delayCopy<StudentDetail>(target);
  }

  // 学籍状态合法流转：在读 -> 休学 / 毕业班；休学 -> 在读（复学）；毕业班 -> 已毕业。
  private isValidTransition(current: StudentStatus, next: StudentStatus): boolean {
    if (current === next) {
      return false;
    }
    if (current === 'active') {
      return next === 'suspended' || next === 'graduating';
    }
    if (current === 'suspended') {
      return next === 'active';
    }
    if (current === 'graduating') {
      return next === 'graduated';
    }
    return false;
  }

  async updateStatus(studentId: string, nextStatus: StudentStatus): Promise<StudentDetail> {
    if (!AuthorizationService.hasAdminPermission('students.manage', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    if (AppConfig.useRemote) {
      // \u5f85\u529e\uff1a\u540e\u7aef student_profiles \u6682\u65e0\u5b66\u7c4d\u72b6\u6001\u5b57\u6bb5\uff0cremote \u6a21\u5f0f\u4e0b\u672c\u5730\u4fee\u6539\u65e0\u6cd5\u540c\u6b65\u670d\u52a1\u5668\uff0c\u6682\u4e0d\u652f\u6301\uff08\u524d\u7f6e\u6761\u4ef6\uff1a\u540e\u7aef\u6269\u5c55\u5b66\u7c4d\u72b6\u6001\u5b57\u6bb5\u5e76\u63d0\u4f9b\u53d8\u66f4\u63a5\u53e3\uff09
      return this.reject('\u8054\u673a\u6a21\u5f0f\u6682\u4e0d\u652f\u6301\u5b66\u7c4d\u72b6\u6001\u53d8\u66f4\uff08\u670d\u52a1\u5668\u6863\u6848\u65e0\u8be5\u5b57\u6bb5\uff09');
    }
    if (!this.isAllowedStatus(nextStatus)) {
      return this.reject('学籍状态不合法');
    }
    const roster = await this.getRoster();
    const target = roster.find((s) => s.studentId === studentId);
    if (!target) {
      return this.reject('学生不存在', 'notFound');
    }
    if (!this.isValidTransition(target.status, nextStatus)) {
      return this.reject('当前学籍状态不可执行该操作');
    }
    let updated: StudentDetail = target;
    const next = roster.map((item) => {
      if (item.studentId !== studentId) {
        return item;
      }
      const copy: StudentDetail = {
        studentId: item.studentId,
        name: item.name,
        gender: item.gender,
        college: item.college,
        major: item.major,
        className: item.className,
        grade: item.grade,
        gpa: item.gpa,
        earnedCredits: item.earnedCredits,
        totalCredits: item.totalCredits,
        phone: item.phone,
        email: item.email,
        dormitory: item.dormitory,
        advisor: item.advisor,
        status: nextStatus,
        enrollDate: item.enrollDate
      };
      updated = copy;
      return copy;
    });
    await this.saveRoster(next);
    return this.delayCopy<StudentDetail>(updated);
  }
}
