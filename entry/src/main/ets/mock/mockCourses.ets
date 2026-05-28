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
    college: '计算机学院',
    campus: '玫瑰校区',
    classroom: '理工楼 305',
    weeks: '1-16 周',
    periodStart: 1,
    periodEnd: 2,
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
    college: '人文学院',
    campus: '玫瑰校区',
    classroom: '文渊馆 201',
    weeks: '1-12 周',
    periodStart: 3,
    periodEnd: 4,
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
    college: '艺术学院',
    classroom: '艺术楼 A102',
    weeks: '2-15 周',
    periodStart: 5,
    periodEnd: 6,
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
    college: '数学学院',
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
    teacher: 'Anya Lee',
    college: '外国语学院',
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
    id: 's-1', term: '2025-2026-2', type: 'normal', courseId: 'c-001',
    courseName: '数据结构与算法', teacher: '苏婉清',
    weekday: 1, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '理工楼 305',
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    weekText: '1-16 周', courseType: '必修'
  },
  {
    id: 's-2', term: '2025-2026-2', type: 'normal', courseId: 'c-002',
    courseName: '中国古典文学赏析', teacher: '陆清和',
    weekday: 2, periodStart: 3, periodEnd: 4,
    startTime: '10:00', endTime: '11:35', classroom: '文渊馆 201',
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    weekText: '1-12 周', courseType: '选修'
  },
  {
    id: 's-3', term: '2025-2026-2', type: 'normal', courseId: 'c-004',
    courseName: '高等数学（下）', teacher: '岳明远',
    weekday: 3, periodStart: 1, periodEnd: 2,
    startTime: '08:00', endTime: '09:35', classroom: '理工楼 102',
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
    weekText: '1-18 周', courseType: '必修'
  },
  {
    id: 's-4', term: '2025-2026-2', type: 'normal', courseId: 'c-003',
    courseName: '视觉传达基础', teacher: '林婉如',
    weekday: 3, periodStart: 5, periodEnd: 6,
    startTime: '14:00', endTime: '15:35', classroom: '艺术楼 A102',
    weeks: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    weekText: '2-15 周', courseType: '公选'
  },
  {
    id: 's-5', term: '2025-2026-2', type: 'normal', courseId: 'c-005',
    courseName: '大学英语 IV', teacher: 'Anya Lee',
    weekday: 4, periodStart: 7, periodEnd: 8,
    startTime: '16:00', endTime: '17:35', classroom: '语音 203',
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    weekText: '1-16 周', courseType: '必修'
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
