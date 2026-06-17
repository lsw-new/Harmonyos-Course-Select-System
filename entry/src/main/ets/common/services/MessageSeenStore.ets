// 消息已读状态 · 按学号本地持久化（PreferenceStorage）。
// 与「紧急弹窗已读」同一套思路：只在本机记录已读的 message id 集合；
// 跨设备同步需后端，本期不做。

import { PreferenceStorage } from '../storage/PreferenceStorage';

const KEY_PREFIX = 'message.read.';

export class MessageSeenStore {
  private static keyFor(studentId: string): string {
    return KEY_PREFIX + studentId;
  }

  // 读取某学号已读的 message id 列表（损坏/缺失返回空）
  static async loadRead(studentId: string): Promise<string[]> {
    if (studentId.length === 0) {
      return [];
    }
    const raw = await PreferenceStorage.get().getString(MessageSeenStore.keyFor(studentId), '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  static async saveRead(studentId: string, ids: string[]): Promise<void> {
    if (studentId.length === 0) {
      return;
    }
    await PreferenceStorage.get().putString(MessageSeenStore.keyFor(studentId), JSON.stringify(ids));
  }

  // 标记单条已读（幂等）
  static async markRead(studentId: string, id: string): Promise<void> {
    const cur = await MessageSeenStore.loadRead(studentId);
    if (cur.indexOf(id) < 0) {
      cur.push(id);
      await MessageSeenStore.saveRead(studentId, cur);
    }
  }
}
