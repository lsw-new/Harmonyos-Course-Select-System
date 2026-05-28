// 基于 @ohos.data.preferences 的轻量本地配置存储

import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const STORE_NAME = 'app_preferences';

export class PreferenceStorage {
  private static instance?: PreferenceStorage;
  private store?: preferences.Preferences;

  static get(): PreferenceStorage {
    if (!PreferenceStorage.instance) {
      PreferenceStorage.instance = new PreferenceStorage();
    }
    return PreferenceStorage.instance;
  }

  async init(context: common.UIAbilityContext | common.Context): Promise<void> {
    if (this.store) {
      return;
    }
    this.store = await preferences.getPreferences(context, STORE_NAME);
  }

  async putString(key: string, value: string): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(key, value);
    await this.store.flush();
  }

  async getString(key: string, fallback: string = ''): Promise<string> {
    if (!this.store) {
      return fallback;
    }
    const v = await this.store.get(key, fallback);
    return typeof v === 'string' ? v : fallback;
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(key, value);
    await this.store.flush();
  }

  async getBoolean(key: string, fallback: boolean = false): Promise<boolean> {
    if (!this.store) {
      return fallback;
    }
    const v = await this.store.get(key, fallback);
    return typeof v === 'boolean' ? v : fallback;
  }

  async remove(key: string): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.delete(key);
    await this.store.flush();
  }
}
