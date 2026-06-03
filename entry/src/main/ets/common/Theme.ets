// 通用样式与主题 · Elysia Rose Theme
// 复用 ArkTS 常量定义

interface ElysiaPalette {
  rose50: string;
  rose100: string;
  rose200: string;
  rose300: string;
  rose400: string;
  rose500: string;
  rose600: string;
  rose700: string;
  cream50: string;
  cream100: string;
  lav200: string;
  lav300: string;
  lav500: string;
  gold300: string;
  gold500: string;
  gold700: string;
  // 语义状态色 —— 收敛页面里散落的写死强调/成功色字面量（精确沿用现有取值，零视觉变化）。
  roseAccent: string;   // 页面高频强调玫瑰（原散落 #D8546B 60 处）
  success: string;      // 成功 / 通过 绿（原散落 #7BB07B 24 处）
  ink: string;
  inkSoft: string;
  inkMute: string;
  surface: string;
  surfaceGlow: string;
  // 语义化半透明/表面 token —— 收敛页面里散落的写死浅色字面量。
  glass: string;        // 磨砂输入框 / 次按钮填充
  glassSoft: string;    // 更轻的磨砂层（圆形返回按钮等）
  barBg: string;        // 底部 TabBar / 操作栏背景
  pillBg: string;       // 标签 Pill 默认背景
  hairline: string;     // 描边
  hairlineSoft: string; // 更淡的描边
  scrim: string;        // 弹层遮罩
}

export class ElysiaTheme {
  private static readonly lightPalette: ElysiaPalette = {
    rose50: '#FFF6FA',
    rose100: '#FFE9F1',
    rose200: '#FFD3E3',
    rose300: '#FFB4CE',
    rose400: '#FF8DB4',
    rose500: '#F2709C',
    rose600: '#D85487',
    rose700: '#A93C68',
    cream50: '#FFFBF6',
    cream100: '#FFF4EB',
    lav200: '#EFDFFF',
    lav300: '#D9BFFF',
    lav500: '#B589FF',
    gold300: '#F2D5A0',
    gold500: '#D9B675',
    gold700: '#A8854A',
    roseAccent: '#D8546B',
    success: '#7BB07B',
    ink: '#4B2A38',
    inkSoft: '#7A5266',
    inkMute: '#B294A4',
    surface: '#FFFDFB',
    surfaceGlow: '#FFF1F7',
    glass: '#CCFFFFFF',
    glassSoft: '#A6FFFFFF',
    barBg: '#F2FFF6FA',
    pillBg: '#FFE4EE',
    hairline: '#80FFB3CE',
    hairlineSoft: '#66FFB3CE',
    scrim: '#66000000'
  };

  private static get palette(): ElysiaPalette {
    return ElysiaTheme.lightPalette;
  }

  // 主色 — 玫瑰
  static get ROSE_50(): string { return ElysiaTheme.palette.rose50; }
  static get ROSE_100(): string { return ElysiaTheme.palette.rose100; }
  static get ROSE_200(): string { return ElysiaTheme.palette.rose200; }
  static get ROSE_300(): string { return ElysiaTheme.palette.rose300; }
  static get ROSE_400(): string { return ElysiaTheme.palette.rose400; }
  static get ROSE_500(): string { return ElysiaTheme.palette.rose500; }
  static get ROSE_600(): string { return ElysiaTheme.palette.rose600; }
  static get ROSE_700(): string { return ElysiaTheme.palette.rose700; }

  // 奶油
  static get CREAM_50(): string { return ElysiaTheme.palette.cream50; }
  static get CREAM_100(): string { return ElysiaTheme.palette.cream100; }

  // 薰衣草
  static get LAV_200(): string { return ElysiaTheme.palette.lav200; }
  static get LAV_300(): string { return ElysiaTheme.palette.lav300; }
  static get LAV_500(): string { return ElysiaTheme.palette.lav500; }

  // 金
  static get GOLD_300(): string { return ElysiaTheme.palette.gold300; }
  static get GOLD_500(): string { return ElysiaTheme.palette.gold500; }
  static get GOLD_700(): string { return ElysiaTheme.palette.gold700; }

  // 语义状态色
  static get ROSE_ACCENT(): string { return ElysiaTheme.palette.roseAccent; }
  static get SUCCESS(): string { return ElysiaTheme.palette.success; }
  static get WARNING(): string { return ElysiaTheme.palette.gold500; }

  // 文本
  static get INK(): string { return ElysiaTheme.palette.ink; }
  static get INK_SOFT(): string { return ElysiaTheme.palette.inkSoft; }
  static get INK_MUTE(): string { return ElysiaTheme.palette.inkMute; }

  // 表面
  static get SURFACE(): string { return ElysiaTheme.palette.surface; }
  static get SURFACE_GLOW(): string { return ElysiaTheme.palette.surfaceGlow; }

  // 语义化半透明 / 表面 / 描边 token（纯浅色）。保留无参方法名，调用点统一为 `()`。
  static glass(): string { return ElysiaTheme.lightPalette.glass; }
  static glassSoft(): string { return ElysiaTheme.lightPalette.glassSoft; }
  static barBg(): string { return ElysiaTheme.lightPalette.barBg; }
  static pillBg(): string { return ElysiaTheme.lightPalette.pillBg; }
  static hairline(): string { return ElysiaTheme.lightPalette.hairline; }
  static hairlineSoft(): string { return ElysiaTheme.lightPalette.hairlineSoft; }
  static scrim(): string { return ElysiaTheme.lightPalette.scrim; }
  static surfaceOf(): string { return ElysiaTheme.lightPalette.surface; }

  // 页面整屏渐变背景的色标（纯浅色）。
  static pageGradient(): Array<[string, number]> {
    const p: ElysiaPalette = ElysiaTheme.lightPalette;
    return [[p.rose50, 0.0], [p.cream50, 0.55], [p.surfaceGlow, 1.0]];
  }

  // 字体
  static readonly FONT_DISPLAY: string = 'serif'; // 替换为 Cormorant Garamond
  static readonly FONT_BODY: string = 'HarmonyOS Sans';
}

// 渐变背景资源
export class Gradients {
  static phoneBg(): LinearGradient {
    return {
      angle: 180,
      colors: [
        [ElysiaTheme.ROSE_50, 0.0],
        [ElysiaTheme.CREAM_50, 0.55],
        [ElysiaTheme.SURFACE_GLOW, 1.0]
      ]
    } as LinearGradient;
  }

  static heroCard(): LinearGradient {
    return {
      angle: 135,
      colors: [
        [ElysiaTheme.ROSE_200, 0.0],
        [ElysiaTheme.ROSE_100, 0.4],
        [ElysiaTheme.LAV_200, 1.0]
      ]
    } as LinearGradient;
  }

  static primaryBtn(): LinearGradient {
    return {
      angle: 135,
      colors: [
        [ElysiaTheme.ROSE_400, 0.0],
        [ElysiaTheme.ROSE_500, 1.0]
      ]
    } as LinearGradient;
  }
}

interface LinearGradient {
  angle: number;
  colors: Array<[string, number]>;
}
