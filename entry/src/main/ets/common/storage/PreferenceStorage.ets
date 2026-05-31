// 基于 @ohos.data.preferences 的轻量本地配置存储

import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const STORE_NAME = 'app_preferences';

export class PreferenceStorage {
  private static instance?: PreferenceStorage;
  private store?: preferences.Preferences;
  private memory: Record<string, string | boolean> = {};

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
    const store = await preferences.getPreferences(context, STORE_NAME);
    this.store = store;
    const keys = Object.keys(this.memory);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = this.memory[key];
      await store.put(key, value);
    }
    if (keys.length > 0) {
      await store.flush();
      this.memory = {};
    }
  }

  async putString(key: string, value: string): Promise<void> {
    if (!this.store) {
      this.memory[key] = value;
      return;
    }
    await this.store.put(key, value);
    await this.store.flush();
  }

  async getString(key: string, fallback: string = ''): Promise<string> {
    if (!this.store) {
      const cached = this.memory[key];
      if (typeof cached === 'string') {
        return cached;
      }
      return fallback;
    }
    const v = await this.store.get(key, fallback);
    return typeof v === 'string' ? v : fallback;
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    if (!this.store) {
      this.memory[key] = value;
      return;
    }
    await this.store.put(key, value);
    await this.store.flush();
  }

  async getBoolean(key: string, fallback: boolean = false): Promise<boolean> {
    if (!this.store) {
      const cached = this.memory[key];
      if (typeof cached === 'boolean') {
        return cached;
      }
      return fallback;
    }
    const v = await this.store.get(key, fallback);
    return typeof v === 'boolean' ? v : fallback;
  }

  async remove(key: string): Promise<void> {
    if (!this.store) {
      // ArkTS 不支持 delete 运算符：重建一份不含该键的内存副本
      const next: Record<string, string | boolean> = {};
      const keys = Object.keys(this.memory);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] !== key) {
          next[keys[i]] = this.memory[keys[i]];
        }
      }
      this.memory = next;
      return;
    }
    await this.store.delete(key);
    await this.store.flush();
  }
}
