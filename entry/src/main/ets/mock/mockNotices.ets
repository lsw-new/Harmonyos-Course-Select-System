import { Notice } from '../models/Notice';

export const mockNotices: Notice[] = [
  {
    id: 'n-1',
    title: '关于 2026 春季学期评教任务开放的通知',
    publisher: '教务处',
    publishedAt: '2026-05-25 09:00',
    summary: '本学期评教任务已开放，请同学们在 6 月 10 日前完成。',
    content: '为提升教学质量，本学期评教任务已于 5 月 25 日开放。\n\n请同学们登录教学管理系统，进入"量化评教"模块，完成本学期所有课程的评教任务。截止时间为 2026 年 6 月 10 日 23:59。\n\n评教结果将用于教师教学绩效评估，请认真填写。',
    isRead: false,
    category: '教务',
    attachments: []
  },
  {
    id: 'n-2',
    title: '端午节放假安排通知',
    publisher: '学生工作处',
    publishedAt: '2026-05-22 14:30',
    summary: '6 月 9 日至 6 月 11 日放假调休，共 3 天。',
    content: '根据国务院办公厅通知，2026 年端午节放假安排如下：\n\n6 月 9 日（星期一）至 6 月 11 日（星期三）放假调休，共 3 天。\n6 月 12 日（星期四）正常上课。\n\n请同学们合理安排出行计划，注意安全。',
    isRead: true,
    category: '学工',
    attachments: [
      { id: 'a-1', fileName: '端午放假调休安排.pdf', fileUrl: 'mock://files/duanwu.pdf', fileSize: 184320 }
    ]
  },
  {
    id: 'n-3',
    title: '图书馆暑期开放时间调整',
    publisher: '图书馆',
    publishedAt: '2026-05-20 10:15',
    summary: '7 月 1 日起调整为 8:00-22:00。',
    content: '亲爱的读者：\n\n自 7 月 1 日起，图书馆开放时间调整为每日 8:00-22:00。\n\n暑期阅览室、自习区域开放安排详见附件。',
    isRead: true,
    category: '生活',
    attachments: [
      { id: 'a-2', fileName: '图书馆暑期开放时间表.xlsx', fileUrl: 'mock://files/library.xlsx', fileSize: 24576 }
    ]
  },
  {
    id: 'n-4',
    title: '关于第二轮选课的重要提醒',
    publisher: '教务处',
    publishedAt: '2026-05-18 16:00',
    summary: '第二轮选课 5 月 20 日开始。',
    content: '第二轮选课开放时间：2026 年 5 月 20 日 09:00 - 5 月 30 日 23:59。\n\n请同学们及时登录教学管理系统进行选课操作。',
    isRead: false,
    category: '教务',
    attachments: []
  }
];
