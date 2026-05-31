import { UserProfile, AccountInfo, LoginHistoryItem } from '../models/User';

export const mockStudentProfile: UserProfile = {
  studentId: '2023307020941',
  name: '李仕炜',
  avatarUrl: '',
  college: '电子信息工程学院',
  major: '计算机科学与技术',
  className: '23计科U9',
  grade: '2023 级',
  phone: '138****1234',
  email: 'lishiwei@jdart.edu.cn',
  address: '江西省景德镇市新厂西路 88 号',
  emergencyContact: '父亲 138****0001',
  bio: '诗与画，从不缺席的清晨。',
  role: 'student'
};

export const mockAccountInfo: AccountInfo = {
  studentId: '2023307020941',
  name: '李仕炜',
  email: 'lishiwei@jdart.edu.cn',
  status: 'active',
  validFrom: '2023-09-01',
  createdAt: '2023-08-25',
  updatedAt: '2026-04-12',
  passwordPolicy: '至少 8 位 · 字母+数字',
  loginCount: 142
};

export const mockLoginHistory: LoginHistoryItem[] = [
  {
    id: 'lh-1',
    loginTime: '2026-05-27 08:43',
    ipAddress: '10.10.*.42',
    location: '景德镇 · 校园网',
    durationMinutes: 35
  },
  {
    id: 'lh-2',
    loginTime: '2026-05-26 19:21',
    ipAddress: '10.10.*.18',
    location: '景德镇 · 校园网',
    durationMinutes: 12
  },
  {
    id: 'lh-3',
    loginTime: '2026-05-25 22:05',
    ipAddress: '120.85.*.66',
    location: '景德镇 · 中国电信',
    durationMinutes: 47
  }
];

// 测试登录凭据（学生端）· 与 mockStudentProfile 对应
export const TEST_STUDENT_ID: string = '2023307020941';
export const TEST_STUDENT_PASSWORD: string = 'Elysia@2024';
