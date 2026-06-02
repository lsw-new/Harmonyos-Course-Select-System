// Track B 远程数据源：封装后端 API 调用（认证 / 课程 / 选课垂直切片）。
// 仅当 AppConfig.useRemote=true 时被仓储调用；apiClient 已自动拆 ApiResponse 信封并附带 token。
// 说明：ArkTS 禁 Record 对象字面量，故 GET 查询参数内联进 path、POST/DELETE body 用具名接口。
import { apiClient } from '../http/ApiClient';

export interface RemoteCourse {
  id: string;
  code: string;
  name: string;
  teacher: string;
  category: string;
  credit: number;
  timeText: string;
  capacity: number;
  selectedCount: number;
  status: string;
}

export interface RemoteRound {
  id: string;
  name: string;
  status: string;
  startTime: string;
  endTime: string;
  creditLimit: number;
}

export interface RemoteLoginResult {
  token: string;
  accountId: string;
  role: string;
}

interface LoginBody {
  account: string;
  password: string;
}

interface SelectionBody {
  studentId: string;
  courseId: string;
}

export interface RemoteGrade {
  id: string;
  term: string;
  courseCode: string;
  teachingClassNo: string;
  courseName: string;
  courseCategory: string;
  credit: number;
  score: number;
  gradePoint: number;
  rank: number;
  publishedAt: string;
}

export interface RemoteNotice {
  id: string;
  title: string;
  publisher: string;
  publishedAt: string;
  summary: string;
  content: string;
  isRead: boolean;
  category: string;
  attachments: string[];
}

export interface RemoteLeave {
  id: string;
  type: string;
  startDate: string;
  endDate: string;
  reason: string;
  attachments: string[];
  state: string;
  submittedAt: string;
  feedback: string;
}

interface LeaveCreateBody {
  studentId: string;
  type: string;
  startDate: string;
  endDate: string;
  reason: string;
}

interface StudentIdBody {
  studentId: string;
}

export interface RemoteFeedback {
  id: string;
  category: string;
  title: string;
  content: string;
  contact: string;
  screenshots: string[];
  submittedAt: string;
  state: string;
}

export interface RemoteEvalTask {
  id: string;
  term: string;
  courseCode: string;
  courseName: string;
  courseCategory: string;
  teacherName: string;
  questionnaireName: string;
  status: string;
  openTime: string;
  closeTime: string;
}

export interface RemotePractice {
  id: string;
  title: string;
  org: string;
  category: string;
  credits: number;
  period: string;
  location: string;
  mentor: string;
  slotsTotal: number;
  slotsTaken: number;
  signedUp: boolean;
  description: string;
  requirements: string[];
}

interface FeedbackBody {
  studentId: string;
  category: string;
  title: string;
  content: string;
  contact: string;
}

interface EvalSubmitBody {
  studentId: string;
  answers: Object;
}

export class RemoteApi {
  static async login(account: string, password: string): Promise<RemoteLoginResult> {
    const body: LoginBody = { account: account, password: password };
    return apiClient.post<RemoteLoginResult>('/auth/login', body);
  }

  static async listOpenCourses(): Promise<RemoteCourse[]> {
    return apiClient.get<RemoteCourse[]>('/courses?status=open');
  }

  static async mySelections(studentId: string): Promise<RemoteCourse[]> {
    return apiClient.get<RemoteCourse[]>('/selections?studentId=' + encodeURIComponent(studentId));
  }

  static async activeRound(): Promise<RemoteRound | null> {
    return apiClient.get<RemoteRound | null>('/selection-rounds/active');
  }

  static async select(studentId: string, courseId: string): Promise<void> {
    const body: SelectionBody = { studentId: studentId, courseId: courseId };
    await apiClient.post<Object>('/selections', body);
  }

  static async drop(studentId: string, courseId: string): Promise<void> {
    const body: SelectionBody = { studentId: studentId, courseId: courseId };
    await apiClient.delete<Object>('/selections', body);
  }

