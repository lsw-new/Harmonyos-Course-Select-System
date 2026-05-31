import { EvaluationTask, EvaluationQuestionnaire } from '../models/Evaluation';

export const mockEvaluationTasks: EvaluationTask[] = [
  {
    id: 'eval-1', term: '2025-2026-2',
    courseCode: 'CS101', courseName: '数据结构与算法', courseCategory: '必修',
    teacherName: '苏婉清', questionnaireName: '理工类课程通用评教问卷',
    status: 'open', openTime: '2026-05-25 00:00', closeTime: '2026-06-10 23:59'
  },
  {
    id: 'eval-2', term: '2025-2026-2',
    courseCode: 'LIT201', courseName: '中国古典文学赏析', courseCategory: '选修',
    teacherName: '陆清和', questionnaireName: '人文社科类课程评教问卷',
    status: 'submitted', openTime: '2026-05-25 00:00', closeTime: '2026-06-10 23:59'
  },
  {
    id: 'eval-3', term: '2025-2026-2',
    courseCode: 'ENG202', courseName: '大学英语 IV', courseCategory: '必修',
    teacherName: '李安雅', questionnaireName: '语言类课程评教问卷',
    status: 'closed', closedReason: '不在开放期'
  }
];

export const mockQuestionnaire: EvaluationQuestionnaire = {
  taskId: 'eval-1',
  title: '理工类课程通用评教问卷',
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
