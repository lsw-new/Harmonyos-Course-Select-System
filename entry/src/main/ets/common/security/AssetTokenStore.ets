// Token 安全存储 · 优先用 @kit.AssetStoreKit（TEE/安全硬件级），不可用时降级 PreferenceStorage。
// Asset Store Kit 在运行期不可用（仿真器/低版本）时由 try/catch 自动回退，不退步于改造前的行为。
// 说明：Asset Kit 分支按官方文档 Map 式 API 编写并通过构建校验，但本环境无法真机验证其运行路径。

import util from '@ohos.util';
import { asset } from '@kit.AssetStoreKit';
import { PreferenceStorage } from '../storage/PreferenceStorage';

// ---- Alias / Key 常量 --------------------------------------------------------
const ASSET_ALIAS_STUDENT = 'edu_token_student';
const ASSET_ALIAS_ADMIN = 'edu_token_admin';
const PREF_KEY_STUDENT = 'fallback.token.student';
const PREF_KEY_ADMIN = 'fallback.token.admin';

// ---- Asset Kit 能力缓存标志 --------------------------------------------------
// undefined = 尚未检测；true = 可用；false = 不可用
let assetAvailable: boolean | undefined = undefined;

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
    await PreferenceStorage.get().putString(prefKey, token);
    return;
  }
  try {
    await assetSet(alias, token);
    assetAvailable = true;
  } catch (e) {
    assetAvailable = false;
    // 降级：写 Preferences（与改造前行为一致）
    await PreferenceStorage.get().putString(prefKey, token);
  }
}

async function secureGet(alias: string, prefKey: string): Promise<string | undefined> {
  if (assetAvailable === false) {
    const val = await PreferenceStorage.get().getString(prefKey, '');
    return val.length > 0 ? val : undefined;
  }
  try {
    const val = await assetGet(alias);
    assetAvailable = true;
    if (val !== undefined && val.length > 0) {
      return val;
    }
    // Asset 无此条目，从 Preferences 读取（升级迁移场景）
    const fallback = await PreferenceStorage.get().getString(prefKey, '');
    return fallback.length > 0 ? fallback : undefined;
  } catch (e) {
    assetAvailable = false;
    const val = await PreferenceStorage.get().getString(prefKey, '');
    return val.length > 0 ? val : undefined;
  }
}

async function secureRemove(alias: string, prefKey: string): Promise<void> {
  // Preferences 侧无论如何清除
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
  // 保存学生端 token（安全存储，降级到 Preferences）。
  static async setStudentToken(token: string): Promise<void> {
    await secureSet(ASSET_ALIAS_STUDENT, token, PREF_KEY_STUDENT);
  }

  // 读取学生端 token。
  static async getStudentToken(): Promise<string | undefined> {
    return secureGet(ASSET_ALIAS_STUDENT, PREF_KEY_STUDENT);
  }

  // 保存管理员端 token（安全存储，降级到 Preferences）。
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
