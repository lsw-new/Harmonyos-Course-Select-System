// 响应式断点系统：sm(<600vp) / md(600–840vp) / lg(>=840vp)。
// 当前断点由 EntryAbility 监听窗口尺寸写入 AppStorage('breakpoint')，
// 页面用 @StorageProp('breakpoint') bp: string = 'sm' 订阅，按断点切换列数 / 内容最大宽度 / 间距。
// 目的：平板 / 折叠屏展开 / PC 上不再是“被拉宽的大号手机”，内容居中留白、多栏排布。

export type BreakpointType = 'sm' | 'md' | 'lg';

export class BreakpointManager {
  // 由宽度(vp)归类断点。
  static classify(widthVp: number): BreakpointType {
    if (widthVp >= 840) {
      return 'lg';
    }
    if (widthVp >= 600) {
      return 'md';
    }
    return 'sm';
  }

  // 卡片 / 列表多栏列数：sm 单栏，md 双栏，lg 三栏。
  static columns(bp: string): number {
    if (bp === 'lg') {
      return 3;
    }
    if (bp === 'md') {
      return 2;
    }
    return 1;
  }

  // 内容区最大宽度：大屏不铺满，居中留白。sm 返回极大值表示不限制（铺满手机宽）。
  static contentMaxWidth(bp: string): number {
    if (bp === 'lg') {
      return 880;
    }
    if (bp === 'md') {
      return 680;
    }
    return 100000;
  }

  // 页面左右安全留白（大屏更宽）。
  static gutter(bp: string): number {
    return bp === 'sm' ? 16 : 24;
  }
}
