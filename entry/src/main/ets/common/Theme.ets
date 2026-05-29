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
  ink: string;
  inkSoft: string;
  inkMute: string;
  surface: string;
  surfaceGlow: string;
}

export class ElysiaTheme {
  private static darkMode: boolean = false;

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
    ink: '#4B2A38',
    inkSoft: '#7A5266',
    inkMute: '#B294A4',
    surface: '#FFFDFB',
    surfaceGlow: '#FFF1F7'
  };

  private static readonly darkPalette: ElysiaPalette = {
    rose50: '#160D13',
    rose100: '#21131B',
    rose200: '#3A2030',
    rose300: '#5A2D46',
    rose400: '#FF9FBE',
    rose500: '#FF8DB4',
    rose600: '#F2709C',
    rose700: '#FFB4CE',
    cream50: '#160D13',
    cream100: '#21131B',
    lav200: '#33223D',
    lav300: '#4C3560',
    lav500: '#D9BFFF',
    gold300: '#F2D5A0',
    gold500: '#D9B675',
    gold700: '#F7D99B',
    ink: '#F8EAF1',
    inkSoft: '#E2C9D6',
    inkMute: '#BFA8B4',
    surface: '#241821',
    surfaceGlow: '#2D1B27'
  };

  private static get palette(): ElysiaPalette {
    return ElysiaTheme.darkMode ? ElysiaTheme.darkPalette : ElysiaTheme.lightPalette;
  }

  static setDarkMode(isDark: boolean): void {
    ElysiaTheme.darkMode = isDark;
  }

  static isDarkMode(): boolean {
    return ElysiaTheme.darkMode;
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

  // 文本
  static get INK(): string { return ElysiaTheme.palette.ink; }
  static get INK_SOFT(): string { return ElysiaTheme.palette.inkSoft; }
  static get INK_MUTE(): string { return ElysiaTheme.palette.inkMute; }

  // 表面
  static get SURFACE(): string { return ElysiaTheme.palette.surface; }
  static get SURFACE_GLOW(): string { return ElysiaTheme.palette.surfaceGlow; }

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
