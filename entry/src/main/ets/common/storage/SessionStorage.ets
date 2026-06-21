// 会话存储：持久化 token、角色与用户资料缓存

import { UserProfile, UserRole } from '../../models/User';
import { AdminProfile } from '../../models/Admin';
import { TeacherProfile } from '../../models/Teacher';
import { PreferenceStorage } from './PreferenceStorage';
import { AssetTokenStore } from '../security/AssetTokenStore';

const KEY_TOKEN = 'session.token';
const KEY_ROLE = 'session.role';
const KEY_STUDENT_PROFILE = 'session.studentProfile';
const KEY_ADMIN_PROFILE = 'session.adminProfile';
const KEY_TEACHER_PROFILE = 'session.teacherProfile';
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

interface StoredTeacherProfile {
  teacherId?: string;
  name?: string;
  college?: string;
  title?: string;
  email?: string;
}

export class SessionStorage {
  private static _instance?: SessionStorage;

  private token?: string;
  private role?: UserRole;
  private studentProfile?: UserProfile;
  private adminProfile?: AdminProfile;
  private teacherProfile?: TeacherProfile;

  static get(): SessionStorage {
    if (!SessionStorage._instance) {
      SessionStorage._instance = new SessionStorage();
    }
    return SessionStorage._instance;
  }

  async restore(): Promise<void> {
    const prefs = PreferenceStorage.get();
    // KEY_TOKEN 仅用于读取旧版本可能残留的明文 token，作为一次性迁移的桥接来源；
    // 新版本不再写入此键，长期 token 的权威来源是 AssetTokenStore（见 reconcileSecureToken）。
    const t = await prefs.getString(KEY_TOKEN);
    const r = await prefs.getString(KEY_ROLE);
    this.token = t || undefined;
    this.role = (r === 'student' || r === 'admin' || r === 'teacher') ? r : undefined;
    this.studentProfile = undefined;
    this.adminProfile = undefined;
    this.teacherProfile = undefined;

    if (this.role === 'student') {
      const raw = await prefs.getString(KEY_STUDENT_PROFILE);
      this.studentProfile = this.parseStudentProfile(raw);
    } else if (this.role === 'admin') {
      const raw = await prefs.getString(KEY_ADMIN_PROFILE);
      this.adminProfile = this.parseAdminProfile(raw);
    } else if (this.role === 'teacher') {
      const raw = await prefs.getString(KEY_TEACHER_PROFILE);
      this.teacherProfile = this.parseTeacherProfile(raw);
    }
  }

