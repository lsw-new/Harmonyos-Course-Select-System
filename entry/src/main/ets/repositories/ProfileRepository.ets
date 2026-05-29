// 个人资料、首页摘要、扩展服务

import { BaseRepository } from './BaseRepository';
import { UserProfile } from '../models/User';
import { HomeSummary } from '../models/Home';
import { LeaveRequest, FeedbackItem, PracticeEntry, LeaveType, FeedbackCategory } from '../models/Misc';
import { mockStudentProfile } from '../mock/mockUser';
import { mockHomeSummary } from '../mock/mockHome';
import { mockLeaveRequests, mockFeedback, mockPracticeEntries } from '../mock/mockMisc';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';

const KEY_LOCAL_LEAVES = 'local.leaveRequests.v1';
const KEY_LOCAL_FEEDBACK = 'local.feedback.v1';

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
    if (!this.isLeavesLoaded) {
      this.localLeaves = await LocalDataStore.loadArray<LeaveRequest>(KEY_LOCAL_LEAVES, []);
      this.isLeavesLoaded = true;
    }
    return this.localLeaves;
  }

  private async getLocalFeedback(): Promise<FeedbackItem[]> {
    if (!this.isFeedbackLoaded) {
      this.localFeedback = await LocalDataStore.loadArray<FeedbackItem>(KEY_LOCAL_FEEDBACK, []);
      this.isFeedbackLoaded = true;
    }
    return this.localFeedback;
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
    return this.delayCopy<HomeSummary>(mockHomeSummary);
  }

  async getLeaveRequests(): Promise<LeaveRequest[]> {
    const localItems = await this.getLocalLeaves();
    const items = localItems.concat(mockLeaveRequests);
    return this.delayCopy<LeaveRequest[]>(items);
  }

  async submitLeave(req: LeaveSubmitForm): Promise<LeaveRequest> {
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
    const localItems = await this.getLocalLeaves();
    const next = [item].concat(localItems);
    this.localLeaves = next;
    this.isLeavesLoaded = true;
    await LocalDataStore.saveArray<LeaveRequest>(KEY_LOCAL_LEAVES, next);
    return this.delay<LeaveRequest>(item);
  }

  async getFeedback(): Promise<FeedbackItem[]> {
    const localItems = await this.getLocalFeedback();
    const items = localItems.concat(mockFeedback);
    return this.delayCopy<FeedbackItem[]>(items);
  }

  async submitFeedback(req: FeedbackSubmitForm): Promise<FeedbackItem> {
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
