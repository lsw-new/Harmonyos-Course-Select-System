// 全局应用配置

// 运行模式（单一事实来源）——切换只改 runtimeMode 一处，避免多布尔组合态不一致：
//   mock   —— 课堂演示 / 无网展示：全部走本地 mock 数据，可重置，离线可用。
//   local  —— 单机版：走本地 RDB / Preferences，不访问后端（mock 仅作未落库项的展示兜底）。
//   remote —— 联机 / 生产 / 答辩：走 Track B 后端；调用失败直接报错，禁止静默回退 mock。
export type RuntimeMode = 'mock' | 'local' | 'remote';

export class AppConfig {
  // 切换运行模式只改这一处。
  // 2026-06-10 默认改为 remote：班级同学已开始真实注册使用，注册/登录必须走后端
  //（名册白名单、真实姓名/班级资料、按班级课表与评教任务均为后端能力；
  //  mock 模式下注册只在本机建号、登录恒显示内置演示资料「李仕炜」，会出现张冠李戴）。
  // 离线课堂演示时改回 'mock' 即可。
  static runtimeMode: RuntimeMode = 'remote';

  // 经 nginx 反向代理 + Let's Encrypt 证书的 HTTPS 域名（不再写死公网 HTTP IP）。
  // 2026-06-09 起域名由 lsw666.duckdns.org 迁移为 lsw666.dns.army（旧域名证书已失效，TLS 握手失败）。
  static baseUrl: string = 'https://lsw666.dns.army/api';
  // 数据加载延迟（ms）。全局「正在加载」遮罩由 AppRoute 统一控制，故此处保持较小值让页面快速就绪。
  static mockDelayMs: number = 60;
  static appName: string = '景德镇艺术职业大学教学管理系统';

  // ===== 以下为派生开关，一律以 runtimeMode 为唯一事实来源（getter，不可单独赋值） =====

  // 是否走远程后端：仅 remote 模式。
  static get useRemote(): boolean {
    return AppConfig.runtimeMode === 'remote';
  }

  // 远程调用失败是否允许静默回退本地 mock / 缓存：
  // ┌─ mock/local 模式：返回 true，但这两种模式本就不走远程路径，此值无实际影响。
  // └─ remote 模式：返回 false，禁止任何静默回退 mock 数据——失败必须报错上报，
  //    防止后端不可用时 UI 静默展示 mock/mockAdmin 中的演示占位数据，造成数据误导。
  // 【mock 与真实数据边界】mock/ 目录下的数据均为演示用固定数据，不反映真实用户/班级情况；
  // remote 模式下，所有数据来源必须是 Track B 后端（https://lsw666.dns.army/api），
  // 绝不能将 mock 数据作为兜底"真实"结果呈现给已登录的真实用户。
  static get allowMockFallbackInRemote(): boolean {
    return AppConfig.runtimeMode !== 'remote';
  }

  // 是否以 mock 为主数据源：仅 mock 模式。
  static get useMock(): boolean {
    return AppConfig.runtimeMode === 'mock';
  }
}
