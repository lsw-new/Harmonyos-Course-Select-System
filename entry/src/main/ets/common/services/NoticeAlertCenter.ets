// 通知强制弹窗调度中心：
// - 轮询通知列表，挑出 urgency = 'important' / 'urgent' 且当前账号未确认的条目
// - 通过 AppStorage 广播给 NoticeAlertOverlay 渲染强制弹窗
// - 已确认（点击"确定"）的条目按账号持久化到 PreferenceStorage，避免重复弹

import { Notice } from '../../models/Notice';
import { PreferenceStorage } from '../storage/PreferenceStorage';
import { SessionStorage } from '../storage/SessionStorage';

const PREF_PREFIX = 'notice.alert.seen.';
const STORAGE_CURRENT = 'noticeAlertCurrent';
const STORAGE_VERSION = 'noticeAlertVersion';
const POLL_INTERVAL_MS = 30000;

type NoticeLoader = () => Promise<Notice[]>;

interface SeenEntry {
  ownerId: string;
  ids: string[];
}

export class NoticeAlertCenter {
  private static loader?: NoticeLoader;
  private static timer: number = -1;
  private static queue: Notice[] = [];
  private static current?: Notice;
  private static seenIds: string[] = [];
  private static currentOwner: string = '';
  private static loading: boolean = false;

  static start(loader: NoticeLoader): void {
    NoticeAlertCenter.loader = loader;
    AppStorage.setOrCreate<number>(STORAGE_VERSION, 0);
    AppStorage.setOrCreate<Notice | undefined>(STORAGE_CURRENT, undefined);
    NoticeAlertCenter.kick();
    if (NoticeAlertCenter.timer < 0) {
      NoticeAlertCenter.timer = setInterval(() => {
        NoticeAlertCenter.kick();
      }, POLL_INTERVAL_MS);
    }
  }

  static stop(): void {
    if (NoticeAlertCenter.timer >= 0) {
      clearInterval(NoticeAlertCenter.timer);
      NoticeAlertCenter.timer = -1;
    }
  }

  // 学生/管理员切换或退出登录后，清空本地队列并按新账号重新计算
  static resetForOwnerChange(): void {
    NoticeAlertCenter.queue = [];
    NoticeAlertCenter.current = undefined;
    NoticeAlertCenter.seenIds = [];
    NoticeAlertCenter.currentOwner = '';
    AppStorage.setOrCreate<Notice | undefined>(STORAGE_CURRENT, undefined);
    NoticeAlertCenter.bumpVersion();
    NoticeAlertCenter.kick();
  }

  // 主动触发一次拉取（页面发布通知/进入首页时调用）
  static async kick(): Promise<void> {
    if (!NoticeAlertCenter.loader || NoticeAlertCenter.loading) {
      return;
    }
    const owner = NoticeAlertCenter.resolveOwner();
    if (!owner) {
      return;
    }
    NoticeAlertCenter.loading = true;
    try {
      if (owner !== NoticeAlertCenter.currentOwner) {
        NoticeAlertCenter.currentOwner = owner;
        NoticeAlertCenter.seenIds = await NoticeAlertCenter.loadSeen(owner);
      }
      const items = await NoticeAlertCenter.loader();
      const pending: Notice[] = [];
      for (let i = 0; i < items.length; i++) {
        const n = items[i];
        const u = n.urgency || 'normal';
        if (u !== 'important' && u !== 'urgent') {
          continue;
        }
        if (NoticeAlertCenter.seenIds.indexOf(n.id) >= 0) {
          continue;
        }
        if (NoticeAlertCenter.queue.some((q) => q.id === n.id)) {
          continue;
        }
        if (NoticeAlertCenter.current && NoticeAlertCenter.current.id === n.id) {
          continue;
        }
        pending.push(n);
      }
      // urgent 优先，其次按 publishedAt 倒序
      pending.sort((a, b) => {
        const aUrg = a.urgency === 'urgent' ? 0 : 1;
        const bUrg = b.urgency === 'urgent' ? 0 : 1;
        if (aUrg !== bUrg) {
          return aUrg - bUrg;
        }
        return a.publishedAt < b.publishedAt ? 1 : -1;
      });
      for (let i = 0; i < pending.length; i++) {
        NoticeAlertCenter.queue.push(pending[i]);
      }
      NoticeAlertCenter.promoteIfIdle();
    } catch (e) {
      // 拉取失败：保留队列状态，下一周期再尝试
    } finally {
      NoticeAlertCenter.loading = false;
    }
  }

  static async acknowledge(noticeId: string): Promise<void> {
    if (!NoticeAlertCenter.current || NoticeAlertCenter.current.id !== noticeId) {
      return;
    }
    if (NoticeAlertCenter.seenIds.indexOf(noticeId) < 0) {
      NoticeAlertCenter.seenIds.push(noticeId);
      await NoticeAlertCenter.saveSeen(NoticeAlertCenter.currentOwner, NoticeAlertCenter.seenIds);
    }
    NoticeAlertCenter.current = undefined;
    AppStorage.setOrCreate<Notice | undefined>(STORAGE_CURRENT, undefined);
    NoticeAlertCenter.bumpVersion();
    NoticeAlertCenter.promoteIfIdle();
  }

  private static promoteIfIdle(): void {
    if (NoticeAlertCenter.current) {
      return;
    }
    if (NoticeAlertCenter.queue.length === 0) {
      return;
    }
    const next = NoticeAlertCenter.queue.shift();
    if (!next) {
      return;
    }
    NoticeAlertCenter.current = next;
    AppStorage.setOrCreate<Notice | undefined>(STORAGE_CURRENT, next);
    NoticeAlertCenter.bumpVersion();
  }

  private static bumpVersion(): void {
    const cur = AppStorage.get<number>(STORAGE_VERSION);
    const v = typeof cur === 'number' ? cur : 0;
    AppStorage.setOrCreate<number>(STORAGE_VERSION, v + 1);
  }

  private static resolveOwner(): string {
    const session = SessionStorage.get();
    const student = session.getStudent();
    if (student && student.studentId) {
      return `student:${student.studentId}`;
    }
    const admin = session.getAdmin();
    if (admin && admin.adminId) {
      return `admin:${admin.adminId}`;
    }
    return '';
  }

  private static async loadSeen(owner: string): Promise<string[]> {
    const raw = await PreferenceStorage.get().getString(PREF_PREFIX + owner, '');
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as SeenEntry;
      if (parsed && parsed.ids && parsed.ids.length > 0) {
        return parsed.ids;
      }
    } catch (e) {
      // 损坏数据：当作未读处理
    }
    return [];
  }

  private static async saveSeen(owner: string, ids: string[]): Promise<void> {
    const entry: SeenEntry = { ownerId: owner, ids: ids };
    await PreferenceStorage.get().putString(PREF_PREFIX + owner, JSON.stringify(entry));
  }
}
