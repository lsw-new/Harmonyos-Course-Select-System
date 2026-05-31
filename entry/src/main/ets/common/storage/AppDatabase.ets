import { relationalStore } from '@kit.ArkData';
import common from '@ohos.app.ability.common';
import {
  DATABASE_NAME,
  DATABASE_SCHEMA_SQL,
  DATABASE_SCHEMA_VERSION_KEY,
  DATABASE_VERSION
} from './DatabaseSchema';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DATABASE_NAME,
  securityLevel: relationalStore.SecurityLevel.S2,
  encrypt: false
};

export class AppDatabase {
  private static store?: relationalStore.RdbStore;
  private static initTask?: Promise<void>;

  static async init(context: common.UIAbilityContext | common.Context): Promise<void> {
    if (AppDatabase.store) {
      return;
    }
    if (AppDatabase.initTask) {
      return AppDatabase.initTask;
    }
    AppDatabase.initTask = AppDatabase.openAndMigrate(context)
      .catch((err: Object): Promise<void> => {
        AppDatabase.initTask = undefined;
        return Promise.reject(err);
      });
    return AppDatabase.initTask;
  }

  static isReady(): boolean {
    return AppDatabase.store !== undefined;
  }

  static getStore(): relationalStore.RdbStore {
    if (!AppDatabase.store) {
      throw new Error('AppDatabase is not initialized');
    }
    return AppDatabase.store;
  }

  static async execute(sql: string): Promise<void> {
    await AppDatabase.getStore().executeSql(sql);
  }

  static async query(sql: string): Promise<relationalStore.ResultSet> {
    return AppDatabase.getStore().querySql(sql);
  }

  static sqlText(value: string): string {
    return `'${value.replace(/'/g, "''")}'`;
  }

  static sqlNullableText(value?: string): string {
    if (value === undefined) {
      return 'NULL';
    }
    return AppDatabase.sqlText(value);
  }

  private static async openAndMigrate(context: common.UIAbilityContext | common.Context): Promise<void> {
    const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await AppDatabase.applySchema(store);
    AppDatabase.store = store;
  }

  private static async applySchema(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql('PRAGMA foreign_keys = ON');
    for (let i = 0; i < DATABASE_SCHEMA_SQL.length; i++) {
      await store.executeSql(DATABASE_SCHEMA_SQL[i]);
    }
    await store.executeSql(`PRAGMA user_version = ${DATABASE_VERSION}`);
    await store.executeSql(
      `INSERT OR REPLACE INTO app_meta (key, value, updated_at) VALUES ('${DATABASE_SCHEMA_VERSION_KEY}', '${DATABASE_VERSION}', CURRENT_TIMESTAMP)`
    );
  }
}
