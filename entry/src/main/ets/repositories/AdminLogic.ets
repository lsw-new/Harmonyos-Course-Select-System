// 管理端域纯逻辑（无状态、不依赖会话/RDB/网络/鉴权）：课程与成绩的校验/净化/规范化、
// 成绩状态机判定、列表合并、远程 DTO→模型映射。从 AdminRepository 平移（行为不变），
// 便于复用与单测；有状态的取数/持久化/鉴权/RemoteApi 编排仍在 AdminRepository。

import {
  AdminCourseItem, AdminCourseWritePayload, GradeAuditItem, GradeAuditStatus,
  ApprovalItem, ApprovalStatus, StudentAdminItem, StudentAdminStatus, StudentEducationLevel
} from '../models/Admin';
import { RemoteStudent, RemoteGradeTask, RemoteApproval } from '../common/remote/RemoteApi';

const COURSE_CATEGORIES: string[] = ['required', 'elective', 'public', 'practice'];
const COURSE_STATUSES: string[] = ['draft', 'open', 'closed', 'archived'];
const GRADE_STATUSES: string[] = ['pendingAudit', 'inputting', 'published', 'appealed', 'rejected'];
const COURSE_CODE_PATTERN: RegExp = new RegExp('^[A-Za-z0-9_-]{2,32}$');
const CONTROL_CHAR_PATTERN: RegExp = new RegExp('[\\r\\n\\u0000-\\u001f\\u007f]');

export class AdminLogic {
  static isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  static hasOneDecimalAtMost(value: number): boolean {
    return Math.round(value * 10) === value * 10;
  }

  static isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  static isAllowedCourseCategory(value: string): boolean {
    return COURSE_CATEGORIES.indexOf(value) >= 0;
  }

  static isAllowedCourseStatus(value: string): boolean {
    return COURSE_STATUSES.indexOf(value) >= 0;
  }

  static isAllowedGradeStatus(value: string): boolean {
    return GRADE_STATUSES.indexOf(value) >= 0;
  }

  static shouldHaveCompleteGradeInput(status: string): boolean {
    return status === 'pendingAudit' || status === 'published' || status === 'rejected' || status === 'appealed';
  }

  static isValidRejectReason(value: string | undefined): boolean {
    return value !== undefined && AdminLogic.isCleanText(value, 1, 120);
  }

  static isValidInputProgress(value: number): boolean {
    return AdminLogic.isFiniteNumber(value) && Math.floor(value) === value && value >= 0 && value <= 100;
  }

  static normalizeRejectReason(reason: string): string {
    return reason.trim();
  }

  static validateRejectReason(reason: string): string {
    if (!AdminLogic.isCleanText(reason, 1, 120)) {
      return '驳回理由需为 1-120 字且不能包含换行或控制字符';
    }
    return '';
  }

  static canInputGradeStatus(status: string): boolean {
    return status === 'inputting' || status === 'rejected' || status === 'appealed';
  }

  static toGradeStatusByProgress(inputProgress: number): 'inputting' | 'pendingAudit' {
    return inputProgress === 100 ? 'pendingAudit' : 'inputting';
  }

