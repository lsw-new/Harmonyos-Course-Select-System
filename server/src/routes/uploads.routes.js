'use strict';
// 对象存储上传/下载路由（roadmap #9）。
//
// POST /api/uploads — 学生上传图片，JSON body { filename, contentType, dataBase64 }。
//   - 身份从 JWT 取（防 IDOR），不信任 body 传入的 ownerId。
//   - 仅允许 image/* 内容类型白名单，解码后体积 ≤ 2MB。
//   - 本路由挂载自己的 express.json({limit:'3mb'})，不改全局限制（全局为 300kb，满足普通接口）。
//   - 返回 { uploadId, url, size }。
//
// GET /api/uploads/:id — 按不可猜测的 uploadId 查元数据并流式返回文件字节。
//   - 读取开放（public-by-id）：<img src> 无需附带 Authorization 头即可渲染。
//   - 安全性依赖 uploadId 的不可猜测性（crypto.randomUUID → UUID v4）。
//   - 若需严格保密图片可改为 authRequired，但会导致 <img src> 无法自动携带 token。

const express = require('express');
const { pool } = require('../db');
const { ok, fail } = require('../envelope');
const { authRequired } = require('../auth');
const { serverError } = require('../middleware/errorHandler');
const { currentStudentId } = require('../identity');
const { genId } = require('../ids');
const { getStorage } = require('../storage');

const router = express.Router();

// 上传路由使用更宽松的 JSON 限制（3mb 足以容纳 2MB 的 base64 + 头部开销）。
// 注意：仅对本路由生效，不改全局 300kb 限制。
const jsonLarge = express.json({ limit: '3mb' });

// 允许的图片 content-type 白名单
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
// 解码后体积上限：2MB
const MAX_BYTES = 2 * 1024 * 1024;

// 去掉 data URL 前缀（如 data:image/jpeg;base64,），返回纯 base64 字符串和 contentType。
// 若无前缀则按原文返回，contentType 由调用方提供。
function stripDataUrl(raw, fallbackContentType) {
  const m = raw.match(/^data:([^;]+);base64,(.+)$/s);
  if (m) {
    return { contentType: m[1], base64: m[2] };
  }
  return { contentType: fallbackContentType, base64: raw };
}

// ---- 上传图片（需登录，学生身份） ----
router.post('/api/uploads', jsonLarge, authRequired, async (req, res) => {
  const ownerId = currentStudentId(req);
  if (!ownerId) {
    return res.status(403).json(fail('需要学生登录'));
  }

  const b = req.body || {};
  const rawBase64 = typeof b.dataBase64 === 'string' ? b.dataBase64 : '';
  const rawFilename = typeof b.filename === 'string' ? b.filename.trim() : '';
  const rawContentType = typeof b.contentType === 'string' ? b.contentType.trim().toLowerCase() : '';

  if (!rawBase64) {
    return res.status(400).json(fail('缺少 dataBase64'));
  }
  if (!rawFilename) {
    return res.status(400).json(fail('缺少 filename'));
  }

  // 剥离 data URL 前缀（App 端可能把完整 data URL 直接传过来）
  const { contentType, base64 } = stripDataUrl(rawBase64, rawContentType);

  // 内容类型白名单
  if (!ALLOWED_TYPES.has(contentType)) {
    return res.status(400).json(fail(`不支持的图片类型：${contentType}，允许 jpeg/png/webp/gif`));
  }

  // 解码并检查大小
  let buffer;
  try {
    buffer = Buffer.from(base64, 'base64');
  } catch (e) {
    return res.status(400).json(fail('base64 数据无效'));
  }
  if (buffer.length > MAX_BYTES) {
    return res.status(400).json(fail(`图片过大（${buffer.length} 字节），上限 2MB`));
  }
  if (buffer.length === 0) {
    return res.status(400).json(fail('图片数据为空'));
  }

  const uploadId = genId('up');
  const storageKey = uploadId; // 本地适配器直接用 uploadId 作文件名；S3 可加前缀

  try {
    // 写对象到存储后端
    await getStorage().put(storageKey, buffer, contentType);

    // 写元数据到 DB
    await pool.query(
      `INSERT INTO dtest2.uploads (upload_id, owner_id, kind, filename, content_type, size_bytes, storage_key)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [uploadId, ownerId, 'image', rawFilename, contentType, buffer.length, storageKey]
    );

    res.json(ok({ uploadId, url: `/api/uploads/${uploadId}`, size: buffer.length }));
  } catch (e) {
    serverError(res, '上传失败', e);
  }
});

// ---- 下载/渲染图片（公开，按不可猜测的 uploadId 访问）----
// 选择 public-by-id：uploadId = UUID v4（122 位随机性），不可枚举；
// 公开读取使 <img src="/api/uploads/:id"> 无需前端在请求头携带 token，
// 头像/反馈截图等可直接在 HTML/ArkUI Image 控件中渲染。
// 若业务需要严格私密，将此路由改为 authRequired 并在前端使用 Blob URL。
router.get('/api/uploads/:id', async (req, res) => {
  const uploadId = req.params.id;
  try {
    const r = await pool.query(
      'SELECT storage_key, content_type FROM dtest2.uploads WHERE upload_id = $1',
      [uploadId]
    );
    if (r.rowCount === 0) {
      return res.status(404).json(fail('资源不存在'));
    }
    const { storage_key: storageKey, content_type: contentType } = r.rows[0];
    const { buffer } = await getStorage().get(storageKey);
    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Length', buffer.length);
    // 长缓存：uploadId 不可变，内容固定，1 年强缓存
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.end(buffer);
  } catch (e) {
    serverError(res, '读取资源失败', e);
  }
});

module.exports = router;
