import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo } from '../models/Course';

export const mockCourses: Course[] = [
  {
    id: 'c-001',
    code: 'CS101',
    teachingClassNo: '01',
    name: '数据结构与算法',
    category: '必修',
    credit: 4,
    teacher: '苏婉清',
    college: '电子信息工程学院',
    campus: '茶苑校区',
    classroom: '理工楼 305',
    weeks: '1-16 周',
    periodStart: 9,
    periodEnd: 10,
    weekday: 1,
    capacity: 60,
    selectedCount: 58,
    description: '线性表、栈与队列、树、图、查找与排序。',
    assessment: { usual: 30, experiment: 20, finalDefense: 50 }
  },
  {
    id: 'c-002',
    code: 'LIT201',
    teachingClassNo: '02',
    name: '中国古典文学赏析',
    category: '选修',
    credit: 2,
    teacher: '陆清和',
    college: '基础教学部',
    campus: '茶苑校区',
    classroom: '文渊馆 201',
    weeks: '1-12 周',
    periodStart: 9,
    periodEnd: 10,
    weekday: 2,
    capacity: 80,
    selectedCount: 80,
    description: '诗经楚辞、汉乐府、唐诗宋词、明清小说。',
    assessment: { usual: 40, experiment: 0, finalDefense: 60 }
  },
  {
    id: 'c-003',
    code: 'ART303',
    teachingClassNo: '01',
    name: '视觉传达基础',
    category: '公选',
    credit: 2,
    teacher: '林婉如',
    college: '设计艺术学院',
    classroom: '艺术楼 A102',
    weeks: '2-15 周',
    periodStart: 9,
    periodEnd: 10,
    weekday: 3,
    capacity: 40,
    selectedCount: 32,
    description: '色彩、构图、版式、符号语义。',
    assessment: { usual: 30, experiment: 40, finalDefense: 30 }
  },
  {
    id: 'c-004',
    code: 'MATH101',
    teachingClassNo: '03',
    name: '高等数学（下）',
    category: '必修',
    credit: 5,
    teacher: '岳明远',
    college: '基础教学部',
    classroom: '理工楼 102',
    weeks: '1-18 周',
    periodStart: 1,
    periodEnd: 2,
    weekday: 3,
    capacity: 120,
    selectedCount: 100
  },
  {
    id: 'c-005',
    code: 'ENG202',
    teachingClassNo: '04',
    name: '大学英语 IV',
    category: '必修',
    credit: 3,
    teacher: '李安雅',
    college: '基础教学部',
    classroom: '语音 203',
    weeks: '1-16 周',
    periodStart: 7,
    periodEnd: 8,
    weekday: 4,
    capacity: 50,
    selectedCount: 49
  }
];

