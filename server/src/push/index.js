'use strict';
// 推送通知服务（roadmap #8）：HMS Push REST API + transactional outbox sweeper。
//
// 架构：推送是网络副作用，绝不在业务写事务内发起。insertMessage 保持纯 DB 写入；
// sweeper 独立轮询出站箱（pushed_at IS NULL），尝试后无论成功/跳过都置 pushed_at = now()，
// 保证队列幂等耗尽，单条失败不阻断批次，sweeper 不抛出到调用方。
//
// 去活：环境变量 PUSH_DRIVER=hms + HMS_PUSH_APP_ID / HMS_PUSH_CLIENT_ID /
//         HMS_PUSH_CLIENT_SECRET 全部配置 → 真实推送；
//       否则 dispatchToStudent 直接返回 {status:'skipped'}，零网络调用。
// 上线步骤（AGC）：
//   1. 在 AGC 控制台创建项目并开启推送服务，取 AppId / OAuth ClientId / ClientSecret。
//   2. 在 .env 写入 PUSH_DRIVER=hms + 上述三个变量。
//   3. 客户端调用 POST /api/push/tokens 上报 pushService.getToken() 返回的 token。

const { genId } = require('../ids');

// ---- HMS OAuth token 缓存（进程级，有效期内复用）----
let _hmsTokenCache = null; // { token, expiresAt }

async function getHmsOAuthToken() {
  const now = Date.now();
  if (_hmsTokenCache && _hmsTokenCache.expiresAt > now + 60_000) {
    return _hmsTokenCache.token;
  }
  const clientId = process.env.HMS_PUSH_CLIENT_ID;
  const clientSecret = process.env.HMS_PUSH_CLIENT_SECRET;
  const tokenUrl = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
  const body = `grant_type=client_credentials&client_id=${encodeURIComponent(clientId)}&client_secret=${encodeURIComponent(clientSecret)}`;
  const res = await fetch(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) {
    throw new Error(`HMS OAuth failed: ${res.status}`);
  }
  const json = await res.json();
  _hmsTokenCache = {
    token: json.access_token,
    expiresAt: now + (json.expires_in || 3600) * 1000,
  };
  return _hmsTokenCache.token;
}

/**
 * 向单个学生的所有已注册设备发推送。
 * 无配置 / 无 token → {status:'skipped'}，绝不抛出。
 * @param {{query:Function}} db
 * @param {string} studentId
 * @param {{title:string, body:string, route?:string, param?:string}} payload
 */
async function dispatchToStudent(db, studentId, payload) {
  try {
    const isConfigured =
      process.env.PUSH_DRIVER === 'hms' &&
      process.env.HMS_PUSH_APP_ID &&
      process.env.HMS_PUSH_CLIENT_ID &&
      process.env.HMS_PUSH_CLIENT_SECRET;

    if (!isConfigured) {
      return { status: 'skipped' };
    }

    const r = await db.query(
      'SELECT token FROM dtest2.device_tokens WHERE student_id = $1',
      [studentId]
    );
    if (!r.rows || r.rows.length === 0) {
      return { status: 'skipped' };
    }

    const tokens = r.rows.map((row) => row.token);
    const appId = process.env.HMS_PUSH_APP_ID;
    const accessToken = await getHmsOAuthToken();
    const pushUrl = `https://push-api.cloud.huawei.com/v1/${appId}/messages:send`;

    const message = {
      message: {
        notification: {
          title: payload.title,
          body: payload.body || '',
        },
        android: {
          notification: {
            title: payload.title,
            body: payload.body || '',
            click_action: {
              type: 1,
              intent: payload.route
                ? `#Intent;action=android.intent.action.VIEW;scheme=edu.jdz;S.route=${encodeURIComponent(payload.route)};S.param=${encodeURIComponent(payload.param || '')};end`
                : '#Intent;action=android.intent.action.MAIN;end',
            },
          },
        },
        token: tokens,
      },
    };

    const pushRes = await fetch(pushUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    });

    const pushJson = await pushRes.json();
    if (pushRes.ok && pushJson.code === '80000000') {
      return { status: 'sent', tokenCount: tokens.length };
    }
    // 非零 code = 部分失败（无效 token 等），记录但不抛出
    console.warn('[push] HMS partial failure:', JSON.stringify(pushJson));
    return { status: 'partial', code: pushJson.code };
  } catch (e) {
    // 任何网络/解析错误：记录，返回 error，不向外抛
    console.error('[push] dispatchToStudent error:', e && e.message ? e.message : e);
    return { status: 'error' };
  }
}

/**
 * 出站箱 sweeper：轮询 pushed_at IS NULL 消息，逐条推送并标记。
 * 单条失败不停止批次；不向调用方抛出（setInterval 内调用，抛出无人接收）。
 * @param {{query:Function}} db
 */
async function sweepAndPush(db) {
  let processed = 0;
  let skipped = 0;
  let errors = 0;
  try {
    const r = await db.query(
      `SELECT message_id, student_id, title, body, route, param
         FROM dtest2.messages
        WHERE pushed_at IS NULL
        ORDER BY created_at
        LIMIT 100`
    );
    if (!r.rows || r.rows.length === 0) return;

    for (const row of r.rows) {
      try {
        const result = await dispatchToStudent(db, row.student_id, {
          title: row.title,
          body: row.body || '',
          route: row.route || '',
          param: row.param || '',
        });
        // 无论推送结果如何，标记 pushed_at 防止重推
        await db.query(
          'UPDATE dtest2.messages SET pushed_at = now() WHERE message_id = $1',
          [row.message_id]
        );
        if (result.status === 'skipped') {
          skipped++;
        } else {
          processed++;
        }
      } catch (e) {
        errors++;
        console.error('[push] sweep row error:', row.message_id, e && e.message ? e.message : e);
        // 即便 UPDATE 失败也继续下一条
      }
    }

    if (processed > 0 || errors > 0) {
      console.log(`[push] sweep done: sent=${processed} skipped=${skipped} errors=${errors}`);
    }
  } catch (e) {
    console.error('[push] sweepAndPush error:', e && e.message ? e.message : e);
  }
}

module.exports = { dispatchToStudent, sweepAndPush };
