// ============================================================
// 【演示用模拟数据 · Mock — 非真实数据】
// 本文件为演示/离线展示专用，所有数据均为人工编造，不代表任何真实项目、机构或名额情况。
// remote 模式（AppConfig.runtimeMode = 'remote'）下，此文件中的数据不应作为数据来源出现；
// 该模式下实践项目数据由 Track B 后端（https://lsw666.dns.army/api）提供。
// ============================================================

// 实践项目种子数据 · Practice
// 覆盖四类（企业实习/科研训练/社会实践/志愿服务），名额各异，含一个已满项目。

import { PracticeProjectDetail } from '../models/PracticeModels';

// 详情为权威数据源；列表项由详情投影得到（去掉描述/要求等长字段）。
export const mockPracticeDetails: PracticeProjectDetail[] = [
  {
    id: 'p-001',
    title: '玫瑰科技 · 前端研发实习',
    org: '玫瑰科技有限公司',
    category: 'internship',
    credits: 3,
    period: '2026.07 - 2026.09',
    location: '玫瑰城 · 创新大厦 12F',
    mentor: '苏婉清',
    slotsTotal: 8,
    slotsTaken: 5,
    signedUp: false,
    description: '参与 HarmonyOS NEXT 应用前端开发，跟随导师完成真实业务模块，体验完整的需求评审、开发、测试与发版流程。',
    requirements: [
      '掌握 TypeScript / ArkTS 基础语法',
      '了解组件化与状态管理',
      '每周可保证 4 个工作日到岗',
      '具备良好的沟通与协作能力'
    ]
  },
  {
    id: 'p-002',
    title: '智慧城市数据分析实习',
    org: '云栖数据研究院',
    category: 'internship',
    credits: 2,
    period: '2026.07 - 2026.08',
    location: '云栖小镇 · B 座 3F',
    mentor: '陆清和',
    slotsTotal: 6,
    slotsTaken: 6,
    signedUp: false,
    description: '围绕城市交通与人流数据进行清洗、建模与可视化，输出分析报告并参与一次内部汇报。',
    requirements: [
      '熟悉 Python 数据处理',
      '了解基础统计与可视化方法',
      '对城市治理议题有兴趣'
    ]
  },
  {
    id: 'p-003',
    title: '类脑计算实验室 · 科研训练',
    org: '人工智能学院',
    category: 'research',
    credits: 4,
    period: '2026.03 - 2026.12',
    location: '理工楼 · 智能实验室 506',
    mentor: '林婉如',
    slotsTotal: 4,
    slotsTaken: 2,
    signedUp: false,
    description: '加入导师课题组，参与神经形态计算相关文献调研、实验设计与论文撰写，培养科研基本功。',
    requirements: [
      '修读过线性代数与概率论',
      '具备一定的英文文献阅读能力',
      '能投入长期、稳定的研究时间'
    ]
  },
  {
    id: 'p-004',
    title: '古典文献数字化整理项目',
    org: '人文学院 · 数字人文中心',
    category: 'research',
    credits: 2,
    period: '2026.04 - 2026.07',
    location: '文渊馆 · 古籍室',
    mentor: '沈砚秋',
    slotsTotal: 5,
    slotsTaken: 1,
    signedUp: false,
    description: '对馆藏古典文献进行扫描、校勘与结构化标注，参与构建可检索的数字文献库。',
    requirements: [
      '具备一定古汉语阅读基础',
      '细致、耐心，注重数据准确性',
      '熟悉基础的文本编辑工具'
    ]
  },
  {
    id: 'p-005',
    title: '乡村振兴社会实践调研',
    org: '校团委 · 社会实践部',
    category: 'social',
    credits: 2,
    period: '2026.07 (暑期两周)',
    location: '清和县 · 玫瑰村',
    mentor: '周牧云',
    slotsTotal: 20,
    slotsTaken: 12,
    signedUp: false,
    description: '深入乡村开展产业、教育与文化调研，形成调研报告并提出可落地的振兴建议。',
    requirements: [
      '能适应乡村调研的生活条件',
      '具备团队协作与访谈沟通能力',
      '愿意承担报告撰写任务'
    ]
  },
  {
    id: 'p-006',
    title: '玫瑰之家 · 敬老志愿服务',
    org: '青年志愿者协会',
    category: 'volunteer',
    credits: 1,
    period: '2026.03 - 2026.06 (每周末)',
    location: '玫瑰城 · 颐养中心',
    mentor: '叶知秋',
    slotsTotal: 30,
    slotsTaken: 18,
    signedUp: false,
    description: '为社区长者提供陪伴、文娱与基础健康监测等志愿服务，累计服务时长可计入第二课堂。',
    requirements: [
      '有爱心与责任心',
      '每月至少参与两次服务',
      '完成岗前志愿培训'
    ]
  }
];
