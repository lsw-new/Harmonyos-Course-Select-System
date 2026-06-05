// AccountStore · 账号密码持久层
// 优先走 RDB accounts 表；未就绪时回退到 Preferences（内存 KV）。
// 密码哈希方案：SHA-256(salt + ":" + SHA-256(password))
// 盐值 = 16 字节随机，hex 编码（32 字符）。

import util from '@ohos.util';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppDatabase } from './AppDatabase';
import { PreferenceStorage } from './PreferenceStorage';
import { TEST_STUDENT_ID, TEST_STUDENT_PASSWORD } from '../../mock/mockUser';
import { TEST_ADMIN_ID, TEST_ADMIN_PASSWORD } from '../../mock/mockAdmin';

// ---- Preferences Key 前缀 ---------------------------------------------------
const PREF_PREFIX = 'account.store.';
const PREF_SEEDED_KEY = 'account.store.seeded';

// ---- 账号记录结构 ------------------------------------------------------------
interface AccountRecord {
  accountId: string;
  role: string;
  passwordHash: string;
  salt: string;
  status: string;
}

// ---- SHA-256 辅助 ------------------------------------------------------------

async function sha256Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA256');
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(input);
  const dataBlob: cryptoFramework.DataBlob = { data: data };
  await md.update(dataBlob);
  const digest: cryptoFramework.DataBlob = await md.digest();
  return bytesToHex(digest.data);
}

function bytesToHex(bytes: Uint8Array): string {
  const parts: string[] = [];
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i] & 0xff;
    const h = b.toString(16);
    parts.push(h.length === 1 ? ('0' + h) : h);
  }
  return parts.join('');
}

function generateSalt(): string {
  // 优先用 cryptoFramework 生成随机盐（16 字节）
  try {
    const rand = cryptoFramework.createRandom();
    const blob = rand.generateRandomSync(16);
    return bytesToHex(blob.data);
  } catch (_e) {
    // 降级：Math.random（仅用于盐生成，安全性足够）
    const fallback = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      fallback[i] = Math.floor(Math.random() * 256);
    }
    return bytesToHex(fallback);
  }
}

/**
 * 计算密码存储哈希：
 *   step1 = SHA256(password)
 *   result = SHA256(salt + ":" + step1)
 */
async function hashPassword(password: string, salt: string): Promise<string> {
  const step1 = await sha256Hex(password);
  return sha256Hex(salt + ':' + step1);
}

// ---- 种子化状态标志（内存级，避免重复写入） ----------------------------------
let seedDone = false;

// ---- AccountStore 主体 -------------------------------------------------------

export class AccountStore {
  /**
   * 确保 mock 测试账号已写入持久层（幂等）。
   * 在首次 verifyPassword / changePassword / resetPassword 前自动调用。
   */
  static async ensureSeeded(): Promise<void> {
    if (seedDone) {
      return;
    }

    // 检查跨会话持久化标记
    const seededFlag = await PreferenceStorage.get().getString(PREF_SEEDED_KEY, '');
    if (seededFlag === 'yes') {
      seedDone = true;
      return;
    }

    // 检查数据库或 Preferences 中是否已有学生账号
    if (AppDatabase.isReady()) {
      const exists = await AccountStore.rdbExists(TEST_STUDENT_ID);
      if (exists) {
        seedDone = true;
        await PreferenceStorage.get().putString(PREF_SEEDED_KEY, 'yes');
        return;
      }
    } else {
      const raw = await PreferenceStorage.get().getString(PREF_PREFIX + TEST_STUDENT_ID, '');
      if (raw.length > 0) {
        seedDone = true;
        await PreferenceStorage.get().putString(PREF_SEEDED_KEY, 'yes');
        return;
      }
    }

    // 首次运行：种子化测试账号
    await AccountStore.seedOneAccount(TEST_STUDENT_ID, 'student', TEST_STUDENT_PASSWORD);
    await AccountStore.seedOneAccount(TEST_ADMIN_ID, 'admin', TEST_ADMIN_PASSWORD);

    await PreferenceStorage.get().putString(PREF_SEEDED_KEY, 'yes');
    seedDone = true;
  }

  private static async seedOneAccount(accountId: string, role: string, password: string): Promise<void> {
    const salt = generateSalt();
    const passwordHash = await hashPassword(password, salt);
    const record: AccountRecord = {
      accountId: accountId,
      role: role,
      passwordHash: passwordHash,
      salt: salt,
      status: 'active'
    };
    await AccountStore.saveRecord(record);
  }

  /**
   * 校验密码是否正确。
   * 返回 true = 通过；false = 密码错误或账号不存在。
   */
  static async verifyPassword(accountId: string, password: string): Promise<boolean> {
    await AccountStore.ensureSeeded();
    const record = await AccountStore.loadRecord(accountId);
    if (!record) {
      return false;
    }
    if (record.status !== 'active') {
      return false;
    }
    const computed = await hashPassword(password, record.salt);
    return computed === record.passwordHash;
  }

