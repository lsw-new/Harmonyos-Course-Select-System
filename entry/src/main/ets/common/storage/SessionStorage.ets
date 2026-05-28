// 会话存储 · Token、当前用户、角色
// 同时利用 PreferenceStorage 做持久化（仅限 Token + 角色 + 学号），UserProfile 仅缓存内存

import { UserProfile, UserRole } from '../../models/User';
import { AdminProfile } from '../../models/Admin';
import { PreferenceStorage } from './PreferenceStorage';

const KEY_TOKEN = 'session.token';
const KEY_ROLE = 'session.role';
const KEY_REMEMBER_ID = 'session.rememberId';

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
    return !!this.token && !!this.role;
  }

  async setStudentSession(token: string, profile: UserProfile): Promise<void> {
    this.token = token;
    this.role = 'student';
    this.studentProfile = profile;
    this.adminProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.putString(KEY_TOKEN, token);
    await prefs.putString(KEY_ROLE, 'student');
  }

  async setAdminSession(token: string, profile: AdminProfile): Promise<void> {
    this.token = token;
    this.role = 'admin';
    this.adminProfile = profile;
    this.studentProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.putString(KEY_TOKEN, token);
    await prefs.putString(KEY_ROLE, 'admin');
  }

  async clear(): Promise<void> {
    this.token = undefined;
    this.role = undefined;
    this.studentProfile = undefined;
    this.adminProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.remove(KEY_TOKEN);
    await prefs.remove(KEY_ROLE);
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
