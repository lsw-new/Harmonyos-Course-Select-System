-- 对象存储元数据表（roadmap #9）：记录每次上传的基本信息，
-- 实际文件字节由 storage 适配器（默认本地文件系统，可切 S3/MinIO）持有。
-- storage_key 为适配器内部定位键（本地模式 = upload_id；S3 模式可含前缀路径）。
-- 全部 CREATE ... IF NOT EXISTS，幂等可重复执行，可安全置于迁移系统事务内。

CREATE TABLE IF NOT EXISTS dtest2.uploads (
    upload_id    text PRIMARY KEY,
    owner_id     text NOT NULL,
    kind         text NOT NULL DEFAULT 'image',
    filename     text NOT NULL,
    content_type text NOT NULL,
    size_bytes   int  NOT NULL,
    storage_key  text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- 按上传者 + 时间倒序查询（如列出某用户的上传历史）
CREATE INDEX IF NOT EXISTS idx_uploads_owner_created
  ON dtest2.uploads (owner_id, created_at DESC);
