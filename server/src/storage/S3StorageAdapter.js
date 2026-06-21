'use strict';
// S3/MinIO 兼容存储适配器。
//
// 启用方式：设置 STORAGE_DRIVER=s3，并提供以下环境变量：
//   S3_ENDPOINT   — 端点 URL，如 https://s3.amazonaws.com 或 http://minio:9000
//   S3_BUCKET     — 存储桶名称
//   S3_ACCESS_KEY — Access Key / Access Key ID
//   S3_SECRET_KEY — Secret Key
//   S3_REGION     — 区域，如 us-east-1（MinIO 可设 us-east-1）
//
// 上线 S3/MinIO 前还需安装 SDK：
//   npm i @aws-sdk/client-s3
//
// ⚠️  @aws-sdk/client-s3 未在 package.json 中声明。
//     本适配器只在 STORAGE_DRIVER=s3 时才被实例化，SDK 在构造函数内懒加载，
//     默认（本地文件）路径永远不会 require 它，不会影响默认启动。

class S3StorageAdapter {
  constructor() {
    // 懒加载 SDK（仅 s3 模式会到达此处）
    let S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand, HeadObjectCommand;
    try {
      // eslint-disable-next-line
      ({ S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand, HeadObjectCommand } =
        require('@aws-sdk/client-s3'));
    } catch (e) {
      throw new Error(
        '[storage] STORAGE_DRIVER=s3 已配置，但 @aws-sdk/client-s3 未安装。' +
        '请先在 server/ 目录下执行：npm i @aws-sdk/client-s3'
      );
    }
    this.bucket = process.env.S3_BUCKET;
    if (!this.bucket) {
      throw new Error('[storage] STORAGE_DRIVER=s3 时必须设置 S3_BUCKET 环境变量');
    }
    this.s3 = new S3Client({
      endpoint: process.env.S3_ENDPOINT,
      region: process.env.S3_REGION || 'us-east-1',
      credentials: {
        accessKeyId: process.env.S3_ACCESS_KEY || '',
        secretAccessKey: process.env.S3_SECRET_KEY || ''
      },
      // MinIO 等自托管需要 path-style URL
      forcePathStyle: !!process.env.S3_ENDPOINT
    });
    this._PutObjectCommand = PutObjectCommand;
    this._GetObjectCommand = GetObjectCommand;
    this._DeleteObjectCommand = DeleteObjectCommand;
    this._HeadObjectCommand = HeadObjectCommand;
  }

  async put(key, buffer, contentType) {
    await this.s3.send(new this._PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType
    }));
  }

  async get(key) {
    const resp = await this.s3.send(new this._GetObjectCommand({
      Bucket: this.bucket,
      Key: key
    }));
    // SDK v3：resp.Body 是 ReadableStream（Node.js）
    const chunks = [];
    for await (const chunk of resp.Body) {
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks);
    return { buffer, contentType: resp.ContentType || 'application/octet-stream' };
  }

  async exists(key) {
    try {
      await this.s3.send(new this._HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch (e) {
      if (e && (e.$metadata?.httpStatusCode === 404 || e.name === 'NotFound')) {
        return false;
      }
      throw e;
    }
  }

  async remove(key) {
    await this.s3.send(new this._DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}

module.exports = { S3StorageAdapter };
