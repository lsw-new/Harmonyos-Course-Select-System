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
}
