-- 全局系统配置（键值，jsonb）：首个用途为评教期开关 key='eval.period.open'（value_json 为布尔）。
-- 管理员在管理端切换后全局生效：学生端评教入口/问卷/提交均以此为准（后端提交时权威校验）。
CREATE TABLE IF NOT EXISTS dtest2.system_settings (
    key text PRIMARY KEY,
    value_json jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
