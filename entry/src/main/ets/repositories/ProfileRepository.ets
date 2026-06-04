// 个人资料、首页摘要、扩展服务

import { BaseRepository } from './BaseRepository';
import { UserProfile } from '../models/User';
import { ApprovalItem } from '../models/Admin';
import { HomeSummary } from '../models/Home';
import { LeaveRequest, FeedbackItem, PracticeEntry, LeaveType, FeedbackCategory, FeedbackState, ApprovalState } from '../models/Misc';
import { mockStudentProfile } from '../mock/mockUser';
import { mockHomeSummary } from '../mock/mockHome';
import { mockNotices } from '../mock/mockNotices';
import { mockLeaveRequests, mockFeedback, mockPracticeEntries } from '../mock/mockMisc';
import { NoticeStore } from '../common/services/NoticeStore';
import { AppDatabase } from '../common/storage/AppDatabase';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteLeave, RemoteFeedback } from '../common/remote/RemoteApi';

const KEY_LOCAL_LEAVES = 'local.leaveRequests.v1';
const KEY_LOCAL_FEEDBACK = 'local.feedback.v1';
const KEY_ADMIN_APPROVALS = 'local.adminApprovals.v1';

export interface ProfileEditPatch {
  avatarUrl?: string;
  phone?: string;
  email?: string;
  address?: string;
  emergencyContact?: string;
  bio?: string;
}

export interface LeaveSubmitForm {
  type: LeaveType;
  startDate: string;
  endDate: string;
  reason: string;
  attachments: string[];
}

export interface FeedbackSubmitForm {
  category: FeedbackCategory;
  title: string;
  content: string;
  contact: string;
  screenshots: string[];
}

export class ProfileRepository extends BaseRepository {
  private static _instance?: ProfileRepository;
  static get(): ProfileRepository {
    if (!ProfileRepository._instance) {
      ProfileRepository._instance = new ProfileRepository();
    }
    return ProfileRepository._instance;
  }

  private workingProfile: UserProfile = JSON.parse(JSON.stringify(mockStudentProfile)) as UserProfile;
  private localLeaves: LeaveRequest[] = [];
  private localFeedback: FeedbackItem[] = [];
  private isLeavesLoaded: boolean = false;
  private isFeedbackLoaded: boolean = false;

  private async getLocalLeaves(): Promise<LeaveRequest[]> {
    this.localLeaves = await LocalDataStore.loadArray<LeaveRequest>(KEY_LOCAL_LEAVES, []);
    this.isLeavesLoaded = true;
    return this.localLeaves;
  }

  private async getLocalFeedback(): Promise<FeedbackItem[]> {
    if (!this.isFeedbackLoaded) {
      this.localFeedback = await LocalDataStore.loadArray<FeedbackItem>(KEY_LOCAL_FEEDBACK, []);
      this.isFeedbackLoaded = true;
    }
    return this.localFeedback;
  }

  private leaveTypeLabel(type: LeaveType): string {
    if (type === 'sick') {
      return '\u75c5\u5047';
    }
    if (type === 'personal') {
      return '\u4e8b\u5047';
    }
    if (type === 'public') {
      return '\u516c\u5047';
    }
    return '\u5176\u4ed6';
  }

  private buildLeaveApproval(item: LeaveRequest): ApprovalItem {
    const student = this.getCurrentStudentProfile();
    const approval: ApprovalItem = {
      id: `ap-${item.id}`,
      type: '\u8bf7\u5047',
      applicantName: student.name,
      applicantId: student.studentId,
      title: `${this.leaveTypeLabel(item.type)}\u8bf7\u5047\u7533\u8bf7`,
      reason: item.reason,
      status: 'pending',
      isUrgent: false,
      submittedAt: item.submittedAt
    };
    return approval;
  }

  private async appendLeaveApproval(item: LeaveRequest): Promise<void> {
    const approval = this.buildLeaveApproval(item);
    const stored = await LocalDataStore.loadArray<ApprovalItem>(KEY_ADMIN_APPROVALS, []);
    const exists = stored.some((cur) => cur.id === approval.id);
    if (!exists) {
      await LocalDataStore.saveArray<ApprovalItem>(KEY_ADMIN_APPROVALS, [approval].concat(stored));
    }
  }

  private getCurrentStudentProfile(): UserProfile {
    return SessionStorage.get().getStudent() ?? this.workingProfile;
  }

