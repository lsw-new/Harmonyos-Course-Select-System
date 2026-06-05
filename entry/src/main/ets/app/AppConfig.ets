// 全局应用配置

export class AppConfig {
  static useMock: boolean = true;
  // Track B 远程开关：true 时认证/选课走远程后端（失败回退本地），默认 false 保持本地优先。
  static useRemote: boolean = false;
  // 经 nginx 反向代理 + Let's Encrypt 证书的 HTTPS 域名（不再写死公网 HTTP IP）。
  static baseUrl: string = 'https://lsw666.duckdns.org/api';
  // 数据加载延迟（ms）。全局「正在加载」遮罩由 AppRoute 统一控制 1.5s，故此处保持较小值让页面在遮罩后快速就绪。
  static mockDelayMs: number = 60;
  static appName: string = '景德镇艺术职业大学教学管理系统';
}
