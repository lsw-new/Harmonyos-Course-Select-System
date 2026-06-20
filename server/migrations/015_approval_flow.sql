-- 多级审批流（roadmap #7）：把请假审批从单节点扩展为可配置的有序多步流。
-- 表 dtest2.approval_flow_nodes / approval_steps 已在 001 建好，本迁移只补默认流配置（种子）。
-- 全部 INSERT ... WHERE NOT EXISTS，幂等可重复执行；本 schema 数据量小，迁移在事务内。
--
-- 设计说明：
--  - 目前系统没有 辅导员/院领导 角色，所有节点均由管理员（教务管理员，作为代理人）处理。
--    故每个节点的 approver_role 统一为 '教务管理员'（与 approval_steps 既有的 approver_role 取值一致），
--    管理端鉴权仍走 approvals.handle:approve，无需新增角色。
--  - approval_flow_nodes.node_order 有 UNIQUE 约束；按 node_order 升序构成审批链。
--  - 默认流：1 辅导员审批 → 2 教务审批 → 3 院领导审批（标题用于前端进度条展示，角色统一为管理员代理）。

INSERT INTO dtest2.approval_flow_nodes (node_id, name, approver_role, enabled, node_order)
SELECT 'flow-leave-1', '辅导员审批', '教务管理员', true, 1
WHERE NOT EXISTS (SELECT 1 FROM dtest2.approval_flow_nodes WHERE node_order = 1);

INSERT INTO dtest2.approval_flow_nodes (node_id, name, approver_role, enabled, node_order)
SELECT 'flow-leave-2', '教务审批', '教务管理员', true, 2
WHERE NOT EXISTS (SELECT 1 FROM dtest2.approval_flow_nodes WHERE node_order = 2);

INSERT INTO dtest2.approval_flow_nodes (node_id, name, approver_role, enabled, node_order)
SELECT 'flow-leave-3', '院领导审批', '教务管理员', true, 3
WHERE NOT EXISTS (SELECT 1 FROM dtest2.approval_flow_nodes WHERE node_order = 3);

-- 按 node_order 拉取启用节点构建步骤（提交请假时使用）；保留索引便于有序读取。
CREATE INDEX IF NOT EXISTS idx_approval_flow_nodes_order
  ON dtest2.approval_flow_nodes (node_order) WHERE enabled;

-- 按审批实例读取有序步骤（详情/进度条）。
CREATE INDEX IF NOT EXISTS idx_approval_steps_approval_order
  ON dtest2.approval_steps (approval_id, step_order);