  private parseStringArray(raw: string): string[] {
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  private async upsertStudentProfile(profile: UserProfile): Promise<void> {
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO student_profiles (
        student_id, account_id, name, gender, college, major, class_name, grade, phone, email,
        address, emergency_contact, avatar_url, bio, status, updated_at
      ) VALUES (
        ${AppDatabase.sqlText(profile.studentId)},
        NULL,
        ${AppDatabase.sqlText(profile.name)},
        NULL,
        ${AppDatabase.sqlText(profile.college)},
        ${AppDatabase.sqlText(profile.major)},
        ${AppDatabase.sqlText(profile.className)},
        ${AppDatabase.sqlText(profile.grade)},
        ${AppDatabase.sqlNullableText(profile.phone)},
        ${AppDatabase.sqlNullableText(profile.email)},
        ${AppDatabase.sqlNullableText(profile.address)},
        ${AppDatabase.sqlNullableText(profile.emergencyContact)},
        ${AppDatabase.sqlNullableText(profile.avatarUrl)},
        ${AppDatabase.sqlNullableText(profile.bio)},
        'active',
        CURRENT_TIMESTAMP
      )`
    );
  }

  private async saveLeaveToRdb(item: LeaveRequest): Promise<void> {
    const student = this.getCurrentStudentProfile();
    const approval = this.buildLeaveApproval(item);
    await this.upsertStudentProfile(student);
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO leave_requests (
        leave_id, student_id, type, start_date, end_date, reason, attachments_json, status, feedback, submitted_at, updated_at
      ) VALUES (
        ${AppDatabase.sqlText(item.id)},
        ${AppDatabase.sqlText(student.studentId)},
        ${AppDatabase.sqlText(item.type)},
        ${AppDatabase.sqlText(item.startDate)},
        ${AppDatabase.sqlText(item.endDate)},
        ${AppDatabase.sqlText(item.reason)},
        ${AppDatabase.sqlText(JSON.stringify(item.attachments))},
        ${AppDatabase.sqlText(item.state)},
        ${AppDatabase.sqlNullableText(item.feedback)},
        ${AppDatabase.sqlText(item.submittedAt)},
        CURRENT_TIMESTAMP
      )`
    );
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO approval_instances (
        approval_id, biz_type, biz_id, applicant_id, title, reason, status, current_step, is_urgent, submitted_at, updated_at
      ) VALUES (
        ${AppDatabase.sqlText(approval.id)},
        'leave',
        ${AppDatabase.sqlText(item.id)},
        ${AppDatabase.sqlText(student.studentId)},
        ${AppDatabase.sqlText(approval.title)},
        ${AppDatabase.sqlText(approval.reason)},
        ${AppDatabase.sqlText(approval.status)},
        1,
        0,
        ${AppDatabase.sqlText(approval.submittedAt)},
        CURRENT_TIMESTAMP
      )`
    );
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO approval_steps (
        step_id, approval_id, step_order, node_name, approver_role, status
      ) VALUES (
        ${AppDatabase.sqlText(`step-${approval.id}-1`)},
        ${AppDatabase.sqlText(approval.id)},
        1,
        ${AppDatabase.sqlText('\u6559\u52a1\u5ba1\u6279')},
        ${AppDatabase.sqlText('\u6559\u52a1\u7ba1\u7406\u5458')},
        'pending'
      )`
    );
  }

  private async getLeaveRequestsFromRdb(): Promise<LeaveRequest[]> {
    const student = this.getCurrentStudentProfile();
    const resultSet = await AppDatabase.query(
      `SELECT leave_id, type, start_date, end_date, reason, COALESCE(attachments_json, '[]') AS attachments_json,
        status, submitted_at, COALESCE(feedback, '') AS feedback
       FROM leave_requests
       WHERE student_id = ${AppDatabase.sqlText(student.studentId)}
       ORDER BY submitted_at DESC`
    );
    const items: LeaveRequest[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: LeaveRequest = {
          id: resultSet.getString(resultSet.getColumnIndex('leave_id')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as LeaveType,
          startDate: resultSet.getString(resultSet.getColumnIndex('start_date')),
          endDate: resultSet.getString(resultSet.getColumnIndex('end_date')),
          reason: resultSet.getString(resultSet.getColumnIndex('reason')),
          attachments: this.parseStringArray(resultSet.getString(resultSet.getColumnIndex('attachments_json'))),
          state: resultSet.getString(resultSet.getColumnIndex('status')) as ApprovalState,
          submittedAt: resultSet.getString(resultSet.getColumnIndex('submitted_at')),
          feedback: resultSet.getString(resultSet.getColumnIndex('feedback'))
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  async getProfile(): Promise<UserProfile> {
    return this.delayCopy<UserProfile>(this.workingProfile);
  }

  async updateProfile(patch: ProfileEditPatch): Promise<UserProfile> {
    const cur = this.workingProfile;
    const next: UserProfile = {
      studentId: cur.studentId,
      name: cur.name,
      avatarUrl: patch.avatarUrl ?? cur.avatarUrl,
      college: cur.college,
      major: cur.major,
      className: cur.className,
      grade: cur.grade,
      phone: patch.phone ?? cur.phone,
      email: patch.email ?? cur.email,
      address: patch.address ?? cur.address,
      emergencyContact: patch.emergencyContact ?? cur.emergencyContact,
      bio: patch.bio ?? cur.bio,
      role: cur.role
    };
    this.workingProfile = next;
    await SessionStorage.get().updateStudentProfile(next);
    return this.delayCopy<UserProfile>(next);
  }

  async getHomeSummary(): Promise<HomeSummary> {
    const summary = await this.delayCopy<HomeSummary>(mockHomeSummary);
    // 未读角标与通知摘要改为按通知仓储动态计算，反映已读状态（避免静态快照不刷新）
    const notices = await NoticeStore.list(mockNotices);
    summary.unreadNoticeCount = notices.filter((n) => !n.isRead).length;
    summary.noticeSummary = notices.slice(0, 3);
    return summary;
  }

  private remoteToLeave(l: RemoteLeave): LeaveRequest {
    const item: LeaveRequest = {
      id: l.id,
      type: l.type as LeaveType,
      startDate: l.startDate,
      endDate: l.endDate,
      reason: l.reason,
      attachments: l.attachments,
      state: l.state as ApprovalState,
      submittedAt: l.submittedAt
    };
    if (l.feedback.length > 0) {
      item.feedback = l.feedback;
    }
    return item;
  }

  async getLeaveRequests(): Promise<LeaveRequest[]> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.listLeave(student.studentId);
          const remoteItems: LeaveRequest[] = remote.map((l) => this.remoteToLeave(l));
          return this.delayCopy<LeaveRequest[]>(remoteItems);
        } catch (e) {
          // 远程失败回退本地
        }
      }
    }
    if (AppDatabase.isReady()) {
      const rdbItems = await this.getLeaveRequestsFromRdb();
      const ids = rdbItems.map((item) => item.id);
      const seeded = mockLeaveRequests.filter((item) => ids.indexOf(item.id) < 0);
      return this.delayCopy<LeaveRequest[]>(rdbItems.concat(seeded));
    }
    const localItems = await this.getLocalLeaves();
    const items = localItems.concat(mockLeaveRequests);
    return this.delayCopy<LeaveRequest[]>(items);
  }

  async submitLeave(req: LeaveSubmitForm): Promise<LeaveRequest> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.submitLeave(student.studentId, req.type, req.startDate, req.endDate, req.reason);
          return this.delay<LeaveRequest>(this.remoteToLeave(remote));
        } catch (e) {
          return this.reject((e instanceof Error) ? e.message : String(e));
        }
      }
    }
    const item: LeaveRequest = {
      id: `lv-${Date.now()}`,
      type: req.type,
      startDate: req.startDate,
      endDate: req.endDate,
      reason: req.reason,
      attachments: req.attachments,
      state: 'pending',
      submittedAt: new Date().toISOString()
    };
    if (AppDatabase.isReady()) {
      await this.saveLeaveToRdb(item);
      return this.delay<LeaveRequest>(item);
    }
    const localItems = await this.getLocalLeaves();
    const next = [item].concat(localItems);
    this.localLeaves = next;
    this.isLeavesLoaded = true;
    await LocalDataStore.saveArray<LeaveRequest>(KEY_LOCAL_LEAVES, next);
    await this.appendLeaveApproval(item);
    return this.delay<LeaveRequest>(item);
  }

  private remoteToFeedback(f: RemoteFeedback): FeedbackItem {
    const item: FeedbackItem = {
      id: f.id,
      category: f.category as FeedbackCategory,
      title: f.title,
      content: f.content,
      contact: f.contact,
      screenshots: [],
      submittedAt: f.submittedAt,
      state: f.state as FeedbackState
    };
    return item;
  }

  async getFeedback(): Promise<FeedbackItem[]> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.listFeedback(student.studentId);
          return this.delayCopy<FeedbackItem[]>(remote.map((f) => this.remoteToFeedback(f)));
        } catch (e) {
          // 远程失败回退本地
        }
      }
    }
    const localItems = await this.getLocalFeedback();
    const items = localItems.concat(mockFeedback);
    return this.delayCopy<FeedbackItem[]>(items);
  }

  async submitFeedback(req: FeedbackSubmitForm): Promise<FeedbackItem> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.submitFeedback(student.studentId, req.category, req.title, req.content, req.contact);
          return this.delay<FeedbackItem>(this.remoteToFeedback(remote));
        } catch (e) {
          return this.reject((e instanceof Error) ? e.message : String(e));
        }
      }
    }
    const item: FeedbackItem = {
      id: `fb-${Date.now()}`,
      category: req.category,
      title: req.title,
      content: req.content,
      contact: req.contact,
      screenshots: req.screenshots,
      submittedAt: new Date().toISOString(),
      state: 'submitted'
    };
    const localItems = await this.getLocalFeedback();
    const next = [item].concat(localItems);
    this.localFeedback = next;
    this.isFeedbackLoaded = true;
    await LocalDataStore.saveArray<FeedbackItem>(KEY_LOCAL_FEEDBACK, next);
    return this.delay<FeedbackItem>(item);
  }

  async getPracticeEntries(): Promise<PracticeEntry[]> {
    return this.delayCopy<PracticeEntry[]>(mockPracticeEntries);
  }
}
