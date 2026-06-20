// 学生用户与账号模型

export type UserRole = 'student' | 'admin';

export interface UserProfile {
  studentId: string;
  name: string;
  avatarUrl?: string;
  college: string;
  major: string;
  className: string;
  grade: string;
  phone?: string;
  email?: string;
  address?: string;
  emergencyContact?: string;
  bio?: string;
  role: UserRole;
}

export interface LoginRequest {
  studentId: string;
  password: string;
  remember?: boolean;
}

export interface RegisterRequest {
  studentId: string;
  name: string;
  email: string;
  emailCode: string;
  password: string;
  confirmPassword: string;
  agreed: boolean;
}

export interface ResetPasswordRequest {
  account: string;
  contact: string;
  verifyCode: string;
  newPassword: string;
  method: 'phone' | 'email';
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export interface LoginResult {
  token: string;
  user: UserProfile;
}

// #12 登录可能直接成功，或需要邮箱二次验证。
// kind='ok'       —— 2FA 关闭，会话已建立，result 即正常登录结果。
// kind='twoFactor'—— 2FA 开启，尚未建立会话，需用 account + 脱敏 email 进入验证码步骤。
export type LoginOutcomeKind = 'ok' | 'twoFactor';

export interface LoginOutcome {
  kind: LoginOutcomeKind;
  result?: LoginResult;
  account?: string;
  email?: string;
}

export interface AccountInfo {
  studentId: string;
  name: string;
  email?: string;
  status: 'active' | 'locked' | 'pending';
  validFrom: string;
  createdAt: string;
  updatedAt: string;
  passwordPolicy: string;
  loginCount: number;
}

export interface LoginHistoryItem {
  id: string;
  loginTime: string;
  ipAddress: string;
  location: string;
  durationMinutes: number;
}
