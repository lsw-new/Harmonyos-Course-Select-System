'use strict';

jest.mock('../src/db', () => require('./helpers/dbMock'));

const { __mock } = require('./helpers/dbMock');
const {
  fetchStudentProfile,
  fetchAdminProfile,
  normalizePermCode
} = require('../src/repositories/profile.repo');

describe('profile repository', () => {
  beforeEach(() => {
    __mock.reset();
  });

  test('normalizes evaluation permission codes for the app permission vocabulary', () => {
    expect(normalizePermCode('evaluations.manage')).toBe('evaluation.manage');
    expect(normalizePermCode('notices.manage')).toBe('notices.manage');
  });

  test('returns null when a student profile does not exist', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.student_profiles/, result: [] }]);

    await expect(fetchStudentProfile('missing-student')).resolves.toBeNull();
  });

  test('maps a student profile and defaults optional fields to empty strings', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.student_profiles/, result: {
      student_id: 's1', name: '张三', avatar_url: null, college: '陶瓷美术学院', major: '陶艺',
      class_name: '陶艺1班', grade: '2024', phone: null, email: null, address: null,
      emergency_contact: null, bio: null
    } }]);

    await expect(fetchStudentProfile('s1')).resolves.toEqual({
      studentId: 's1', name: '张三', avatarUrl: '', college: '陶瓷美术学院', major: '陶艺',
      className: '陶艺1班', grade: '2024', phone: '', email: '', address: '',
      emergencyContact: '', bio: '', role: 'student'
    });
  });

  test('returns null when an admin profile does not exist', async () => {
    __mock.setRoutes([{ match: /FROM dtest2\.admin_profiles/, result: [] }]);

    await expect(fetchAdminProfile('missing-admin')).resolves.toBeNull();
  });

  test('maps admin permissions with code normalization and fallback fields', async () => {
    __mock.setRoutes([
      { match: /FROM dtest2\.admin_profiles/, result: {
        admin_id: 'a1', name: '管理员', department: '教务处', role_id: 'role1', avatar_url: null,
        online_status: 'online', role_name: '超级管理员'
      } },
      { match: /FROM dtest2\.role_permissions/, result: [
        { code: 'evaluations.manage', name: null, module: null, actions: null },
        { code: 'notices.manage', name: '公告管理', module: '教务', actions: ['create', 'view'] }
      ] }
    ]);

    await expect(fetchAdminProfile('a1')).resolves.toEqual({
      adminId: 'a1', name: '管理员', department: '教务处', roleName: '超级管理员',
      avatarUrl: '', onlineStatus: 'online',
      permissions: [
        { code: 'evaluation.manage', name: 'evaluations.manage', module: '', actions: [] },
        { code: 'notices.manage', name: '公告管理', module: '教务', actions: ['create', 'view'] }
      ]
    });
  });
});
