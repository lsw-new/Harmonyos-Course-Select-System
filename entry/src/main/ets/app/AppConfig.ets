// 全局应用配置

export class AppConfig {
  static useMock: boolean = true;
  // Track B 远程开关：true 时认证/选课走远程后端（失败回退本地），默认 false 保持本地优先。
  static useRemote: boolean = false;
  static baseUrl: string = 'http://138.2.47.185:8090/api';
  static mockDelayMs: number = 60;
  static appName: string = '景德镇艺术职业大学教学管理系统';
}
