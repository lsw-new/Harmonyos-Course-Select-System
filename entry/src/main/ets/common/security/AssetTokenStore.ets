// Token 安全存储 · token 的权威持久化来源。优先用 @kit.AssetStoreKit（TEE/安全硬件级）；
// 运行期不可用（仿真器/无 TEE 的低端机）时由 try/catch 自动降级到“进程内内存”兜底。
// 安全模型（P2-02 收口）：
//   - 长期 token 只存 Asset Store。SessionStorage 不再把 'session.token' 明文写入 Preferences；
//     冷启动后的登录 token 由 SessionStorage.restore()→reconcileSecureToken() 从 Asset Store 取回。
//   - Preferences 的 'fallback.token.*' 仅用于读取旧版本可能残留的明文 token，作一次性只读迁移，
//     迁移/登出后即删（见 secureRemove），杜绝 token 长期明文落盘（备份/取证风险）。
//   - 降级到内存后不落盘：同一进程内 set/get 一致，但冷启动内存清空 → 需重新登录（安全优先于便利）。
// 说明：Asset Kit 分支按官方文档 Map 式 API 编写并通过构建校验，但本环境无法真机验证其运行路径。

import util from '@ohos.util';
import { asset } from '@kit.AssetStoreKit';
import { PreferenceStorage } from '../storage/PreferenceStorage';

// ---- Alias / Key 常量 --------------------------------------------------------
const ASSET_ALIAS_STUDENT = 'edu_token_student';
const ASSET_ALIAS_ADMIN = 'edu_token_admin';
// 旧版本可能把 token 明文写过的 Preferences 键；现仅用于 clear() 时清理历史残留，不再写入。
const PREF_KEY_STUDENT = 'fallback.token.student';
const PREF_KEY_ADMIN = 'fallback.token.admin';

// ---- Asset Kit 能力缓存标志 --------------------------------------------------
// undefined = 尚未检测；true = 可用；false = 不可用
let assetAvailable: boolean | undefined = undefined;

// ---- 进程内内存兜底 ----------------------------------------------------------
// Asset Kit 不可用时的降级存储：仅存活于当前进程，不落盘，避免长期明文暴露。
const memoryFallback: Map<string, string> = new Map();

// ---- 辅助：string <-> bytes --------------------------------------------------

function strToBytes(text: string): Uint8Array {
  const encoder = new util.TextEncoder();
  return encoder.encodeInto(text);
}

function bytesToStr(bytes: Uint8Array): string {
  const decoder = new util.TextDecoder();
  return decoder.decodeWithStream(bytes);
}

// ---- Asset Kit 调用封装（官方 Map 式 API） -----------------------------------

async function assetSet(alias: string, token: string): Promise<void> {
  // 先删旧条目，避免 duplicate alias 错误
  try {
    const del: asset.AssetMap = new Map();
    del.set(asset.Tag.ALIAS, strToBytes(alias));
    await asset.remove(del);
  } catch (e) {
    // 不存在则忽略
  }
  const attr: asset.AssetMap = new Map();
  attr.set(asset.Tag.ALIAS, strToBytes(alias));
  attr.set(asset.Tag.SECRET, strToBytes(token));
  attr.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
  await asset.add(attr);
}

async function assetGet(alias: string): Promise<string | undefined> {
  const query: asset.AssetMap = new Map();
  query.set(asset.Tag.ALIAS, strToBytes(alias));
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
  const results: Array<asset.AssetMap> = await asset.query(query);
  if (!results || results.length === 0) {
    return undefined;
  }
  const secret = results[0].get(asset.Tag.SECRET);
  if (secret instanceof Uint8Array) {
    return bytesToStr(secret);
  }
  return undefined;
}

async function assetRemove(alias: string): Promise<void> {
  try {
    const del: asset.AssetMap = new Map();
    del.set(asset.Tag.ALIAS, strToBytes(alias));
    await asset.remove(del);
  } catch (e) {
    // 不存在则忽略
  }
}

// ---- 降级逻辑 ---------------------------------------------------------------

async function secureSet(alias: string, token: string, prefKey: string): Promise<void> {
  if (assetAvailable === false) {
    // 降级：仅写进程内存，不落盘（避免长期明文暴露）
    memoryFallback.set(prefKey, token);
    return;
  }
  try {
    await assetSet(alias, token);
    assetAvailable = true;
  } catch (e) {
    assetAvailable = false;
    // 降级：仅写进程内存，不落盘
    memoryFallback.set(prefKey, token);
  }
}

async function secureGet(alias: string, prefKey: string): Promise<string | undefined> {
  if (assetAvailable === false) {
    return readFallback(prefKey);
  }
  try {
    const val = await assetGet(alias);
    assetAvailable = true;
    if (val !== undefined && val.length > 0) {
      return val;
    }
    // Asset 无此条目，从兜底读取（含旧版本明文残留的一次性迁移）
    return readFallback(prefKey);
  } catch (e) {
    assetAvailable = false;
    return readFallback(prefKey);
  }
}

// 兜底读取顺序：进程内存优先；其次读旧版本可能残留的 Preferences 明文（只读迁移，不回写）。
async function readFallback(prefKey: string): Promise<string | undefined> {
  const mem = memoryFallback.get(prefKey);
  if (mem !== undefined && mem.length > 0) {
    return mem;
  }
  const legacy = await PreferenceStorage.get().getString(prefKey, '');
  return legacy.length > 0 ? legacy : undefined;
}

async function secureRemove(alias: string, prefKey: string): Promise<void> {
  // 进程内存兜底清除
  memoryFallback.delete(prefKey);
  // 一并清除旧版本可能残留的 Preferences 明文 token
  await PreferenceStorage.get().remove(prefKey);
  if (assetAvailable === false) {
    return;
  }
  try {
    await assetRemove(alias);
  } catch (e) {
    // 忽略
  }
}

// ---- 公开 API ---------------------------------------------------------------

export class AssetTokenStore {
  // 保存学生端 token（权威存安全存储；Asset 不可用时降级到进程内存，不落盘）。
  static async setStudentToken(token: string): Promise<void> {
    await secureSet(ASSET_ALIAS_STUDENT, token, PREF_KEY_STUDENT);
  }

  // 读取学生端 token。
  static async getStudentToken(): Promise<string | undefined> {
    return secureGet(ASSET_ALIAS_STUDENT, PREF_KEY_STUDENT);
  }

  // 保存管理员端 token（权威存安全存储；Asset 不可用时降级到进程内存，不落盘）。
  static async setAdminToken(token: string): Promise<void> {
    await secureSet(ASSET_ALIAS_ADMIN, token, PREF_KEY_ADMIN);
  }

  // 读取管理员端 token。
  static async getAdminToken(): Promise<string | undefined> {
    return secureGet(ASSET_ALIAS_ADMIN, PREF_KEY_ADMIN);
  }

  // 清除所有 token（登出时调用）。
  static async clear(): Promise<void> {
    await secureRemove(ASSET_ALIAS_STUDENT, PREF_KEY_STUDENT);
    await secureRemove(ASSET_ALIAS_ADMIN, PREF_KEY_ADMIN);
  }
}
