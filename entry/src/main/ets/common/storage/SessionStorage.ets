// 会话存储：持久化 token、角色与用户资料缓存

import { UserProfile, UserRole } from '../../models/User';
import { AdminProfile } from '../../models/Admin';
import { PreferenceStorage } from './PreferenceStorage';

const KEY_TOKEN = 'session.token';
const KEY_ROLE = 'session.role';
const KEY_STUDENT_PROFILE = 'session.studentProfile';
const KEY_ADMIN_PROFILE = 'session.adminProfile';
const KEY_REMEMBER_ID = 'session.rememberId';

interface StoredStudentProfile {
  studentId?: string;
  name?: string;
  college?: string;
  major?: string;
  className?: string;
  grade?: string;
  role?: string;
}

interface StoredAdminProfile {
  adminId?: string;
  name?: string;
  department?: string;
  roleName?: string;
  onlineStatus?: string;
  permissions?: Object[];
}

export class SessionStorage {
  private static _instance?: SessionStorage;

  private token?: string;
  private role?: UserRole;
  private studentProfile?: UserProfile;
  private adminProfile?: AdminProfile;

  static get(): SessionStorage {
    if (!SessionStorage._instance) {
      SessionStorage._instance = new SessionStorage();
    }
    return SessionStorage._instance;
  }

  async restore(): Promise<void> {
    const prefs = PreferenceStorage.get();
    const t = await prefs.getString(KEY_TOKEN);
    const r = await prefs.getString(KEY_ROLE);
    this.token = t || undefined;
    this.role = (r === 'student' || r === 'admin') ? r : undefined;
    this.studentProfile = undefined;
    this.adminProfile = undefined;

    if (this.role === 'student') {
      const raw = await prefs.getString(KEY_STUDENT_PROFILE);
      this.studentProfile = this.parseStudentProfile(raw);
    } else if (this.role === 'admin') {
      const raw = await prefs.getString(KEY_ADMIN_PROFILE);
      this.adminProfile = this.parseAdminProfile(raw);
    }
  }

  private parseStudentProfile(raw: string): UserProfile | undefined {
    const value = this.parseObject(raw) as StoredStudentProfile | undefined;
    if (!value) {
      return undefined;
    }
    if (!this.hasRequiredString(value.studentId)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.name)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.college)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.major)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.className)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.grade)) {
      return undefined;
    }
    if (value.role !== 'student') {
      return undefined;
    }
    return value as UserProfile;
  }

  private parseAdminProfile(raw: string): AdminProfile | undefined {
    const value = this.parseObject(raw) as StoredAdminProfile | undefined;
    if (!value) {
      return undefined;
    }
    if (!this.hasRequiredString(value.adminId)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.name)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.department)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.roleName)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.onlineStatus)) {
      return undefined;
    }
    if (!Array.isArray(value.permissions)) {
      return undefined;
    }
    return value as AdminProfile;
  }

  private hasRequiredString(value?: string): boolean {
    return typeof value === 'string' && value.length > 0;
  }

  private parseObject(raw: string): Object | undefined {
    if (raw.length === 0) {
      return undefined;
    }
    try {
      const value = JSON.parse(raw) as Object;
      if (value === null || Array.isArray(value) || typeof value !== 'object') {
        return undefined;
      }
      return value;
    } catch (e) {
      return undefined;
    }
  }

  async restoreProfileIfMissing(studentProfile?: UserProfile, adminProfile?: AdminProfile): Promise<void> {
    if (this.role === 'student' && this.studentProfile === undefined && studentProfile !== undefined) {
      this.studentProfile = studentProfile;
      await PreferenceStorage.get().putString(KEY_STUDENT_PROFILE, JSON.stringify(studentProfile));
    }
    if (this.role === 'admin' && this.adminProfile === undefined && adminProfile !== undefined) {
      this.adminProfile = adminProfile;
      await PreferenceStorage.get().putString(KEY_ADMIN_PROFILE, JSON.stringify(adminProfile));
    }
  }

  getToken(): string | undefined {
    return this.token;
  }

  getRole(): UserRole | undefined {
    return this.role;
  }

  getStudent(): UserProfile | undefined {
    return this.studentProfile;
  }

  getAdmin(): AdminProfile | undefined {
    return this.adminProfile;
  }

  isAuthenticated(): boolean {
    if (!this.token || !this.role) {
      return false;
    }
    if (this.role === 'student') {
      return this.getStudent() !== undefined;
    }
    return this.getAdmin() !== undefined;
  }

  async setStudentSession(token: string, profile: UserProfile): Promise<void> {
    this.token = token;
    this.role = 'student';
    this.studentProfile = profile;
    this.adminProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.putString(KEY_TOKEN, token);
    await prefs.putString(KEY_ROLE, 'student');
    await prefs.putString(KEY_STUDENT_PROFILE, JSON.stringify(profile));
    await prefs.remove(KEY_ADMIN_PROFILE);
  }

  async updateStudentProfile(profile: UserProfile): Promise<void> {
    if (this.role !== 'student') {
      return;
    }
    this.studentProfile = profile;
    await PreferenceStorage.get().putString(KEY_STUDENT_PROFILE, JSON.stringify(profile));
  }

  async setAdminSession(token: string, profile: AdminProfile): Promise<void> {
    this.token = token;
    this.role = 'admin';
    this.adminProfile = profile;
    this.studentProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.putString(KEY_TOKEN, token);
    await prefs.putString(KEY_ROLE, 'admin');
    await prefs.putString(KEY_ADMIN_PROFILE, JSON.stringify(profile));
    await prefs.remove(KEY_STUDENT_PROFILE);
  }

  async clear(): Promise<void> {
    this.token = undefined;
    this.role = undefined;
    this.studentProfile = undefined;
    this.adminProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.remove(KEY_TOKEN);
    await prefs.remove(KEY_ROLE);
    await prefs.remove(KEY_STUDENT_PROFILE);
    await prefs.remove(KEY_ADMIN_PROFILE);
  }

  async saveRememberId(studentId: string): Promise<void> {
    const prefs = PreferenceStorage.get();
    await prefs.putString(KEY_REMEMBER_ID, studentId);
  }

  async getRememberId(): Promise<string> {
    const prefs = PreferenceStorage.get();
    return await prefs.getString(KEY_REMEMBER_ID);
  }

  async clearRememberId(): Promise<void> {
    const prefs = PreferenceStorage.get();
    await prefs.remove(KEY_REMEMBER_ID);
  }
}