  static async listGrades(studentId: string, term?: string): Promise<RemoteGrade[]> {
    let path = '/grades?studentId=' + encodeURIComponent(studentId);
    if (term && term.length > 0 && term !== '全部') {
      path += '&term=' + encodeURIComponent(term);
    }
    return apiClient.get<RemoteGrade[]>(path);
  }

  static async listNotices(studentId: string, category?: string): Promise<RemoteNotice[]> {
    let path = '/notices?studentId=' + encodeURIComponent(studentId);
    if (category && category.length > 0 && category !== '全部') {
      path += '&category=' + encodeURIComponent(category);
    }
    return apiClient.get<RemoteNotice[]>(path);
  }

  static async noticeDetail(studentId: string, id: string): Promise<RemoteNotice> {
    return apiClient.get<RemoteNotice>('/notices/' + encodeURIComponent(id) + '?studentId=' + encodeURIComponent(studentId));
  }

  static async markNoticeRead(studentId: string, id: string): Promise<void> {
    const body: StudentIdBody = { studentId: studentId };
    await apiClient.post<Object>('/notices/' + encodeURIComponent(id) + '/read', body);
  }

  static async listLeave(studentId: string): Promise<RemoteLeave[]> {
    return apiClient.get<RemoteLeave[]>('/leave?studentId=' + encodeURIComponent(studentId));
  }

  static async submitLeave(studentId: string, type: string, startDate: string, endDate: string, reason: string): Promise<RemoteLeave> {
    const body: LeaveCreateBody = { studentId: studentId, type: type, startDate: startDate, endDate: endDate, reason: reason };
    return apiClient.post<RemoteLeave>('/leave', body);
  }

  static async listFeedback(studentId: string): Promise<RemoteFeedback[]> {
    return apiClient.get<RemoteFeedback[]>('/feedback?studentId=' + encodeURIComponent(studentId));
  }

  static async submitFeedback(studentId: string, category: string, title: string, content: string, contact: string): Promise<RemoteFeedback> {
    const body: FeedbackBody = { studentId: studentId, category: category, title: title, content: content, contact: contact };
    return apiClient.post<RemoteFeedback>('/feedback', body);
  }

  static async listEvaluations(studentId: string, term?: string): Promise<RemoteEvalTask[]> {
    let path = '/evaluations?studentId=' + encodeURIComponent(studentId);
    if (term && term.length > 0 && term !== '全部') {
      path += '&term=' + encodeURIComponent(term);
    }
    return apiClient.get<RemoteEvalTask[]>(path);
  }

  static async submitEvaluation(studentId: string, taskId: string, answers: Object): Promise<void> {
    const body: EvalSubmitBody = { studentId: studentId, answers: answers };
    await apiClient.post<Object>('/evaluations/' + encodeURIComponent(taskId) + '/submit', body);
  }

  static async listPractice(studentId: string, category?: string): Promise<RemotePractice[]> {
    let path = '/practice?studentId=' + encodeURIComponent(studentId);
    if (category && category.length > 0) {
      path += '&category=' + encodeURIComponent(category);
    }
    return apiClient.get<RemotePractice[]>(path);
  }

  static async practiceDetail(studentId: string, id: string): Promise<RemotePractice> {
    return apiClient.get<RemotePractice>('/practice/' + encodeURIComponent(id) + '?studentId=' + encodeURIComponent(studentId));
  }

  static async practiceSignup(studentId: string, id: string): Promise<RemotePractice> {
    const body: StudentIdBody = { studentId: studentId };
    return apiClient.post<RemotePractice>('/practice/' + encodeURIComponent(id) + '/signup', body);
  }

  static async practiceCancel(studentId: string, id: string): Promise<RemotePractice> {
    const body: StudentIdBody = { studentId: studentId };
    return apiClient.delete<RemotePractice>('/practice/' + encodeURIComponent(id) + '/signup', body);
  }
}
