// 全局应用配置

export class AppConfig {
  static useMock: boolean = true;
  // Track B 远程开关：true 时认证/选课走远程后端（失败回退本地），默认 false 保持本地优先。
  static useRemote: boolean = false;
  static baseUrl: string = 'http://138.2.47.185:8090/api';
  // 数据加载延迟：每次仓储取数耗时，使带 loading 态的页面统一显示约 1.5 秒「正在加载」
  static mockDelayMs: number = 1500;
  static appName: string = '景德镇艺术职业大学教学管理系统';
}