  /**
   * 修改密码（已在调用方完成旧密码校验）。
   * 生成新盐 + 新哈希并持久化。
   */
  static async changePassword(accountId: string, newPassword: string): Promise<void> {
    await AccountStore.ensureSeeded();
    const record = await AccountStore.loadRecord(accountId);
    if (!record) {
      throw new Error('账号不存在');
    }
    const salt = generateSalt();
    const passwordHash = await hashPassword(newPassword, salt);
    const updated: AccountRecord = {
      accountId: record.accountId,
      role: record.role,
      passwordHash: passwordHash,
      salt: salt,
      status: record.status
    };
    await AccountStore.saveRecord(updated);
  }

  /**
   * 重置密码（找回密码流程，无需旧密码）。
   * P1-02：账号不存在直接抛错，不再自动建号（堵掉「找回密码可建任意账号」）。
   */
  static async resetPassword(accountId: string, newPassword: string): Promise<void> {
    await AccountStore.ensureSeeded();
    const record = await AccountStore.loadRecord(accountId);
    if (!record) {
      throw new Error('账号不存在，无法重置密码');
    }
    const salt = generateSalt();
    const passwordHash = await hashPassword(newPassword, salt);
    const updated: AccountRecord = {
      accountId: record.accountId,
      role: record.role,
      passwordHash: passwordHash,
      salt: salt,
      status: 'active'
    };
    await AccountStore.saveRecord(updated);
  }

  /**
   * 创建账号（注册流程）。
   * P1-01：账号已存在则抛错；否则写入新账号（默认 active）。
   */
  static async createAccount(accountId: string, role: string, password: string): Promise<void> {
    await AccountStore.ensureSeeded();
    const existing = await AccountStore.loadRecord(accountId);
    if (existing) {
      throw new Error('该账号已存在');
    }
    const salt = generateSalt();
    const passwordHash = await hashPassword(password, salt);
    const record: AccountRecord = {
      accountId: accountId,
      role: role,
      passwordHash: passwordHash,
      salt: salt,
      status: 'active'
    };
    await AccountStore.saveRecord(record);
  }

  // ---- 底层 IO：统一入口 -------------------------------------------------------

  private static async loadRecord(accountId: string): Promise<AccountRecord | undefined> {
    if (AppDatabase.isReady()) {
      return AccountStore.rdbLoad(accountId);
    }
    return AccountStore.prefLoad(accountId);
  }

  private static async saveRecord(record: AccountRecord): Promise<void> {
    if (AppDatabase.isReady()) {
      await AccountStore.rdbSave(record);
    }
    // 同时写 Preferences（降级副本 + 快速读取）
    await AccountStore.prefSave(record);
  }

  // ---- RDB 操作 ---------------------------------------------------------------

  private static async rdbExists(accountId: string): Promise<boolean> {
    const sql =
      `SELECT account_id FROM accounts WHERE account_id = ${AppDatabase.sqlText(accountId)} LIMIT 1`;
    const rs = await AppDatabase.query(sql);
    try {
      return rs.goToNextRow();
    } finally {
      rs.close();
    }
  }

  private static async rdbLoad(accountId: string): Promise<AccountRecord | undefined> {
    const sql =
      `SELECT account_id, role, password_hash, salt, status FROM accounts WHERE account_id = ${AppDatabase.sqlText(accountId)} LIMIT 1`;
    const rs = await AppDatabase.query(sql);
    try {
      if (!rs.goToNextRow()) {
        return undefined;
      }
      const record: AccountRecord = {
        accountId: rs.getString(rs.getColumnIndex('account_id')),
        role: rs.getString(rs.getColumnIndex('role')),
        passwordHash: rs.getString(rs.getColumnIndex('password_hash')),
        salt: rs.getString(rs.getColumnIndex('salt')),
        status: rs.getString(rs.getColumnIndex('status'))
      };
      return record;
    } finally {
      rs.close();
    }
  }

  private static async rdbSave(record: AccountRecord): Promise<void> {
    const sql =
      `INSERT OR REPLACE INTO accounts (account_id, role, password_hash, salt, status, updated_at) VALUES (` +
      `${AppDatabase.sqlText(record.accountId)}, ` +
      `${AppDatabase.sqlText(record.role)}, ` +
      `${AppDatabase.sqlText(record.passwordHash)}, ` +
      `${AppDatabase.sqlText(record.salt)}, ` +
      `${AppDatabase.sqlText(record.status)}, ` +
      `CURRENT_TIMESTAMP)`;
    await AppDatabase.execute(sql);
  }

  // ---- Preferences 操作 -------------------------------------------------------

  private static async prefLoad(accountId: string): Promise<AccountRecord | undefined> {
    const raw = await PreferenceStorage.get().getString(PREF_PREFIX + accountId, '');
    if (raw.length === 0) {
      return undefined;
    }
    try {
      const parsed = JSON.parse(raw) as AccountRecord;
      if (!parsed || typeof parsed.passwordHash !== 'string') {
        return undefined;
      }
      return parsed;
    } catch (_e) {
      return undefined;
    }
  }

  private static async prefSave(record: AccountRecord): Promise<void> {
    await PreferenceStorage.get().putString(PREF_PREFIX + record.accountId, JSON.stringify(record));
  }
}
