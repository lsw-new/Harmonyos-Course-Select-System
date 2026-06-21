'use strict';
// 消息中心写入助手（roadmap #4）：在既有写路径（成绩发布 / 审批结果 / 评教生成 等）
// 触发时往 dtest2.messages 落一行。db 可为连接池(pool) 或事务中的 client，
// 故触发点可复用调用方已开的事务（与业务写同生共死）。
//
// 设计取舍：本函数「不」自己 try/catch 吞错。当调用方在显式事务内调用时，
// INSERT 失败应向上抛出，让调用方的 catch 走 ROLLBACK——既不破坏宿主事务的一致性，
// 也不会把 bug 静默藏起来（符合“显式处理错误、绝不静默吞错”的规范）。

const { genId } = require('./ids');

/**
 * 往 dtest2.messages 插入一行消息。
 * @param {{query: Function}} db pool 或事务 client
 * @param {{studentId: string, kind: string, title: string, body?: string, route?: string, param?: string}} m
 * @returns {Promise<string>} 新建的 message_id
 */
async function insertMessage(db, m) {
  const messageId = genId('msg');
  await db.query(
    `INSERT INTO dtest2.messages (message_id, student_id, kind, title, body, route, param)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [
      messageId,
      m.studentId,
      m.kind,
      m.title,
      m.body === undefined ? null : m.body,
      m.route === undefined ? null : m.route,
      m.param === undefined ? null : m.param,
    ]
  );
  return messageId;
}

module.exports = { insertMessage };
