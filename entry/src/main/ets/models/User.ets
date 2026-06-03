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