export const mockSchedule: ScheduleItem[] = [
  {
    id: 'imp-1', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02119204',
    courseName: '鸿蒙应用开发初级认证', teacher: '方坚',
    weekday: 1, periodStart: 1, periodEnd: 4,
    startTime: '08:00', endTime: '11:35', classroom: '上茶苑教7栋404（光接入实训室）', campus: '茶苑校区',
    weeks: [2, 3, 4, 5, 7, 8, 9, 11, 12],
    weekText: '2-5,7-9,11-12 周', courseType: '必修'
  },
  {
    id: 'imp-2', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 1, periodStart: 1, periodEnd: 4,
    startTime: '08:00', endTime: '11:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-20', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 1, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [3, 4, 5, 7, 8, 9, 11, 12, 13, 14, 15],
    weekText: '3-5,7-9,11-15 周', courseType: '必修'
  },
  {
    id: 'imp-21', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02115104',
    courseName: '大型数据库管理与维护', teacher: '陈勇',
    weekday: 1, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教7栋702', campus: '茶苑校区',
    weeks: [16, 17],
    weekText: '16-17 周', courseType: '必修'
  },
  {
    id: 'imp-31', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 1, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教8栋515', campus: '茶苑校区',
    weeks: [13, 14, 15, 16],
    weekText: '13-16 周', courseType: '必修'
  },
  {
    id: 'imp-3', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 2, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教8栋513', campus: '茶苑校区',
    weeks: [7, 8, 9, 10, 11, 12, 17],
    weekText: '7-12,17 周', courseType: '必修'
  },
  {
    id: 'imp-4', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 2, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [16],
    weekText: '16 周', courseType: '必修'
  },
  {
    id: 'imp-5', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02119204',
    courseName: '鸿蒙应用开发初级认证', teacher: '方坚',
    weekday: 2, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教7栋302（数据通信实训室）', campus: '茶苑校区',
    weeks: [6],
    weekText: '6 周', courseType: '必修'
  },
  {
    id: 'imp-6', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 2, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-13', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 2, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [16],
    weekText: '16 周', courseType: '必修'
  },
  {
    id: 'imp-14', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02119204',
    courseName: '鸿蒙应用开发初级认证', teacher: '方坚',
    weekday: 2, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教7栋302（数据通信实训室）', campus: '茶苑校区',
    weeks: [6],
    weekText: '6 周', courseType: '必修'
  },
  {
    id: 'imp-15', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 2, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-22', term: '2025-2026-2', type: 'normal', courseId: 'VMK01100203',
    courseName: '中国近现代史纲要', teacher: '谢双明',
    weekday: 2, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '长芗苑教13栋205', campus: '芗苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9],
    weekText: '2-9 周', courseType: '公选'
  },
  {
    id: 'imp-23', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 2, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [12],
    weekText: '12 周', courseType: '必修'
  },
  {
    id: 'imp-24', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 2, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [13],
    weekText: '13 周', courseType: '必修'
  },
  {
    id: 'imp-32', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02102903',
    courseName: '软件工程', teacher: '黄卫东',
    weekday: 2, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教9栋704', campus: '茶苑校区',
    weeks: [3, 5, 7, 9, 11, 12, 16],
    weekText: '3-11单,12,16 周', courseType: '必修'
  },
  {
    id: 'imp-33', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02102903',
    courseName: '软件工程', teacher: '黄卫东',
    weekday: 2, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教8栋514', campus: '茶苑校区',
    weeks: [2, 4, 6, 8, 10, 17],
    weekText: '2-10双,17 周', courseType: '必修'
  },
  {
    id: 'imp-7', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 3, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教9栋510', campus: '茶苑校区',
    weeks: [16],
    weekText: '16 周', courseType: '必修'
  },
  {
    id: 'imp-8', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 3, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-16', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 3, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-25', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02115104',
    courseName: '大型数据库管理与维护', teacher: '陈勇',
    weekday: 3, periodStart: 5, periodEnd: 8,
    startTime: '14:00', endTime: '17:35', classroom: '上茶苑教7栋702', campus: '茶苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17],
    weekText: '2-13,15-17 周', courseType: '必修'
  },
  {
    id: 'imp-10', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 4, periodStart: 1, periodEnd: 4,
    startTime: '08:00', endTime: '11:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-9', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02119204',
    courseName: '鸿蒙应用开发初级认证', teacher: '方坚',
    weekday: 4, periodStart: 1, periodEnd: 4,
    startTime: '08:00', endTime: '11:35', classroom: '上茶苑教7栋404（光接入实训室）', campus: '茶苑校区',
    weeks: [8, 9, 10, 11, 12],
    weekText: '8-12 周', courseType: '必修'
  },
  {
    id: 'imp-26', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02102903',
    courseName: '软件工程', teacher: '黄卫东',
    weekday: 4, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教8栋512', campus: '茶苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    weekText: '2-11 周', courseType: '必修'
  },
  {
    id: 'imp-27', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02102903',
    courseName: '软件工程', teacher: '黄卫东',
    weekday: 4, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教9栋704', campus: '茶苑校区',
    weeks: [17],
    weekText: '17 周', courseType: '必修'
  },
  {
    id: 'imp-34', term: '2025-2026-2', type: 'normal', courseId: 'VMK01100203',
    courseName: '中国近现代史纲要', teacher: '谢双明',
    weekday: 4, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '长芗苑教13栋205', campus: '芗苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9],
    weekText: '2-9 周', courseType: '公选'
  },
  {
    id: 'imp-35', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 4, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教8栋516', campus: '茶苑校区',
    weeks: [16, 17],
    weekText: '16-17 周', courseType: '必修'
  },
  {
    id: 'imp-36', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 4, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教8栋612', campus: '茶苑校区',
    weeks: [11, 12, 13, 14, 15],
    weekText: '11-15 周', courseType: '必修'
  },
  {
    id: 'imp-40', term: '2025-2026-2', type: 'normal', courseId: 'VJW01102302',
    courseName: '博物馆展览鉴赏', teacher: '汪芷晔',
    weekday: 4, periodStart: 9, periodEnd: 10,
    startTime: '19:00', endTime: '20:35', classroom: '长芗苑教10栋202', campus: '芗苑校区',
    weeks: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
    weekText: '3-18 周', courseType: '公选'
  },
  {
    id: 'imp-11', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 5, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-17', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 5, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教8栋613', campus: '茶苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9],
    weekText: '2-9 周', courseType: '必修'
  },
  {
    id: 'imp-18', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02114904',
    courseName: '软件测试与管理', teacher: '胡晓春',
    weekday: 5, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教8栋612', campus: '茶苑校区',
    weeks: [10, 11, 12],
    weekText: '10-12 周', courseType: '必修'
  },
  {
    id: 'imp-19', term: '2025-2026-2', type: 'practice', courseId: 'VDZ02119303',
    courseName: '鸿蒙移动应用开发综合实践', teacher: '王鑫',
    weekday: 5, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '上茶苑教9栋401（软件工程实训室）', campus: '茶苑校区',
    weeks: [13, 14, 15],
    weekText: '13-15 周', courseType: '必修'
  },
  {
    id: 'imp-28', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 5, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教8栋514', campus: '茶苑校区',
    weeks: [10, 11, 12, 13, 14, 15, 16, 17],
    weekText: '10-17 周', courseType: '必修'
  },
  {
    id: 'imp-29', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 5, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '上茶苑教8栋516', campus: '茶苑校区',
    weeks: [7, 8, 9],
    weekText: '7-9 周', courseType: '必修'
  },
  {
    id: 'imp-37', term: '2025-2026-2', type: 'normal', courseId: 'VMK01100203',
    courseName: '中国近现代史纲要', teacher: '谢双明',
    weekday: 5, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '实践考察',
    weeks: [6, 7, 8, 9],
    weekText: '6-9 周', courseType: '公选'
  },
  {
    id: 'imp-38', term: '2025-2026-2', type: 'normal', courseId: 'VMK01100203',
    courseName: '中国近现代史纲要', teacher: '谢双明',
    weekday: 5, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '长芗苑教13栋205', campus: '芗苑校区',
    weeks: [2, 3, 4, 5],
    weekText: '2-5 周', courseType: '公选'
  },
  {
    id: 'imp-39', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02112704',
    courseName: '计算机组成原理', teacher: '孙连科',
    weekday: 5, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '上茶苑教9栋402（计算机组成原理实训室）', campus: '茶苑校区',
    weeks: [10, 11, 12, 13, 14, 15, 16, 17],
    weekText: '10-17 周', courseType: '必修'
  },
  {
    id: 'imp-12', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02119204',
    courseName: '鸿蒙应用开发初级认证', teacher: '方坚',
    weekday: 6, periodStart: 1, periodEnd: 4,
    startTime: '08:00', endTime: '11:35', classroom: '上茶苑教7栋805（网络系统管理实训室）', campus: '茶苑校区',
    weeks: [11],
    weekText: '11 周', courseType: '必修'
  },
  {
    id: 'imp-30', term: '2025-2026-2', type: 'normal', courseId: 'VDZ02103003',
    courseName: '编译原理', teacher: '张毅恒',
    weekday: 6, periodStart: 5, periodEnd: 8,
    startTime: '14:00', endTime: '17:35', classroom: '上茶苑教7栋802', campus: '茶苑校区',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    weekText: '2-13 周', courseType: '必修'
  }
];

export const mockSelectionCourses: SelectionCourse[] = [
  { course: mockCourses[0], status: 'selected' },
  { course: mockCourses[1], status: 'full' },
  { course: mockCourses[2], status: 'available' },
  { course: mockCourses[3], status: 'conflict', conflictWith: '高等数学时间冲突' },
  { course: mockCourses[4], status: 'available' }
];

export const mockSelectionRound: SelectionRoundInfo = {
  roundName: '第二轮选课',
  startTime: '2026-05-20 09:00',
  endTime: '2026-05-30 23:59',
  remainingSeconds: 3 * 86400 + 4 * 3600,
  selectedCredits: 18,
  creditLimit: 28,
  inProgress: true
};
