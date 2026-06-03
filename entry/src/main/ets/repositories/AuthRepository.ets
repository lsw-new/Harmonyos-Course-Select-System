// 认证 / 账号 仓储

import { BaseRepository } from './BaseRepository';
import {
  LoginRequest, RegisterRequest, ResetPasswordRequest, ChangePasswordRequest,
  LoginResult, AccountInfo, LoginHistoryItem
} from '../models/User';
import { AdminLoginRequest, AdminProfile, AdminLoginResult } from '../models/Admin';
import { mockStudentProfile, mockAccountInfo, mockLoginHistory, TEST_STUDENT_ID, TEST_STUDENT_PASSWORD } from '../mock/mockUser';
import { mockAdminProfile, TEST_ADMIN_ID, TEST_ADMIN_PASSWORD } from '../mock/mockAdmin';
import { AccountStore } from '../common/storage/AccountStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AssetTokenStore } from '../common/security/AssetTokenStore';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi } from '../common/remote/RemoteApi';
import { HttpError } from '../common/http/HttpError';

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

    // Track B：开启远程时优先走后端登录，失败回退本地校验
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.login(req.studentId.trim(), req.password);
        const remoteResult: LoginResult = { token: remote.token, user: mockStudentProfile };
        await AssetTokenStore.setStudentToken(remote.token);
        await SessionStorage.get().setStudentSession(remote.token, mockStudentProfile);
        return this.delay<LoginResult>(remoteResult);
      } catch (e) {
        // 远程登录失败回退本地校验
      }
    }

    // 先尝试持久化存储校验（AccountStore）
    let verified = false;
    try {
      verified = await AccountStore.verifyPassword(req.studentId.trim(), req.password);
    } catch (e) {
      // AccountStore 异常时降级到 mock 校验
      verified = false;
    }

    // 若持久化校验失败，兜底用 mock 凭据（保证既有测试账号可用）
    if (!verified) {
      if (req.studentId.trim() !== TEST_STUDENT_ID || req.password !== TEST_STUDENT_PASSWORD) {
        return this.reject('学号或密码错误');
      }
    }

    const token = `mock-student-token-${Date.now()}`;
    const result: LoginResult = {
      token: token,
      user: mockStudentProfile
    };

    // 安全存储 token
    await AssetTokenStore.setStudentToken(token);
    // 同时写入 SessionStorage（兼容现有读取逻辑）
    await SessionStorage.get().setStudentSession(token, mockStudentProfile);

    return this.delay<LoginResult>(result);
  }

  async register(req: RegisterRequest): Promise<boolean> {
    if (!req.agreed) {
      return this.reject('请先同意用户协议');
    }
    if (req.password !== req.confirmPassword) {
      return this.reject('两次密码不一致');
    }
    // 校验邮箱验证码：走后端真实验证码（成功即被后端消费）。
    try {
      await RemoteApi.verifyEmailCode(req.email, req.emailCode);
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败，请检查网络';
      return this.reject(msg);
    }
    return this.delay<boolean>(true);
  }

  async sendEmailCode(email: string): Promise<boolean> {
    if (!/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email)) {
      return this.reject('邮箱格式不正确');
    }
    // 真实发送：由后端 nodemailer + QQ SMTP 发出验证码邮件，验证码保存在后端。
    // 邮件发送本身必须联网，故此处直连后端，不受 AppConfig.useRemote 开关影响。
    try {
      await RemoteApi.sendEmailCode(email);
      return true;
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码发送失败，请检查网络';
      return this.reject(msg);
    }
  }

  async resetPassword(req: ResetPasswordRequest): Promise<boolean> {
    // 校验账号是否存在（学生 or 管理员）
    const accountId = req.account.trim();
    if (accountId.length === 0) {
      return this.reject('账号不能为空');
    }

    // 校验邮箱验证码：走后端真实验证码（成功即被后端消费），不再接受固定码。
    try {
      await RemoteApi.verifyEmailCode(req.contact, req.verifyCode);
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败，请检查网络';
      return this.reject(msg);
    }

    // 将新密码真正持久化
    try {
      await AccountStore.resetPassword(accountId, req.newPassword);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      return this.reject(`重置密码失败：${msg}`);
    }

    return this.delay<boolean>(true);
  }

  async changePassword(req: ChangePasswordRequest): Promise<boolean> {
    if (req.newPassword !== req.confirmPassword) {
      return this.reject('两次新密码不一致');
    }

    // 从 SessionStorage 取当前登录账号 ID
    const session = SessionStorage.get();
    const student = session.getStudent();
    const admin = session.getAdmin();
    const accountId = student ? student.studentId : (admin ? admin.adminId : '');

    if (accountId.length === 0) {
      return this.reject('未登录，无法修改密码');
    }

    // 先用 AccountStore 校验旧密码
    let verified = false;
    try {
      verified = await AccountStore.verifyPassword(accountId, req.oldPassword);
    } catch (e) {
      verified = false;
    }

    // 降级：若 AccountStore 读不到记录（首次使用），用 mock 凭据兜底
    if (!verified) {
      const isMockStudent = (accountId === TEST_STUDENT_ID && req.oldPassword === TEST_STUDENT_PASSWORD);
      const isMockAdmin = (accountId === TEST_ADMIN_ID && req.oldPassword === TEST_ADMIN_PASSWORD);
      if (!isMockStudent && !isMockAdmin) {
        return this.reject('原密码错误');
      }
    }

    // 持久化新密码
    try {
      await AccountStore.changePassword(accountId, req.newPassword);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      return this.reject(`密码修改失败：${msg}`);
    }

    return this.delay<boolean>(true);
  }

  async logout(): Promise<boolean> {
    // 清除安全存储的 token
    await AssetTokenStore.clear();
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

    // Track B：开启远程时优先走后端登录（要求 role=admin），失败回退本地
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.login(req.adminId.trim(), req.password);
        if (remote.role === 'admin') {
          const remoteResult: AdminLoginResult = { token: remote.token, profile: mockAdminProfile };
          await AssetTokenStore.setAdminToken(remote.token);
          await SessionStorage.get().setAdminSession(remote.token, mockAdminProfile);
          return this.delay<AdminLoginResult>(remoteResult);
        }
      } catch (e) {
        // 远程登录失败回退本地校验
      }
    }

    // 先尝试持久化存储校验
    let verified = false;
    try {
      verified = await AccountStore.verifyPassword(req.adminId.trim(), req.password);
    } catch (e) {
      verified = false;
    }

    // 兜底 mock 校验
    if (!verified) {
      if (req.adminId.trim() !== TEST_ADMIN_ID || req.password !== TEST_ADMIN_PASSWORD) {
        return this.reject('工号或密码错误');
      }
    }

    const token = `mock-admin-token-${Date.now()}`;
    const result: AdminLoginResult = {
      token: token,
      profile: mockAdminProfile
    };

    // 安全存储 token
    await AssetTokenStore.setAdminToken(token);
    // 同时写入 SessionStorage
    await SessionStorage.get().setAdminSession(token, mockAdminProfile);

    return this.delay<AdminLoginResult>(result);
  }
}