  // 用安全存储(AssetTokenStore)对齐会话 token：
  // 安全 store 有 token → 以其为权威来源；仅 Preferences 有(旧版本升级场景) → 回填安全 store 完成迁移。
  // 在 restore() 之后调用，使 token 的读取路径经过 Asset Store Kit。
  async reconcileSecureToken(): Promise<void> {
    if (this.role === undefined) {
      return;
    }
    let secure: string | undefined = undefined;
    if (this.role === 'admin') {
      secure = await AssetTokenStore.getAdminToken();
    } else if (this.role === 'teacher') {
      secure = await AssetTokenStore.getTeacherToken();
    } else {
      secure = await AssetTokenStore.getStudentToken();
    }
    if (secure !== undefined && secure.length > 0) {
      this.token = secure;
      // 安全存储已是权威来源：清除旧版本可能残留的 Preferences 明文 token
      await PreferenceStorage.get().remove(KEY_TOKEN);
      return;
    }
    if (this.token !== undefined && this.token.length > 0) {
      // 旧版本明文 token 一次性迁移到安全存储，迁移后删除 Preferences 明文，杜绝长期落盘
      if (this.role === 'admin') {
        await AssetTokenStore.setAdminToken(this.token);
      } else if (this.role === 'teacher') {
        await AssetTokenStore.setTeacherToken(this.token);
      } else {
        await AssetTokenStore.setStudentToken(this.token);
      }
      await PreferenceStorage.get().remove(KEY_TOKEN);
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

  private parseTeacherProfile(raw: string): TeacherProfile | undefined {
    const value = this.parseObject(raw) as StoredTeacherProfile | undefined;
    if (!value) {
      return undefined;
    }
    if (!this.hasRequiredString(value.teacherId)) {
      return undefined;
    }
    if (!this.hasRequiredString(value.name)) {
      return undefined;
    }
    // college/title/email 可为空串（后端未填），仅 teacherId+name 为必需
    return {
      teacherId: value.teacherId as string,
      name: value.name as string,
      college: value.college ?? '',
      title: value.title ?? '',
      email: value.email ?? ''
    };
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

  getTeacher(): TeacherProfile | undefined {
    return this.teacherProfile;
  }

  isAuthenticated(): boolean {
    if (!this.token || !this.role) {
      return false;
    }
    if (this.role === 'student') {
      return this.getStudent() !== undefined;
    }
    if (this.role === 'teacher') {
      return this.getTeacher() !== undefined;
    }
    return this.getAdmin() !== undefined;
  }

  async setStudentSession(token: string, profile: UserProfile): Promise<void> {
    this.token = token;
    this.role = 'student';
    this.studentProfile = profile;
    this.adminProfile = undefined;
    this.teacherProfile = undefined;
    const prefs = PreferenceStorage.get();
    // 安全加固：token 仅由 AssetTokenStore（安全存储）持久化，不再明文写入 Preferences；
    // 主动清除旧版本可能残留的明文 token。会话内 token 由内存字段 this.token 提供。
    await prefs.remove(KEY_TOKEN);
    await prefs.putString(KEY_ROLE, 'student');
    await prefs.putString(KEY_STUDENT_PROFILE, JSON.stringify(profile));
    await prefs.remove(KEY_ADMIN_PROFILE);
    await prefs.remove(KEY_TEACHER_PROFILE);
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
    this.teacherProfile = undefined;
    const prefs = PreferenceStorage.get();
    // 安全加固：token 仅由 AssetTokenStore（安全存储）持久化，不再明文写入 Preferences；
    // 主动清除旧版本可能残留的明文 token。会话内 token 由内存字段 this.token 提供。
    await prefs.remove(KEY_TOKEN);
    await prefs.putString(KEY_ROLE, 'admin');
    await prefs.putString(KEY_ADMIN_PROFILE, JSON.stringify(profile));
    await prefs.remove(KEY_STUDENT_PROFILE);
    await prefs.remove(KEY_TEACHER_PROFILE);
  }

  // 教师会话落地（roadmap #6）：与学生/管理员同构，token 入安全存储由调用方负责。
  async setTeacherSession(token: string, profile: TeacherProfile): Promise<void> {
    this.token = token;
    this.role = 'teacher';
    this.teacherProfile = profile;
    this.studentProfile = undefined;
    this.adminProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.remove(KEY_TOKEN);
    await prefs.putString(KEY_ROLE, 'teacher');
    await prefs.putString(KEY_TEACHER_PROFILE, JSON.stringify(profile));
    await prefs.remove(KEY_STUDENT_PROFILE);
    await prefs.remove(KEY_ADMIN_PROFILE);
  }

  async clear(): Promise<void> {
    this.token = undefined;
    this.role = undefined;
    this.studentProfile = undefined;
    this.adminProfile = undefined;
    this.teacherProfile = undefined;
    const prefs = PreferenceStorage.get();
    await prefs.remove(KEY_TOKEN);
    await prefs.remove(KEY_ROLE);
    await prefs.remove(KEY_STUDENT_PROFILE);
    await prefs.remove(KEY_ADMIN_PROFILE);
    await prefs.remove(KEY_TEACHER_PROFILE);
    // 一并清除安全存储中的 token，避免清空会话后残留
    await AssetTokenStore.clear();
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
