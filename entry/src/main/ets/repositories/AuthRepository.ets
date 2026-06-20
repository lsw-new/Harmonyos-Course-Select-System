// 认证 / 账号 仓储

import { BaseRepository } from './BaseRepository';
import {
  LoginRequest, RegisterRequest, ResetPasswordRequest, ChangePasswordRequest,
  LoginResult, LoginOutcome, AccountInfo, LoginHistoryItem, UserProfile
} from '../models/User';
import { AdminLoginRequest, AdminProfile, AdminLoginResult, AdminPermission, AdminPermissionAction } from '../models/Admin';
import { mockStudentProfile, mockAccountInfo, mockLoginHistory, TEST_STUDENT_ID, TEST_STUDENT_PASSWORD } from '../mock/mockUser';
import { mockAdminProfile, TEST_ADMIN_ID, TEST_ADMIN_PASSWORD } from '../mock/mockAdmin';
import { AccountStore } from '../common/storage/AccountStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AssetTokenStore } from '../common/security/AssetTokenStore';
import { AppConfig } from '../app/AppConfig';
import {
  RemoteApi, RemoteProfile, RemoteAdminPermission, RemoteLoginHistory,
  RemoteLoginResult, RemoteLoginResponse
} from '../common/remote/RemoteApi';
import { HttpError } from '../common/http/HttpError';

// P1-03：把后端动作字符串窄化为 AdminPermissionAction（ArkTS 安全，非法值兜底 view）
function toAdminAction(a: string): AdminPermissionAction {
  switch (a) {
    case 'create': return 'create';
    case 'update': return 'update';
    case 'delete': return 'delete';
    case 'approve': return 'approve';
    case 'publish': return 'publish';
    default: return 'view';
  }
}

export class AuthRepository extends BaseRepository {
  private static _instance?: AuthRepository;
  static get(): AuthRepository {
    if (!AuthRepository._instance) {
      AuthRepository._instance = new AuthRepository();
    }
    return AuthRepository._instance;
  }

  // P1-03：远程 profile -> UserProfile
  private mapStudentProfile(p: RemoteProfile): UserProfile {
    return {
      studentId: p.studentId ?? '',
      name: p.name ?? '',
      avatarUrl: p.avatarUrl,
      college: p.college ?? '',
      major: p.major ?? '',
      className: p.className ?? '',
      grade: p.grade ?? '',
      phone: p.phone,
      email: p.email,
      address: p.address,
      emergencyContact: p.emergencyContact,
      bio: p.bio,
      role: 'student'
    };
  }

  // P1-03：远程 profile -> AdminProfile（含权限矩阵）
  private mapAdminProfile(p: RemoteProfile): AdminProfile {
    const remotePerms: RemoteAdminPermission[] = p.permissions ?? [];
    const permissions: AdminPermission[] = remotePerms.map((rp: RemoteAdminPermission) => {
      const actions: AdminPermissionAction[] = rp.actions.map((a: string) => toAdminAction(a));
      const perm: AdminPermission = { code: rp.code, name: rp.name, module: rp.module, actions: actions };
      return perm;
    });
    const status: string = p.onlineStatus ?? 'offline';
    const onlineStatus: 'online' | 'busy' | 'offline' =
      status === 'online' ? 'online' : (status === 'busy' ? 'busy' : 'offline');
    return {
      adminId: p.adminId ?? '',
      name: p.name ?? '',
      department: p.department ?? '',
      roleName: p.roleName ?? '',
      avatarUrl: p.avatarUrl,
      onlineStatus: onlineStatus,
      permissions: permissions
    };
  }

  // #12 学生会话落地的唯一路径：映射真实 profile + 安全存储 token + 写 SessionStorage。
  // 正常登录（2FA 关闭）与二次验证通过后均复用此方法，保证两条路径会话建立行为完全一致。
  private async completeStudentSession(remote: RemoteLoginResult): Promise<LoginResult> {
    // 必须拿到后端下发的真实 profile；缺失即视为登录异常，绝不用 mock 李仕炜兜底（防张冠李戴）
    if (!remote.profile) {
      throw new Error('NO_PROFILE');
    }
    const user: UserProfile = this.mapStudentProfile(remote.profile);
    const result: LoginResult = { token: remote.token, user: user };
    await AssetTokenStore.setStudentToken(remote.token);
    await SessionStorage.get().setStudentSession(remote.token, user);
    return result;
  }

