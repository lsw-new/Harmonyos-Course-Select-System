// 对象存储上传/下载域测试（roadmap #9）
// 覆盖：上传成功 happy-path、体积超限、类型不合法、IDOR owner 收口（取 JWT 非 body）、GET 下载。
// storage 层注入内存 mock 适配器，DB 层用 dbMock（无真实 I/O）。

jest.mock('../src/db', () => require('./helpers/dbMock'));

// 在 require app 之前注入内存 storage 适配器（避免本地 fs 实际写磁盘）
const { _setStorageForTest } = require('../src/storage');

// 简单的内存存储适配器（测试专用）
const _store = new Map(); // key -> { buffer, contentType }
const memAdapter = {
  put: async (key, buffer, contentType) => { _store.set(key, { buffer, contentType }); },
  get: async (key) => {
    if (!_store.has(key)) throw Object.assign(new Error('not found'), { code: 'ENOENT' });
    return _store.get(key);
  },
  exists: async (key) => _store.has(key),
  remove: async (key) => { _store.delete(key); }
};
_setStorageForTest(memAdapter);

const request = require('supertest');
const app = require('../src/index');
const { __mock } = require('./helpers/dbMock');
const { signToken } = require('../src/auth');

const stu = `Bearer ${signToken({ sub: '2023307020941', role: 'student' })}`;
const stu2 = `Bearer ${signToken({ sub: '2023307099999', role: 'student' })}`;

// 1x1 白色 JPEG（最小有效 JPEG，用于测试）
const TINY_JPEG_B64 =
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8U' +
  'HRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgN' +
  'DRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy' +
  'MjL/wAARCAABAAEDASIAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAABgUE/8QAHhAAAQQD' +
  'AQEAAAAAAAAAAAAAAQACAxESBCH/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/a' +
  'AAwDAQACEQMRAD8Amk2oqK1gLJMf4FBER//Z';

// 有效的小 PNG（1x1 红色像素）
const TINY_PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==';

beforeEach(() => {
  __mock.reset();
  _store.clear();
});

