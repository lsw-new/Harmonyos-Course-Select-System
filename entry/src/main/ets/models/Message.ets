// 个人系统消息 · 与「公告（Notice）」彻底区分：
// 公告 = 教务处/学工发布的广播（NoticesPage + 紧急强制弹窗的来源）
// 消息 = 学生本人的事务回执，由 MessageRepository 从现有 请假/成绩/选课/评教 接口聚合而成
//        点开 message 跳到 route(+param) 对应的页面；已读状态按学号本地持久化。

export interface Message {
  id: string;        // 稳定且可去重：如 msg-leave-<leaveId>-<state>、msg-grade-<gradeId>、msg-eval-open
  kind: string;      // 'leave' | 'grade' | 'selection' | 'eval'
  title: string;     // 一行标题，如「请假申请已通过」
  body: string;      // 一行摘要
  timestamp: string; // 事件时间（提交/发布/开放）；无时间则为空串，排序时置末
  isRead: boolean;   // 由本地已读集合（MessageSeenStore）派生
  route: string;     // 点击跳转的目标页（Routes.*）
  param?: Record<string, Object>; // 跳转参数，如请假详情的 { id }
}
