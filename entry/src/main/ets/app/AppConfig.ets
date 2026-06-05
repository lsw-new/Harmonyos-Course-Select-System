// 全局应用配置

export class AppConfig {
  static useMock: boolean = true;
  // Track B 远程开关：true 时认证/选课走远程后端（失败回退本地），默认 false 保持本地优先。
  static useRemote: boolean = false;
  // 远程模式下后端调用失败时，是否允许静默回退本地 mock / 缓存。
  // true（默认·演示友好）：远程失败回退本地，保证离线可演示。
  // false（生产建议）：禁止静默回退——登录失败直接报「远程服务异常」，不再用 mock 账号建立会话，
  //   避免后端不可用时给出误导性的「登录成功」。仅在 useRemote=true 时有意义。
  static allowMockFallbackInRemote: boolean = true;
  // 经 nginx 反向代理 + Let's Encrypt 证书的 HTTPS 域名（不再写死公网 HTTP IP）。
  static baseUrl: string = 'https://lsw666.duckdns.org/api';
  // 数据加载延迟（ms）。全局「正在加载」遮罩由 AppRoute 统一控制 1.5s，故此处保持较小值让页面在遮罩后快速就绪。
  static mockDelayMs: number = 60;
  static appName: string = '景德镇艺术职业大学教学管理系统';
}