  async login(req: LoginRequest): Promise<LoginOutcome> {
    if (req.studentId.trim().length === 0 || req.password.length === 0) {
      return this.reject('学号或密码不能为空');
    }

    // Track B：开启远程时优先走后端登录，失败回退本地校验
    if (AppConfig.useRemote) {
      try {
        const remote: RemoteLoginResponse = await RemoteApi.login(req.studentId.trim(), req.password);
        // #12 后端要求二次验证：不建立会话，交回登录页进入验证码步骤
        if (remote.twoFactorRequired === true) {
          const pending: LoginOutcome = {
            kind: 'twoFactor',
            account: remote.account ?? req.studentId.trim(),
            email: remote.email ?? ''
          };
          return this.delay<LoginOutcome>(pending);
        }
        // 正常登录（2FA 关闭）：缺 token 视为异常
        if (remote.token === undefined) {
          throw new Error('NO_TOKEN');
        }
        const normal: RemoteLoginResult = {
          token: remote.token,
          accountId: remote.accountId ?? '',
          role: remote.role ?? 'student',
          profile: remote.profile
        };
        const result: LoginResult = await this.completeStudentSession(normal);
        const ok: LoginOutcome = { kind: 'ok', result: result };
        return this.delay<LoginOutcome>(ok);
      } catch (e) {
        // 远程登录失败：生产模式（禁止回退）下直接报错，不静默用本地/mock 账号建立会话
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.reject('远程服务异常，登录失败，请检查网络后重试');
        }
        // 演示模式：回退本地校验
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

    const ok: LoginOutcome = { kind: 'ok', result: await this.delay<LoginResult>(result) };
    return ok;
  }

  // #12 提交登录二次验证码：成功后经与正常登录同一路径建立会话
  async verifyLoginCode(account: string, code: string): Promise<LoginResult> {
    if (account.trim().length === 0) {
      return this.reject('账号缺失，请返回重新登录');
    }
    if (code.trim().length === 0) {
      return this.reject('请输入验证码');
    }
    try {
      const remote: RemoteLoginResult = await RemoteApi.verifyLoginTwoFactor(account.trim(), code.trim());
      const result: LoginResult = await this.completeStudentSession(remote);
      return this.delay<LoginResult>(result);
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败，请重试';
      return this.reject(msg);
    }
  }

  // #12 读取当前账号登录二次验证开关（仅联机）
  async getTwoFactor(): Promise<boolean> {
    const remote = await RemoteApi.getTwoFactorEnabled();
    return remote.enabled;
  }

  // #12 设置当前账号登录二次验证开关（仅联机），返回后端确认后的状态
  async setTwoFactor(enabled: boolean): Promise<boolean> {
    const remote = await RemoteApi.setTwoFactorEnabled(enabled);
    return remote.enabled;
  }

  async register(req: RegisterRequest): Promise<boolean> {
    if (!req.agreed) {
      return this.reject('请先同意用户协议');
    }
    if (req.studentId.trim().length === 0 || req.name.trim().length === 0) {
      return this.reject('学号和姓名不能为空');
    }
    if (req.password !== req.confirmPassword) {
      return this.reject('两次密码不一致');
    }
    // P1-01：注册真正落库
    if (AppConfig.useRemote) {
      // 远程：后端校验验证码并建账号 + 学生资料（重复学号 409）
      try {
        await RemoteApi.register(req.studentId.trim(), req.name.trim(), req.email, req.emailCode, req.password);
      } catch (e) {
        const msg = (e instanceof HttpError) ? (e as HttpError).message : '注册失败，请检查网络';
        return this.reject(msg);
      }
      return this.delay<boolean>(true);
    }
    // 本地：邮箱验证码仍走后端校验（邮件发送必须联网），再建本地账号
    try {
      await RemoteApi.verifyEmailCode(req.email, req.emailCode);
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败，请检查网络';
      return this.reject(msg);
    }
    try {
      await AccountStore.createAccount(req.studentId.trim(), 'student', req.password);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      return this.reject(`注册失败：${msg}`);
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
    const accountId = req.account.trim();
    if (accountId.length === 0) {
      return this.reject('账号不能为空');
    }
    // P1-02：远程优先——后端校验账号存在 + 邮箱匹配 + 验证码，仅重置不建号
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.resetPassword(accountId, req.contact, req.verifyCode, req.newPassword);
      } catch (e) {
        const msg = (e instanceof HttpError) ? (e as HttpError).message : '重置密码失败，请检查网络';
        return this.reject(msg);
      }
      return this.delay<boolean>(true);
    }
    // 本地：邮箱验证码走后端校验，再本地重置（账号不存在会抛错，不再自动建号）
    try {
      await RemoteApi.verifyEmailCode(req.contact, req.verifyCode);
    } catch (e) {
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '验证码校验失败，请检查网络';
      return this.reject(msg);
    }
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
    // 账户核心字段与会话真实资料同源（学号/姓名/邮箱）；
    // 注册时间/登录次数等后端暂无统计，沿用演示模板。
    const account = await this.delayCopy<AccountInfo>(mockAccountInfo);
    const student = SessionStorage.get().getStudent();
    if (student) {
      account.studentId = student.studentId;
      account.name = student.name;
      account.email = student.email ?? account.email;
    }
    return account;
  }

  async getLoginHistory(): Promise<LoginHistoryItem[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.loginHistory();
        return this.delayCopy<LoginHistoryItem[]>(remote.map((h: RemoteLoginHistory): LoginHistoryItem => {
          const item: LoginHistoryItem = {
            id: h.id,
            loginTime: h.time,
            ipAddress: h.ip,
            location: '',
            durationMinutes: 0
          };
          return item;
        }));
      } catch (e) {
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
      }
    }
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
        const remote: RemoteLoginResponse = await RemoteApi.login(req.adminId.trim(), req.password);
        if (remote.role === 'admin') {
          // 必须拿到后端真实管理员 profile（含真实权限矩阵）；缺失即视为登录异常，
          // 绝不用 mockAdminProfile（全权演示号）兜底，否则任意账号会获得全部管理权限
          if (!remote.profile || remote.token === undefined) {
            throw new Error('NO_PROFILE');
          }
          const adminToken: string = remote.token;
          const profile: AdminProfile = this.mapAdminProfile(remote.profile);
          const remoteResult: AdminLoginResult = { token: adminToken, profile: profile };
          await AssetTokenStore.setAdminToken(adminToken);
          await SessionStorage.get().setAdminSession(adminToken, profile);
          return this.delay<AdminLoginResult>(remoteResult);
        }
        // 远程登录成功但该账号不是管理员：生产模式直接拒绝，不静默落到本地 mock 管理员
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.reject('该账号无管理员权限');
        }
      } catch (e) {
        // 远程登录失败：生产模式（禁止回退）下直接报错，不静默回退本地 mock 管理员
        if (!AppConfig.allowMockFallbackInRemote) {
          return this.reject('远程服务异常，登录失败，请检查网络后重试');
        }
        // 演示模式：回退本地校验
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
