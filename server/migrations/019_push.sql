-- 推送通知（roadmap #8）：设备 token 注册 + 消息推送出站箱（transactional outbox）。
--
-- 1. device_tokens：学生可注册多台设备的 HMS 推送 token（student + token 唯一）。
-- 2. messages.pushed_at：出站箱标志。NULL = 待推送；非 NULL = 已尝试推送（无论成功/跳过）。
--    sweeper 仅处理 pushed_at IS NULL 行，每次尝试后无论结果都写 pushed_at = now()，
--    保证队列幂等耗尽，绝不重复推送。
--
-- 注意：insertMessage 的 INSERT 显式列出列名，不含 pushed_at，故迁移后新消息
-- pushed_at 默认 NULL → 自动进入待推送队列。
-- 回填：将迁移前已有历史消息标记为已推（不对存量消息发送通知，避免刷屏）。
--
-- 幂等：全部使用 IF NOT EXISTS / 无内层 BEGIN/COMMIT。

CREATE TABLE IF NOT EXISTS dtest2.device_tokens (
    token_id   text PRIMARY KEY,
    student_id text NOT NULL,
    token      text NOT NULL,
    platform   text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_student_token
    ON dtest2.device_tokens (student_id, token);

CREATE INDEX IF NOT EXISTS idx_device_tokens_student
    ON dtest2.device_tokens (student_id);

ALTER TABLE dtest2.messages ADD COLUMN IF NOT EXISTS pushed_at timestamptz;

-- 回填：迁移前历史消息视为已推送（以 created_at 代替 pushed_at），
-- 使 sweeper 首次运行时的待推送队列为空。
UPDATE dtest2.messages
   SET pushed_at = created_at
 WHERE pushed_at IS NULL;
