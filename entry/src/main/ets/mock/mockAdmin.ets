import {
  AdminProfile, AdminDashboardSummary, StudentAdminItem, AdminCourseItem,
  SelectionRound, GradeAuditItem, EvaluationStats, ApprovalItem, ApprovalDetail
} from '../models/Admin';

export const mockAdminProfile: AdminProfile = {
  adminId: 'A20251001',
  name: '苏知夏',
  department: '教务处',
  roleName: '教务管理员',
  avatarUrl: '',
  onlineStatus: 'online',
  permissions: [
    { code: 'students.view', name: '学生查看', module: 'students', actions: ['view'] },
    { code: 'courses.manage', name: '课程管理', module: 'courses', actions: ['view', 'create', 'update', 'delete'] },
    { code: 'grades.approve', name: '成绩审核', module: 'grades', actions: ['view', 'create', 'update', 'approve'] },
    { code: 'notices.publish', name: '通知发布', module: 'notices', actions: ['view', 'create', 'publish'] },
    { code: 'approvals.handle', name: '审批处理', module: 'approvals', actions: ['view', 'approve'] }
  ]
};

export const mockAdminDashboard: AdminDashboardSummary = {
  statCards: [
    { key: 'students', label: '在校学生', value: 12480, delta: 12, color: '#F2709C' },
    { key: 'teachers', label: '在职教师', value: 836, delta: 4, color: '#B589FF' },
    { key: 'courses', label: '本学期开课', value: 478, delta: 16, color: '#D9B675' },
    { key: 'pending', label: '待审批', value: 36, delta: -3, color: '#D8546B' }
  ],
  selectionTrend: [
    { label: '周一', value: 320 },
    { label: '周二', value: 412 },
    { label: '周三', value: 380 },
    { label: '周四', value: 526 },
    { label: '周五', value: 489 },
    { label: '周六', value: 270 },
    { label: '周日', value: 198 }
  ],
  courseTypeDistribution: [
    { name: '必修', value: 198, color: '#F2709C' },
    { name: '选修', value: 142, color: '#B589FF' },
    { name: '公选', value: 86, color: '#D9B675' },
    { name: '实践', value: 52, color: '#7BB07B' }
  ],
  pendingApprovals: [
    {
      id: 'ap-1', type: '请假', applicantName: '林夏', applicantId: '202221001234',
      title: '社会实践请假申请', reason: '参加戏剧节展演。',
      status: 'pending', isUrgent: true, submittedAt: '2026-05-28 10:20'
    },
    {
      id: 'ap-2', type: '资料变更', applicantName: '宋衍', applicantId: '202221002021',
      title: '联系方式变更', reason: '更换手机号。',
      status: 'pending', isUrgent: false, submittedAt: '2026-05-27 14:55'
    }
  ]
};

export const mockAdminStudents: StudentAdminItem[] = [
  { studentId: '202221001234', name: '林夏', college: '人文与艺术学院', major: '汉语言文学', className: '汉文 2202', gpa: 3.72, status: 'active', educationLevel: 'undergraduate' },
  { studentId: '202221001235', name: '宋衍', college: '人文与艺术学院', major: '历史学', className: '历史 2201', gpa: 3.58, status: 'active', educationLevel: 'undergraduate' },
  { studentId: '202220001100', name: '陆清和', college: '计算机学院', major: '软件工程', className: '软工 2102', gpa: 3.86, status: 'graduating', educationLevel: 'undergraduate' },
  { studentId: '202122000812', name: '苏婉清', college: '艺术学院', major: '视觉传达', className: '视传 2002', gpa: 3.62, status: 'graduated', educationLevel: 'undergraduate' },
  { studentId: '202321099001', name: '岳明远', college: '数学学院', major: '应用数学', className: '应数 2301', gpa: 3.40, status: 'active', educationLevel: 'postgraduate' }
];

export const mockAdminCourses: AdminCourseItem[] = [
  { id: 'ac-1', code: 'CS101', name: '数据结构与算法', teacher: '苏婉清', category: 'required', credit: 4, timeText: '周一 1-2 节', capacity: 60, selectedCount: 58, status: 'open' },
  { id: 'ac-2', code: 'LIT201', name: '中国古典文学赏析', teacher: '陆清和', category: 'elective', credit: 2, timeText: '周二 3-4 节', capacity: 80, selectedCount: 80, status: 'open' },
  { id: 'ac-3', code: 'ART303', name: '视觉传达基础', teacher: '林婉如', category: 'public', credit: 2, timeText: '周三 5-6 节', capacity: 40, selectedCount: 32, status: 'open' },
  { id: 'ac-4', code: 'PR101', name: '社会实践 I', teacher: '李辰', category: 'practice', credit: 1, timeText: '集中实践', capacity: 200, selectedCount: 165, status: 'open' },
  { id: 'ac-5', code: 'CS401', name: '操作系统原理', teacher: '韩予', category: 'required', credit: 4, timeText: '周四 1-2 节', capacity: 60, selectedCount: 60, status: 'closed' }
];

