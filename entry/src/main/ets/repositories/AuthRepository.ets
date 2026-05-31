// 认证 / 账号 仓储

import { BaseRepository } from './BaseRepository';
import { LoginRequest, RegisterRequest, ResetPasswordRequest, ChangePasswordRequest, LoginResult, AccountInfo, LoginHistoryItem } from '../models/User';
import { AdminLoginRequest, AdminProfile, AdminLoginResult } from '../models/Admin';
import { mockStudentProfile, mockAccountInfo, mockLoginHistory, TEST_STUDENT_ID, TEST_STUDENT_PASSWORD } from '../mock/mockUser';
import { mockAdminProfile, TEST_ADMIN_ID, TEST_ADMIN_PASSWORD } from '../mock/mockAdmin';

export class AuthRepository extends BaseRepository {
  private static _instance?: AuthRepository;
  static get(): AuthRepository {
    if (!AuthRepository._instance) {
      AuthRepository._instance = new AuthRepository();
    }
    return AuthRepository._instance;
  }

  async login(req: LoginRequest): Promise<LoginResult> {
    if (req.studentId.trim().length === 0 || req.password.length === 0) {
      return this.reject('学号或密码不能为空');
    }
    if (req.studentId.trim() !== TEST_STUDENT_ID || req.password !== TEST_STUDENT_PASSWORD) {
      return this.reject('学号或密码错误');
    }
    return this.delay<LoginResult>({
      token: `mock-student-token-${Date.now()}`,
      user: mockStudentProfile
    });
  }

  async register(req: RegisterRequest): Promise<boolean> {
    if (!req.agreed) {
      return this.reject('请先同意用户协议');
    }
    if (req.password !== req.confirmPassword) {
      return this.reject('两次密码不一致');
    }
    return this.delay<boolean>(true);
  }

  async sendSms(phone: string): Promise<boolean> {
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return this.reject('手机号格式不正确');
    }
    return this.delay<boolean>(true);
  }

  async resetPassword(req: ResetPasswordRequest): Promise<boolean> {
    if (req.verifyCode !== '123456') {
      return this.reject('验证码错误');
    }
    return this.delay<boolean>(true);
  }

  async changePassword(req: ChangePasswordRequest): Promise<boolean> {
    if (req.oldPassword !== TEST_STUDENT_PASSWORD) {
      return this.reject('原密码错误');
    }
    if (req.newPassword !== req.confirmPassword) {
      return this.reject('两次新密码不一致');
    }
    return this.delay<boolean>(true);
  }

  async logout(): Promise<boolean> {
    return this.delay<boolean>(true);
  }

  async getAccount(): Promise<AccountInfo> {
    return this.delayCopy<AccountInfo>(mockAccountInfo);
  }

  async getLoginHistory(): Promise<LoginHistoryItem[]> {
    return this.delayCopy<LoginHistoryItem[]>(mockLoginHistory);
  }

  // 管理端
  async adminLogin(req: AdminLoginRequest): Promise<AdminLoginResult> {
    const input: string = req.captcha.trim().toUpperCase();
    const expected: string = (req.expectedCaptcha ?? '').trim().toUpperCase();
    // 必须比对页面展示的验证码挑战值，而不是只校验长度
    if (input.length !== 4 || expected.length !== 4 || input !== expected) {
      return this.reject('图形验证码错误');
    }
    if (req.adminId.trim() !== TEST_ADMIN_ID || req.password !== TEST_ADMIN_PASSWORD) {
      return this.reject('工号或密码错误');
    }
    return this.delay<AdminLoginResult>({
      token: `mock-admin-token-${Date.now()}`,
      profile: mockAdminProfile
    });
  }
}