  static isValidStoredCourse(item: AdminCourseItem): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!AdminLogic.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (typeof item.code !== 'string' || !COURSE_CODE_PATTERN.test(item.code.trim())) {
      return false;
    }
    if (!AdminLogic.isCleanText(item.name, 1, 64) || !AdminLogic.isCleanText(item.teacher, 1, 32) || !AdminLogic.isCleanText(item.timeText, 1, 80)) {
      return false;
    }
    if (!AdminLogic.isAllowedCourseCategory(item.category) || !AdminLogic.isAllowedCourseStatus(item.status)) {
      return false;
    }
    if (!AdminLogic.isFiniteNumber(item.credit) || item.credit <= 0 || item.credit > 20 || !AdminLogic.hasOneDecimalAtMost(item.credit)) {
      return false;
    }
    if (!AdminLogic.isFiniteNumber(item.capacity) || Math.floor(item.capacity) !== item.capacity || item.capacity < 1 || item.capacity > 10000) {
      return false;
    }
    if (!AdminLogic.isFiniteNumber(item.selectedCount) || Math.floor(item.selectedCount) !== item.selectedCount || item.selectedCount < 0 || item.selectedCount > item.capacity) {
      return false;
    }
    return true;
  }

  static sanitizeCourseItems(items: AdminCourseItem[]): AdminCourseItem[] {
    return items.filter((item) => AdminLogic.isValidStoredCourse(item)).map((item) => {
      const sanitized: AdminCourseItem = {
        id: item.id.trim(),
        code: item.code.trim(),
        name: item.name.trim(),
        teacher: item.teacher.trim(),
        category: item.category,
        credit: item.credit,
        timeText: item.timeText.trim(),
        capacity: item.capacity,
        selectedCount: item.selectedCount,
        status: item.status
      };
      return sanitized;
    });
  }

  static isValidStoredGrade(item: GradeAuditItem): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!AdminLogic.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (!AdminLogic.isCleanText(item.courseName, 1, 80) || !AdminLogic.isCleanText(item.teachingClassName, 1, 80) || !AdminLogic.isCleanText(item.teacherName, 1, 32)) {
      return false;
    }
    if (!AdminLogic.isCleanText(item.updatedAt, 1, 40)) {
      return false;
    }
    if (!AdminLogic.isValidInputProgress(item.inputProgress) || !AdminLogic.isAllowedGradeStatus(item.status)) {
      return false;
    }
    if (AdminLogic.shouldHaveCompleteGradeInput(item.status) && item.inputProgress !== 100) {
      return false;
    }
    if (item.status === 'rejected' && !AdminLogic.isValidRejectReason(item.rejectReason)) {
      return false;
    }
    return true;
  }

  static sanitizeGradeItems(items: GradeAuditItem[]): GradeAuditItem[] {
    const ids: string[] = [];
    const sanitized: GradeAuditItem[] = [];
    items.forEach((item) => {
      if (!AdminLogic.isValidStoredGrade(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: GradeAuditItem = {
        id: id,
        courseName: item.courseName.trim(),
        teachingClassName: item.teachingClassName.trim(),
        teacherName: item.teacherName.trim(),
        inputProgress: item.inputProgress,
        status: item.status,
        updatedAt: item.updatedAt.trim()
      };
      const rejectReason = item.rejectReason;
      if (item.status === 'rejected' && rejectReason !== undefined && AdminLogic.isValidRejectReason(rejectReason)) {
        next.rejectReason = rejectReason.trim();
      }
      sanitized.push(next);
    });
    return sanitized;
  }

  static validateCoursePayload(payload: AdminCourseWritePayload, items: AdminCourseItem[], editingId?: string): string {
    const code = payload.code.trim();
    const name = payload.name.trim();
    const teacher = payload.teacher.trim();
    const timeText = payload.timeText.trim();
    if (!COURSE_CODE_PATTERN.test(code)) {
      return '课程代码需为 2-32 位字母、数字、下划线或短横线';
    }
    if (!AdminLogic.isCleanText(name, 1, 64)) {
      return '课程名称需为 1-64 字且不能包含换行或控制字符';
    }
    if (!AdminLogic.isCleanText(teacher, 1, 32)) {
      return '教师需为 1-32 字且不能包含换行或控制字符';
    }
    if (!AdminLogic.isCleanText(timeText, 1, 80)) {
      return '上课时间需为 1-80 字且不能包含换行或控制字符';
    }
    if (!AdminLogic.isAllowedCourseCategory(payload.category)) {
      return '课程类型不合法';
    }
    if (!AdminLogic.isAllowedCourseStatus(payload.status)) {
      return '课程状态不合法';
    }
    if (!AdminLogic.isFiniteNumber(payload.credit) || payload.credit <= 0 || payload.credit > 20 || !AdminLogic.hasOneDecimalAtMost(payload.credit)) {
      return '学分需大于 0 且不超过 20，最多一位小数';
    }
    if (!AdminLogic.isFiniteNumber(payload.capacity) || Math.floor(payload.capacity) !== payload.capacity || payload.capacity < 1 || payload.capacity > 10000) {
      return '容量需为 1-10000 的整数';
    }
    if (!AdminLogic.isFiniteNumber(payload.selectedCount) || Math.floor(payload.selectedCount) !== payload.selectedCount || payload.selectedCount < 0 || payload.selectedCount > payload.capacity) {
      return '已选人数需为 0 到容量之间的整数';
    }
    const duplicated = items.some((item) => item.id !== editingId && item.code.toLowerCase() === code.toLowerCase());
    if (duplicated) {
      return '课程代码已存在';
    }
    const hasTeacherConflict = items.some((item) => item.id !== editingId && item.teacher.trim() === teacher && item.timeText.trim() === timeText);
    if (hasTeacherConflict) {
      return '同一教师在该时间已有课程';
    }
    return '';
  }

  static normalizeCoursePayload(payload: AdminCourseWritePayload): AdminCourseWritePayload {
    return {
      code: payload.code.trim(),
      name: payload.name.trim(),
      teacher: payload.teacher.trim(),
      category: payload.category,
      credit: payload.credit,
      timeText: payload.timeText.trim(),
      capacity: payload.capacity,
      selectedCount: payload.selectedCount,
      status: payload.status
    };
  }

  // 合并 grade 列表，以 localItems 中的条目优先（local 覆盖 seed 同 id）
  static mergeGradeItems(localItems: GradeAuditItem[], seedItems: GradeAuditItem[]): GradeAuditItem[] {
    const result: GradeAuditItem[] = JSON.parse(JSON.stringify(localItems)) as GradeAuditItem[];
    seedItems.forEach((item) => {
      const exists = result.some((cur) => cur.id === item.id);
      if (!exists) {
        result.push(item);
      }
    });
    return result;
  }

  static mergeApprovalItems(localItems: ApprovalItem[], seedItems: ApprovalItem[]): ApprovalItem[] {
    const result: ApprovalItem[] = JSON.parse(JSON.stringify(localItems)) as ApprovalItem[];
    seedItems.forEach((item) => {
      const exists = result.some((cur) => cur.id === item.id);
      if (!exists) {
        result.push(item);
      }
    });
    return result;
  }

  // ===== Track B 管理端远程映射 =====
  static remoteToStudent(s: RemoteStudent): StudentAdminItem {
    const item: StudentAdminItem = {
      studentId: s.studentId,
      name: s.name,
      college: s.college,
      major: s.major,
      className: s.className,
      status: s.status as StudentAdminStatus,
      educationLevel: s.educationLevel as StudentEducationLevel
    };
    return item;
  }

  static remoteToGradeTask(t: RemoteGradeTask): GradeAuditItem {
    const item: GradeAuditItem = {
      id: t.id,
      courseName: t.courseName,
      teachingClassName: t.teachingClassName,
      teacherName: t.teacherName,
      inputProgress: t.inputProgress,
      status: t.status as GradeAuditStatus,
      updatedAt: t.updatedAt
    };
    if (t.rejectReason !== undefined && t.rejectReason.length > 0) {
      item.rejectReason = t.rejectReason;
    }
    return item;
  }

  static remoteToApproval(a: RemoteApproval): ApprovalItem {
    const item: ApprovalItem = {
      id: a.id,
      type: a.type,
      applicantName: a.applicantName,
      applicantId: a.applicantId,
      title: a.title,
      reason: a.reason,
      status: a.status as ApprovalStatus,
      isUrgent: a.isUrgent,
      submittedAt: a.submittedAt
    };
    return item;
  }
}
