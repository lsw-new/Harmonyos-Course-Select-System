-- 消息中心服务端化（roadmap #4）：把原本由客户端聚合 请假/成绩/选课/评教 派生的「消息流」
-- 收口到服务端落库，使「已读状态」可跨设备同步（客户端本地 MessageSeenStore 无法跨端）。
--
-- 表 dtest2.messages：一名学生一行（per-student 行），已读状态用 read_at 列即可（NULL=未读），
-- 无需独立的「已读关联表」。kind 受 CHECK 约束限定为五类。
-- 全部 CREATE ... IF NOT EXISTS，幂等可重复执行，可安全置于单事务迁移内。

CREATE TABLE IF NOT EXISTS dtest2.messages (
    message_id  text PRIMARY KEY,
    student_id  text NOT NULL,
    kind        text NOT NULL,
    title       text NOT NULL,
    body        text,
    route       text,
    param       text,
    read_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT messages_kind_check
      CHECK (kind = ANY (ARRAY['grade'::text, 'approval'::text, 'selection'::text, 'eval'::text, 'system'::text]))
);

-- 列表查询：当前学生的消息按时间倒序（GET /api/messages）。
CREATE INDEX IF NOT EXISTS idx_messages_student_created
  ON dtest2.messages (student_id, created_at DESC);

-- 未读计数 / 未读筛选（GET /api/messages/unread-count）：仅索引未读行，体积小。
CREATE INDEX IF NOT EXISTS idx_messages_student_unread
  ON dtest2.messages (student_id) WHERE read_at IS NULL;
