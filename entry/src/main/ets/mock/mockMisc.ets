import { LeaveRequest, FeedbackItem, PracticeEntry } from '../models/Misc';

export const mockLeaveRequests: LeaveRequest[] = [
  {
    id: 'lv-1', type: 'sick',
    startDate: '2026-05-15', endDate: '2026-05-16',
    reason: '感冒发烧，需在宿舍休息。',
    attachments: ['mock://files/medical-cert.jpg'],
    state: 'approved',
    submittedAt: '2026-05-14 19:30',
    feedback: '已批准，注意休息。'
  },
  {
    id: 'lv-2', type: 'personal',
    startDate: '2026-04-08', endDate: '2026-04-08',
    reason: '家中有事，回家半天。',
    attachments: [],
    state: 'rejected',
    submittedAt: '2026-04-07 21:10',
    feedback: '缺少证明材料。'
  },
  {
    id: 'lv-3', type: 'public',
    startDate: '2026-06-05', endDate: '2026-06-07',
    reason: '参加广州市大学生戏剧节展演。',
    attachments: ['mock://files/event-notice.pdf'],
    state: 'pending',
    submittedAt: '2026-05-28 10:20'
  }
];

export const mockFeedback: FeedbackItem[] = [
  {
    id: 'fb-1', category: 'bug',
    title: '课表页面在 iPad 横屏会错位',
    content: '切换到横屏模式时，周三的课程格出现重叠。',
    contact: 'linxia@example.edu.cn',
    screenshots: [],
    submittedAt: '2026-05-20 16:00',
    state: 'processing'
  },
  {
    id: 'fb-2', category: 'suggestion',
    title: '建议增加成绩排名显示',
    content: '希望成绩页面能显示班级和年级排名。',
    contact: '138****1234',
    screenshots: [],
    submittedAt: '2026-05-10 09:30',
    state: 'closed'
  }
];

export const mockPracticeEntries: PracticeEntry[] = [
  { key: 'intern', label: '实习实践', description: '认知实习、专业实习、顶岗实习', available: true },
  { key: 'central', label: '集中实践', description: '课程设计、毕业设计', available: true },
  { key: 'social', label: '社会实践', description: '寒暑假社会实践活动', available: true },
  { key: 'volunteer', label: '志愿服务', description: '校内外志愿活动报名', available: true },
  { key: 'guide', label: '办事指南', description: '一站式服务流程', available: true },
  { key: 'links', label: '常用链接', description: '校园生活常用入口', available: true },
  { key: 'lost', label: '失物招领', description: '失物登记与领取', available: false },
  { key: 'room', label: '空教室查询', description: '查找当前可用教室', available: true },
  { key: 'pay', label: '缴费查询', description: '学杂费、住宿费查询', available: false }
];