// ============================================================
// POST /api/uploads
// ============================================================
describe('POST /api/uploads', () => {
  test('未授权 → 401', async () => {
    const res = await request(app).post('/api/uploads').send({
      filename: 'a.jpg', contentType: 'image/jpeg', dataBase64: TINY_JPEG_B64
    });
    expect(res.status).toBe(401);
  });

  test('上传 PNG → 200，返回 uploadId / url / size', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.uploads/, result: [] }
    ]);
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'avatar.png', contentType: 'image/png', dataBase64: TINY_PNG_B64 });
    expect(res.status).toBe(200);
    expect(res.body.data.uploadId).toMatch(/^up-/);
    expect(res.body.data.url).toBe(`/api/uploads/${res.body.data.uploadId}`);
    expect(res.body.data.size).toBeGreaterThan(0);
    // storage 应有该对象
    expect(_store.has(res.body.data.uploadId)).toBe(true);
  });

  test('data URL 前缀自动剥离（contentType 从前缀提取）', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.uploads/, result: [] }
    ]);
    const dataUrl = `data:image/jpeg;base64,${TINY_JPEG_B64}`;
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'photo.jpg', contentType: 'image/jpeg', dataBase64: dataUrl });
    expect(res.status).toBe(200);
    expect(res.body.data.uploadId).toMatch(/^up-/);
  });

  test('不支持的 content-type → 400', async () => {
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'file.pdf', contentType: 'application/pdf', dataBase64: TINY_PNG_B64 });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/不支持/);
  });

  test('超过 2MB → 413 或 400（体积超限被拒）', async () => {
    // 生成约 2.1MB 的 buffer 并 base64 编码（base64 后约 2.8MB JSON body）。
    // 路由挂载 express.json({limit:'3mb'}) 处理 ≤3MB；但 decoded buffer > 2MB 时
    // 路由内逻辑返回 400。若 JSON body 本身超过 3mb，Express 提前返回 413。
    // 两种状态码（413/400）都是"请求体过大被拒绝"的正确行为。
    const bigBuffer = Buffer.alloc(2.1 * 1024 * 1024, 0xff);
    const bigB64 = bigBuffer.toString('base64');
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'big.jpg', contentType: 'image/jpeg', dataBase64: bigB64 });
    // base64 后 body ≈ 2.8MB < 3MB 限制 → 进入路由逻辑 → 400（decoded > 2MB）
    expect([400, 413]).toContain(res.status);
  });

  test('缺少 dataBase64 → 400', async () => {
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'a.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/dataBase64/);
  });

  test('缺少 filename → 400', async () => {
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ contentType: 'image/jpeg', dataBase64: TINY_PNG_B64 });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/filename/);
  });

  test('IDOR 防护：owner_id 取自 JWT 而非 body', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.uploads/, result: [] }
    ]);
    // 即使 body 里传了别人的 ownerId 字段，实际落库的 owner_id 应是 JWT sub
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'av.png', contentType: 'image/png', dataBase64: TINY_PNG_B64, ownerId: 'hacker-id' });
    expect(res.status).toBe(200);
    // 检查 DB 写入参数：params[1] 应是 JWT sub（2023307020941），不是 hacker-id
    const ins = __mock.getLog().find((e) => e.sql.indexOf('INSERT INTO dtest2.uploads') >= 0);
    expect(ins).toBeDefined();
    expect(ins.params[1]).toBe('2023307020941');
    expect(ins.params[1]).not.toBe('hacker-id');
  });

  test('两个不同学生各自上传，owner_id 与各自 JWT 一致', async () => {
    __mock.setRoutes([
      { match: /INSERT INTO dtest2\.uploads/, result: [] }
    ]);
    const res1 = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu)
      .send({ filename: 'av1.png', contentType: 'image/png', dataBase64: TINY_PNG_B64 });
    const res2 = await request(app)
      .post('/api/uploads')
      .set('Authorization', stu2)
      .send({ filename: 'av2.png', contentType: 'image/png', dataBase64: TINY_PNG_B64 });
    expect(res1.status).toBe(200);
    expect(res2.status).toBe(200);
    // 两次插入的 owner_id 不同
    const inserts = __mock.getLog().filter((e) => e.sql.indexOf('INSERT INTO dtest2.uploads') >= 0);
    expect(inserts).toHaveLength(2);
    expect(inserts[0].params[1]).toBe('2023307020941');
    expect(inserts[1].params[1]).toBe('2023307099999');
  });
});

// ============================================================
// GET /api/uploads/:id
// ============================================================
describe('GET /api/uploads/:id', () => {
  test('存在的上传 → 200 + 正确 content-type + 文件字节', async () => {
    // 先把对象写入 storage 和 DB mock
    const fakeId = 'up-11111111-0000-0000-0000-000000000001';
    _store.set(fakeId, { buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47]), contentType: 'image/png' });
    __mock.setRoutes([
      {
        match: /SELECT storage_key, content_type FROM dtest2\.uploads WHERE upload_id/,
        result: [{ storage_key: fakeId, content_type: 'image/png' }]
      }
    ]);
    const res = await request(app).get(`/api/uploads/${fakeId}`);
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/image\/png/);
    expect(res.headers['cache-control']).toMatch(/max-age=31536000/);
    expect(res.body).toBeInstanceOf(Buffer);
  });

  test('不存在的 id → 404', async () => {
    __mock.setRoutes([
      {
        match: /SELECT storage_key, content_type FROM dtest2\.uploads WHERE upload_id/,
        result: []
      }
    ]);
    const res = await request(app).get('/api/uploads/up-nonexistent');
    expect(res.status).toBe(404);
  });

  test('无需授权即可访问（public-by-id）', async () => {
    const fakeId = 'up-22222222-0000-0000-0000-000000000002';
    _store.set(fakeId, { buffer: Buffer.from([0xff, 0xd8]), contentType: 'image/jpeg' });
    __mock.setRoutes([
      {
        match: /SELECT storage_key, content_type FROM dtest2\.uploads WHERE upload_id/,
        result: [{ storage_key: fakeId, content_type: 'image/jpeg' }]
      }
    ]);
    // 不传 Authorization 头
    const res = await request(app).get(`/api/uploads/${fakeId}`);
    expect(res.status).toBe(200);
  });
});
