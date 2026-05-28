// 个人资料、首页摘要、扩展服务

import { BaseRepository } from './BaseRepository';
import { UserProfile } from '../models/User';
import { HomeSummary } from '../models/Home';
import { LeaveRequest, FeedbackItem, PracticeEntry, LeaveType, FeedbackCategory } from '../models/Misc';
import { mockStudentProfile } from '../mock/mockUser';
import { mockHomeSummary } from '../mock/mockHome';
import { mockLeaveRequests, mockFeedback, mockPracticeEntries } from '../mock/mockMisc';

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
    return this.delayCopy<UserProfile>(next);
  }

  async getHomeSummary(): Promise<HomeSummary> {
    return this.delayCopy<HomeSummary>(mockHomeSummary);
  }

  async getLeaveRequests(): Promise<LeaveRequest[]> {
    return this.delayCopy<LeaveRequest[]>(mockLeaveRequests);
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
    return this.delay<LeaveRequest>(item);
  }

  async getFeedback(): Promise<FeedbackItem[]> {
    return this.delayCopy<FeedbackItem[]>(mockFeedback);
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
    return this.delay<FeedbackItem>(item);
  }

  async getPracticeEntries(): Promise<PracticeEntry[]> {
    return this.delayCopy<PracticeEntry[]>(mockPracticeEntries);
  }
}