export const mockSelectionRounds: SelectionRound[] = [
  {
    id: 'r-1', name: '第一轮预选', status: 'ended',
    startTime: '2026-04-10 09:00', endTime: '2026-04-15 23:59',
    progressPercent: 100, participantCount: 11800, selectionCount: 38962,
    averageCredit: 22.4, conflictCount: 218
  },
  {
    id: 'r-2', name: '第二轮正选', status: 'running',
    startTime: '2026-05-20 09:00', endTime: '2026-05-30 23:59',
    progressPercent: 68, participantCount: 8124, selectionCount: 21540,
    averageCredit: 19.8, conflictCount: 86
  },
  {
    id: 'r-3', name: '第三轮补选', status: 'notStarted',
    startTime: '2026-06-05 09:00', endTime: '2026-06-08 23:59',
    progressPercent: 0, participantCount: 0, selectionCount: 0,
    averageCredit: 0, conflictCount: 0
  }
];

export const mockGradeAudits: GradeAuditItem[] = [
  { id: 'ga-1', courseName: '数据结构与算法', teachingClassName: '01 班', teacherName: '苏婉清', inputProgress: 100, status: 'pendingAudit', updatedAt: '2026-05-26 17:00' },
  { id: 'ga-2', courseName: '高等数学（下）', teachingClassName: '03 班', teacherName: '岳明远', inputProgress: 78, status: 'inputting', updatedAt: '2026-05-27 10:30' },
  { id: 'ga-3', courseName: '大学英语 IV', teachingClassName: '04 班', teacherName: 'Anya Lee', inputProgress: 100, status: 'published', updatedAt: '2026-05-20 16:00' },
  { id: 'ga-4', courseName: '中国古典文学赏析', teachingClassName: '02 班', teacherName: '陆清和', inputProgress: 100, status: 'appealed', updatedAt: '2026-05-25 09:00' }
];

export const mockEvaluationStats: EvaluationStats = {
  term: '2025-2026-2',
  openStatus: 'open',
  startTime: '2026-05-25 00:00',
  endTime: '2026-06-10 23:59',
  participationRate: 62.4,
  completionRate: 38.7,
  averageScore: 4.32,
  questionnaireCount: 6
};

export const mockApprovals: ApprovalItem[] = [
  { id: 'ap-1', type: '请假', applicantName: '林夏', applicantId: '202221001234', title: '社会实践请假申请', reason: '参加戏剧节展演。', status: 'pending', isUrgent: true, submittedAt: '2026-05-28 10:20' },
  { id: 'ap-2', type: '资料变更', applicantName: '宋衍', applicantId: '202221002021', title: '联系方式变更', reason: '更换手机号。', status: 'pending', isUrgent: false, submittedAt: '2026-05-27 14:55' },
  { id: 'ap-3', type: '成绩复核', applicantName: '陆清和', applicantId: '202220001100', title: '期末成绩复核', reason: '总评分数与预期不符。', status: 'approved', isUrgent: false, submittedAt: '2026-05-22 11:00' },
  { id: 'ap-4', type: '退课', applicantName: '苏婉清', applicantId: '202122000812', title: '视觉传达基础退课', reason: '课程时间冲突。', status: 'rejected', isUrgent: false, submittedAt: '2026-05-15 09:00' },
  { id: 'ap-5', type: '请假', applicantName: '岳明远', applicantId: '202321099001', title: '病假申请', reason: '感冒发烧。', status: 'withdrawn', isUrgent: false, submittedAt: '2026-05-10 14:30' }
];

export const mockApprovalDetail: ApprovalDetail = {
  id: 'ap-1', type: '请假', applicantName: '林夏', applicantId: '202221001234',
  title: '社会实践请假申请', reason: '参加广州市大学生戏剧节展演，需向辅导员与教务处申请请假 3 天。',
  status: 'pending', isUrgent: true, submittedAt: '2026-05-28 10:20',
  flow: [
    { id: 'fl-1', nodeName: '辅导员审核', operatorName: '陈舟', status: 'approved', handledAt: '2026-05-28 12:30', comment: '同意，已知会任课教师。' },
    { id: 'fl-2', nodeName: '教务处审核', status: 'pending' },
    { id: 'fl-3', nodeName: '存档', status: 'waiting' }
  ],
  attachments: ['mock://files/event-notice.pdf']
};

// 测试登录凭据（管理端）· 与 mockAdminProfile 对应
export const TEST_ADMIN_ID: string = 'A20251001';
export const TEST_ADMIN_PASSWORD: string = 'Admin@2024';
