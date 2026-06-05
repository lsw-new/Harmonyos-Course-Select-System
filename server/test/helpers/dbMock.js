// 可复用的 Postgres 连接池 mock：按 SQL 子串路由返回结果，覆盖 pool.query 与事务 client.query。
//
// 用法（在测试文件顶部，jest.mock 会被提升到模块加载之前）：
//   jest.mock('../src/db', () => require('./helpers/dbMock'));
//   const { __mock } = require('./helpers/dbMock');
//   const app = require('../src/index');
//   beforeEach(() => __mock.reset());
//   __mock.setRoutes([{ match: /FROM dtest2\.courses/, result: [{ capacity: 50, status: 'open', ... }] }]);
//
// route.match 可为 RegExp 或 (sql, params)=>boolean；
// route.result 可为数组/对象/Error，或 (params, sql)=>(数组|对象|Error)。返回 Error 即模拟查询抛错。
// BEGIN/COMMIT/ROLLBACK 自动返回空结果，便于断言事务回滚（见 __mock.getLog）。

function makeResult(rows) {
  const arr = Array.isArray(rows) ? rows : (rows === undefined || rows === null ? [] : [rows]);
  return { rows: arr, rowCount: arr.length };
}

const state = { routes: [], log: [] };

function reset() {
  state.routes = [];
  state.log = [];
}

function setRoutes(routes) {
  state.routes = Array.isArray(routes) ? routes.slice() : [];
}

function getLog() {
  return state.log.slice();
}

// 断言某 SQL 片段是否被执行过（如 'ROLLBACK'、'FOR UPDATE'、'INSERT INTO dtest2.selections'）
function executed(fragment) {
  return state.log.some((e) => e.sql.indexOf(fragment) >= 0);
}

async function runQuery(sql, params) {
  const text = String(sql);
  state.log.push({ sql: text, params });
  if (/^\s*(BEGIN|COMMIT|ROLLBACK)\b/i.test(text.trim())) {
    return makeResult([]);
  }
  for (const route of state.routes) {
    const m = route.match;
    const hit = (m instanceof RegExp) ? m.test(text) : !!m(text, params);
    if (hit) {
      const out = (typeof route.result === 'function') ? route.result(params, text) : route.result;
      if (out instanceof Error) {
        throw out;
      }
      return makeResult(out);
    }
  }
  // 未匹配的查询返回空结果，避免 undefined 崩溃；测试可据 getLog 断言。
  return makeResult([]);
}

const client = {
  query: (sql, params) => runQuery(sql, params),
  release: () => undefined
};

const pool = {
  query: (sql, params) => runQuery(sql, params),
  connect: async () => client
};

module.exports = { pool, __mock: { reset, setRoutes, getLog, executed } };
