import { UserProfile, AccountInfo, LoginHistoryItem } from '../models/User';

export const mockStudentProfile: UserProfile = {
  studentId: '202221001234',
  name: '林夏',
  avatarUrl: '',
  college: '人文与艺术学院',
  major: '汉语言文学',
  className: '汉文 2202',
  grade: '2022 级',
  phone: '138****1234',
  email: 'linxia@example.edu.cn',
  address: '玫瑰路 88 号',
  emergencyContact: '父亲 138****0001',
  bio: '诗与画，从不缺席的清晨。',
  role: 'student'
};

export const mockAccountInfo: AccountInfo = {
  studentId: '202221001234',
  name: '林夏',
  email: 'linxia@example.edu.cn',
  status: 'active',
  validFrom: '2022-09-01',
  createdAt: '2022-08-25',
  updatedAt: '2026-04-12',
  passwordPolicy: '至少 8 位 · 字母+数字',
  loginCount: 142
};

export const mockLoginHistory: LoginHistoryItem[] = [
  {
    id: 'lh-1',
    loginTime: '2026-05-27 08:43',
    ipAddress: '10.10.*.42',
    location: '广州 · 校园网',
    durationMinutes: 35
  },
  {
    id: 'lh-2',
    loginTime: '2026-05-26 19:21',
    ipAddress: '10.10.*.18',
    location: '广州 · 校园网',
    durationMinutes: 12
  },
  {
    id: 'lh-3',
    loginTime: '2026-05-25 22:05',
    ipAddress: '120.85.*.66',
    location: '广州 · 中国电信',
    durationMinutes: 47
  }
];
