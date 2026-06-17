// 缓存管理：读取/清理应用沙箱 cacheDir + tempDir。
// 设置页「清除缓存」走真实文件系统：扫描显示真实占用，清理返回释放字节。

import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

export class CacheManager {
  private static context?: common.Context;

  static configure(context: common.UIAbilityContext | common.Context): void {
    CacheManager.context = context;
  }

  // 扫描 cacheDir + tempDir 总占用字节数（递归子目录）。
  static async getSizeBytes(): Promise<number> {
    const ctx = CacheManager.context;
    if (!ctx) {
      return 0;
    }
    const dirs: string[] = [ctx.cacheDir, ctx.tempDir];
    let total = 0;
    for (let i = 0; i < dirs.length; i++) {
      total += await CacheManager.dirSize(dirs[i]);
    }
    return total;
  }

  // 清空 cacheDir + tempDir 内容（保留目录本身），返回清理前的字节数。
  static async clear(): Promise<number> {
    const ctx = CacheManager.context;
    if (!ctx) {
      return 0;
    }
    const before = await CacheManager.getSizeBytes();
    const dirs: string[] = [ctx.cacheDir, ctx.tempDir];
    for (let i = 0; i < dirs.length; i++) {
      await CacheManager.cleanDir(dirs[i]);
    }
    // 真实释放量 = 清理前 − 清理后（被占用/受限文件可能残留，避免虚报）
    const after = await CacheManager.getSizeBytes();
    const freed = before - after;
    return freed > 0 ? freed : 0;
  }

  private static async dirSize(path: string): Promise<number> {
    if (!path || path.length === 0) {
      return 0;
    }
    let stat: fs.Stat | undefined = undefined;
    try {
      stat = await fs.stat(path);
    } catch (e) {
      return 0;
    }
    if (!stat.isDirectory()) {
      return stat.size;
    }
    let total = 0;
    let entries: string[] = [];
    try {
      entries = await fs.listFile(path);
    } catch (e) {
      return 0;
    }
    for (let i = 0; i < entries.length; i++) {
      const child = `${path}/${entries[i]}`;
      try {
        const st = await fs.stat(child);
        if (st.isDirectory()) {
          total += await CacheManager.dirSize(child);
        } else {
          total += st.size;
        }
      } catch (e) {
        // 单个条目读取失败跳过，不阻断整体统计
      }
    }
    return total;
  }

  private static async cleanDir(path: string): Promise<void> {
    if (!path || path.length === 0) {
      return;
    }
    // 直接用 listFile 探目录（与 dirSize 同款），不依赖 fs.access 的返回语义——
    // 此前 `exists = await fs.access(path)` 若拿到非 boolean 会误判为空、提前 return，
    // 导致一个文件都不删，却仍上报清理前的字节数（清了个寂寞）。
    let entries: string[] = [];
    try {
      entries = await fs.listFile(path);
    } catch (e) {
      // 目录不存在 / 不可读：无可清理
      return;
    }
    for (let i = 0; i < entries.length; i++) {
      const child = `${path}/${entries[i]}`;
      try {
        const st = await fs.stat(child);
        if (st.isDirectory()) {
          await CacheManager.cleanDir(child);
          try {
            await fs.rmdir(child);
          } catch (e) {
            // 目录非空或权限受限则跳过
          }
        } else {
          try {
            await fs.unlink(child);
          } catch (e) {
            // 被占用文件跳过
          }
        }
      } catch (e) {
        // 单条失败不阻断整体
      }
    }
  }

  // 统一人类可读格式化（B/KB/MB/GB）。
  static formatBytes(bytes: number): string {
    if (bytes <= 0) {
      return '0 B';
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB'];
    let v = bytes;
    let i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v = v / 1024;
      i += 1;
    }
    if (i === 0) {
      return `${Math.round(v)} ${units[i]}`;
    }
    return `${(Math.round(v * 10) / 10).toFixed(1)} ${units[i]}`;
  }
}
