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
    const previousVersion = await AppDatabase.readUserVersion(store);
    for (let i = 0; i < DATABASE_SCHEMA_SQL.length; i++) {
      await store.executeSql(DATABASE_SCHEMA_SQL[i]);
    }
    await AppDatabase.migrateSchema(store, previousVersion);
    await store.executeSql(`PRAGMA user_version = ${DATABASE_VERSION}`);
    await store.executeSql(
      `INSERT OR REPLACE INTO app_meta (key, value, updated_at) VALUES ('${DATABASE_SCHEMA_VERSION_KEY}', '${DATABASE_VERSION}', CURRENT_TIMESTAMP)`
    );
  }

  private static async readUserVersion(store: relationalStore.RdbStore): Promise<number> {
    const resultSet = await store.querySql('PRAGMA user_version');
    try {
      if (resultSet.goToNextRow()) {
        return resultSet.getLong(0);
      }
      return 0;
    } finally {
      resultSet.close();
    }
  }

  // 旧库升级：v1 的 courses 表补充 selected_count / time_text 列。
  // 全新库（previousVersion=0）由 CREATE TABLE 直接建好这两列，无需迁移。
  private static async migrateSchema(store: relationalStore.RdbStore, previousVersion: number): Promise<void> {
    if (previousVersion >= 1 && previousVersion < 2) {
      await AppDatabase.addColumnIfMissing(store, 'courses', 'selected_count', 'INTEGER NOT NULL DEFAULT 0');
      await AppDatabase.addColumnIfMissing(store, 'courses', 'time_text', 'TEXT');
    }
  }

  private static async addColumnIfMissing(
    store: relationalStore.RdbStore,
    table: string,
    column: string,
    declaration: string
  ): Promise<void> {
    const resultSet = await store.querySql(`PRAGMA table_info(${table})`);
    let exists = false;
    try {
      const nameIndex = resultSet.getColumnIndex('name');
      while (resultSet.goToNextRow()) {
        if (resultSet.getString(nameIndex) === column) {
          exists = true;
          break;
        }
      }
    } finally {
      resultSet.close();
    }
    if (!exists) {
      await store.executeSql(`ALTER TABLE ${table} ADD COLUMN ${column} ${declaration}`);
    }
  }
}
