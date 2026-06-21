'use strict';
// 对象存储工厂：根据 STORAGE_DRIVER 环境变量选择适配器（默认本地文件）。
//
// 适配器接口（StorageAdapter shape）：
//   put(key, buffer, contentType) -> Promise<void>
//   get(key)                      -> Promise<{ buffer: Buffer, contentType: string }>
//   exists(key)                   -> Promise<boolean>
//   remove(key)                   -> Promise<void>
//
// 默认：LocalStorageAdapter（只需 Node 内置 fs，零外部依赖，适合开发/生产单机部署）。
// S3/MinIO：设置 STORAGE_DRIVER=s3 并安装 @aws-sdk/client-s3 后自动激活。

const { LocalStorageAdapter } = require('./LocalStorageAdapter');

// 单例缓存：进程内只实例化一次（避免重复创建 S3 连接）
let _instance = null;

/**
 * 获取当前配置的存储适配器实例（单例）。
 * 默认返回 LocalStorageAdapter；当 STORAGE_DRIVER=s3 时懒加载 S3StorageAdapter。
 * @returns {LocalStorageAdapter|S3StorageAdapter}
 */
function getStorage() {
  if (_instance) {
    return _instance;
  }
  if (process.env.STORAGE_DRIVER === 's3') {
    // S3 适配器在其构造函数内懒加载 @aws-sdk/client-s3（不影响默认路径启动）
    const { S3StorageAdapter } = require('./S3StorageAdapter');
    _instance = new S3StorageAdapter();
  } else {
    _instance = new LocalStorageAdapter();
  }
  return _instance;
}

// 供测试覆写（注入 mock 适配器）
function _setStorageForTest(adapter) {
  _instance = adapter;
}

module.exports = { getStorage, _setStorageForTest };
