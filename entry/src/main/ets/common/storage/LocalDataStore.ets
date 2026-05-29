import { PreferenceStorage } from './PreferenceStorage';

export class LocalDataStore {
  static async loadArray<T>(key: string, fallback: T[]): Promise<T[]> {
    const raw = await PreferenceStorage.get().getString(key, '');
    if (!raw) {
      return JSON.parse(JSON.stringify(fallback)) as T[];
    }
    try {
      const parsed = JSON.parse(raw) as T[];
      if (Array.isArray(parsed)) {
        return parsed;
      }
      return JSON.parse(JSON.stringify(fallback)) as T[];
    } catch (err) {
      return JSON.parse(JSON.stringify(fallback)) as T[];
    }
  }

  static async saveArray<T>(key: string, value: T[]): Promise<void> {
    await PreferenceStorage.get().putString(key, JSON.stringify(value));
  }
}
