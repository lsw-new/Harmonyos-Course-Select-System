// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，所有学生档案均为人工编造，不代表任何真实学生信息。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下学籍详情由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

// 学籍详情 Mock 数据 · 覆盖 mockAdminStudents 中的全部 studentId
// 详情页通过 studentId 命中此表；如未命中则由仓储兜底生成基础档案。

import { StudentDetail } from '../models/StudentDetailModels';

export const mockStudentDetails: StudentDetail[] = [
  {
    studentId: '2023307020941',
    name: '李仕炜',
    gender: '男',
    college: '电子信息工程学院',
    major: '计算机科学与技术',
    className: '23计科U9',
    grade: '2023 级',
    gpa: 3.72,
    earnedCredits: 96,
    totalCredits: 160,
    phone: '138 0000 1234',
    email: 'lishiwei@jdart.edu.cn',
    dormitory: '紫藤苑 6 栋 412',
    advisor: '陈舟',
    status: 'active',
    enrollDate: '2023-09-01'
  },
  {
    studentId: '202221001235',
    name: '宋衍',
    gender: '男',
    college: '陶瓷艺术学院',
    major: '陶瓷艺术设计',
    className: '陶艺2201',
    grade: '2022 级',
    gpa: 3.58,
    earnedCredits: 92,
    totalCredits: 158,
    phone: '139 0000 2021',
    email: 'songyan@jdart.edu.cn',
    dormitory: '梧桐苑 3 栋 207',
    advisor: '周岚',
    status: 'active',
    enrollDate: '2022-09-01'
  },
  {
    studentId: '202220001100',
    name: '陆清和',
    gender: '女',
    college: '设计艺术学院',
    major: '视觉传达设计',
    className: '视传2102',
    grade: '2021 级',
    gpa: 3.86,
    earnedCredits: 148,
    totalCredits: 162,
    phone: '137 0000 1100',
    email: 'luqinghe@jdart.edu.cn',
    dormitory: '木棉苑 9 栋 510',
    advisor: '韩予',
    status: 'graduating',
    enrollDate: '2021-09-01'
  },
  {
    studentId: '202122000812',
    name: '苏婉清',
    gender: '女',
    college: '美术学院',
    major: '环境艺术设计',
    className: '环艺2002',
    grade: '2020 级',
    gpa: 3.62,
    earnedCredits: 160,
    totalCredits: 160,
    phone: '136 0000 0812',
    email: 'suwanqing@jdart.edu.cn',
    dormitory: '已离校',
    advisor: '林婉如',
    status: 'graduated',
    enrollDate: '2020-09-01'
  },
  {
    studentId: '202321099001',
    name: '岳明远',
    gender: '男',
    college: '音乐舞蹈学院',
    major: '音乐表演',
    className: '音乐2301',
    grade: '2023 级',
    gpa: 3.40,
    earnedCredits: 42,
    totalCredits: 120,
    phone: '135 0000 9001',
    email: 'yuemingyuan@jdart.edu.cn',
    dormitory: '研究生公寓 2 栋 318',
    advisor: '沈砚',
    status: 'active',
    enrollDate: '2023-09-01'
  },
  {
    studentId: '202221003366',
    name: '江晚意',
    gender: '女',
    college: '设计艺术学院',
    major: '数字媒体艺术设计',
    className: '数媒2203',
    grade: '2022 级',
    gpa: 3.91,
    earnedCredits: 98,
    totalCredits: 164,
    phone: '134 0000 3366',
    email: 'jiangwanyi@jdart.edu.cn',
    dormitory: '紫藤苑 5 栋 208',
    advisor: '韩予',
    status: 'suspended',
    enrollDate: '2022-09-01'
  }
];
