// 通用样式与主题 · Elysia Rose Theme
// 复用 ArkTS 常量定义

export class ElysiaTheme {
  // 主色 — 玫瑰
  static readonly ROSE_50: string = '#FFF6FA';
  static readonly ROSE_100: string = '#FFE9F1';
  static readonly ROSE_200: string = '#FFD3E3';
  static readonly ROSE_300: string = '#FFB4CE';
  static readonly ROSE_400: string = '#FF8DB4';
  static readonly ROSE_500: string = '#F2709C';
  static readonly ROSE_600: string = '#D85487';
  static readonly ROSE_700: string = '#A93C68';

  // 奶油
  static readonly CREAM_50: string = '#FFFBF6';
  static readonly CREAM_100: string = '#FFF4EB';

  // 薰衣草
  static readonly LAV_200: string = '#EFDFFF';
  static readonly LAV_300: string = '#D9BFFF';
  static readonly LAV_500: string = '#B589FF';

  // 金
  static readonly GOLD_300: string = '#F2D5A0';
  static readonly GOLD_500: string = '#D9B675';
  static readonly GOLD_700: string = '#A8854A';

  // 文本
  static readonly INK: string = '#4B2A38';
  static readonly INK_SOFT: string = '#7A5266';
  static readonly INK_MUTE: string = '#B294A4';

  // 表面
  static readonly SURFACE: string = '#FFFDFB';
  static readonly SURFACE_GLOW: string = '#FFF1F7';

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
        ['#FFF0F5', 1.0]
      ]
    } as LinearGradient;
  }

  static heroCard(): LinearGradient {
    return {
      angle: 135,
      colors: [
        [ElysiaTheme.ROSE_200, 0.0],
        ['#FFE0E9', 0.4],
        [ElysiaTheme.LAV_200, 1.0]
      ]
    } as LinearGradient;
  }

  static primaryBtn(): LinearGradient {
    return {
      angle: 135,
      colors: [
        ['#FF9FBE', 0.0],
        [ElysiaTheme.ROSE_500, 1.0]
      ]
    } as LinearGradient;
  }
}

interface LinearGradient {
  angle: number;
  colors: Array<[string, number]>;
}
