import { EvaluationTask, EvaluationQuestionnaire } from '../models/Evaluation';

// 23计算机科学与技术U9 班级课表的 9 门真实课程与授课教师（与后端 course_teachers 同源）
export const mockEvaluationTasks: EvaluationTask[] = [
  {
    id: 'eval-VDZ02119204', term: '2025-2026-2',
    courseCode: 'VDZ02119204', courseName: '鸿蒙应用开发初级认证', courseCategory: '必修',
    teacherName: '方坚', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02119303', term: '2025-2026-2',
    courseCode: 'VDZ02119303', courseName: '鸿蒙移动应用开发综合实践', courseCategory: '必修',
    teacherName: '王鑫', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02114904', term: '2025-2026-2',
    courseCode: 'VDZ02114904', courseName: '软件测试与管理', courseCategory: '必修',
    teacherName: '胡晓春', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02115104', term: '2025-2026-2',
    courseCode: 'VDZ02115104', courseName: '大型数据库管理与维护', courseCategory: '必修',
    teacherName: '陈勇', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02112704', term: '2025-2026-2',
    courseCode: 'VDZ02112704', courseName: '计算机组成原理', courseCategory: '必修',
    teacherName: '孙连科', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02102903', term: '2025-2026-2',
    courseCode: 'VDZ02102903', courseName: '软件工程', courseCategory: '必修',
    teacherName: '黄卫东', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VDZ02103003', term: '2025-2026-2',
    courseCode: 'VDZ02103003', courseName: '编译原理', courseCategory: '必修',
    teacherName: '张毅恒', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VMK01100203', term: '2025-2026-2',
    courseCode: 'VMK01100203', courseName: '中国近现代史纲要', courseCategory: '公选',
    teacherName: '谢双明', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  },
  {
    id: 'eval-VJW01102302', term: '2025-2026-2',
    courseCode: 'VJW01102302', courseName: '博物馆展览鉴赏', courseCategory: '选修',
    teacherName: '汪芷晔', questionnaireName: '教学质量评价问卷',
    status: 'open', openTime: '2026-06-01 00:00', closeTime: '2026-07-15 23:59'
  }
];

export const mockQuestionnaire: EvaluationQuestionnaire = {
  taskId: 'eval-VDZ02119204',
  title: '教学质量评价问卷',
  description: '本问卷共 5 题，预计耗时 3 分钟。',
  questions: [
    {
      id: 'q-1', type: 'rating', required: true,
      title: '请对教师的整体教学水平进行评分（1-5）'
    },
    {
      id: 'q-2', type: 'single', required: true,
      title: '教师对课程内容的讲解清晰程度',
      options: [
        { id: 'a', label: '非常清晰', score: 5 },
        { id: 'b', label: '比较清晰', score: 4 },
        { id: 'c', label: '一般', score: 3 },
        { id: 'd', label: '不够清晰', score: 2 },
        { id: 'e', label: '不清晰', score: 1 }
      ]
    },
    {
      id: 'q-3', type: 'multiple', required: false,
      title: '你认为本课程的优点是（可多选）',
      options: [
        { id: 'a', label: '内容充实' },
        { id: 'b', label: '互动良好' },
        { id: 'c', label: '案例丰富' },
        { id: 'd', label: '考核合理' }
      ]
    },
    {
      id: 'q-4', type: 'rating', required: true,
      title: '请对课程的作业与考核难度进行评分'
    },
    {
      id: 'q-5', type: 'text', required: false, maxLength: 200,
      title: '其他建议与意见（选填）'
    }
  ]
};
