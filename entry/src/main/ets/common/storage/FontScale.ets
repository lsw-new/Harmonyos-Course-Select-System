// 全局字号比例：PreferenceStorage 持久化 + AppStorage 实时广播。
// 任何页面通过 @StorageProp('fontScaleRatio') 即可即时跟随；
// 设置页 select 后立即生效，无需重启或重新进入。

import { PreferenceStorage } from './PreferenceStorage';

const PREF_KEY = 'fontScale';
export const FONT_SCALE_STORAGE_KEY = 'fontScaleRatio';

class FontScaleOption {
  key: string = '';
  ratio: number = 1.0;
  constructor(key: string, ratio: number) {
    this.key = key;
    this.ratio = ratio;
  }
}

const OPTIONS: FontScaleOption[] = [
  new FontScaleOption('small', 0.87),
  new FontScaleOption('normal', 1.0),
  new FontScaleOption('large', 1.2)
];

export class FontScale {
  // 启动期：从持久化读出档位 → 写入 AppStorage 触发首次广播。
  static async init(): Promise<void> {
    const key = await PreferenceStorage.get().getString(PREF_KEY, 'normal');
    AppStorage.setOrCreate<number>(FONT_SCALE_STORAGE_KEY, FontScale.ratioOf(key));
  }

  // 设置页选档：双写持久化 + AppStorage，所有 @StorageProp 订阅者即时刷新。
  static async set(key: string): Promise<void> {
    await PreferenceStorage.get().putString(PREF_KEY, key);
    AppStorage.setOrCreate<number>(FONT_SCALE_STORAGE_KEY, FontScale.ratioOf(key));
  }

  static ratioOf(key: string): number {
    for (let i = 0; i < OPTIONS.length; i++) {
      if (OPTIONS[i].key === key) {
        return OPTIONS[i].ratio;
      }
    }
    return 1.0;
  }

  static currentRatio(): number {
    const r = AppStorage.get<number>(FONT_SCALE_STORAGE_KEY);
    return (typeof r === 'number' && r > 0) ? r : 1.0;
  }

  static scale(base: number): number {
    return Math.round(base * FontScale.currentRatio() * 100) / 100;
  }
}
