'use strict';
// 本地文件系统存储适配器：把上传文件存到 UPLOAD_DIR（默认 server/uploads/）。
// 这是默认适配器，无需任何外部依赖或环境变量，零配置可用。
// key 格式任意字符串（由调用方约定，通常为 "up-<uuid>"）；
// 文件在磁盘上按 key 命名（特殊字符做简单转义保证路径安全）。

const fs = require('fs');
const path = require('path');

class LocalStorageAdapter {
  /**
   * @param {string} uploadDir  存储根目录，默认取 UPLOAD_DIR 环境变量或 server/uploads/
   */
  constructor(uploadDir) {
    this.uploadDir = uploadDir || process.env.UPLOAD_DIR || path.join(__dirname, '..', '..', 'uploads');
    // 若目录不存在则同步创建（服务启动时执行一次，不影响请求性能）
    fs.mkdirSync(this.uploadDir, { recursive: true });
  }

  // 把 key 转为安全的文件名：保留字母/数字/连字符/下划线，其余替换为 '_'
  _safeName(key) {
    return String(key).replace(/[^A-Za-z0-9\-_]/g, '_');
  }

  _filePath(key) {
    return path.join(this.uploadDir, this._safeName(key));
  }

  /** 写入对象。contentType 存为 <key>.meta 的 JSON 附属文件。 */
  async put(key, buffer, contentType) {
    const filePath = this._filePath(key);
    await fs.promises.writeFile(filePath, buffer);
    await fs.promises.writeFile(filePath + '.meta', JSON.stringify({ contentType }), 'utf8');
  }

  /** 读取对象，返回 { buffer: Buffer, contentType: string } */
  async get(key) {
    const filePath = this._filePath(key);
    const buffer = await fs.promises.readFile(filePath);
    let contentType = 'application/octet-stream';
    try {
      const meta = JSON.parse(await fs.promises.readFile(filePath + '.meta', 'utf8'));
      contentType = meta.contentType || contentType;
    } catch (_) {
      // meta 缺失或损坏：回退默认 MIME
    }
    return { buffer, contentType };
  }

  /** 检查 key 是否存在 */
  async exists(key) {
    try {
      await fs.promises.access(this._filePath(key));
      return true;
    } catch (_) {
      return false;
    }
  }

  /** 删除对象（文件 + meta），key 不存在时静默 */
  async remove(key) {
    const filePath = this._filePath(key);
    await fs.promises.unlink(filePath).catch(() => {});
    await fs.promises.unlink(filePath + '.meta').catch(() => {});
  }
}

module.exports = { LocalStorageAdapter };
