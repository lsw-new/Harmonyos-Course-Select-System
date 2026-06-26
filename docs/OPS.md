# 运维手册（OPS）

本文档描述 dtest2 后端的日常运维：健康检查、可用性监控、数据库备份与恢复、日志。

## 部署概览

| 组件 | 说明 |
|------|------|
| 后端进程 | Node + Express，由 **pm2** 托管，进程名 `dtest2-api`，监听 `:8090` |
| 反向代理 | nginx 反代 `https://lsw666.dns.army/api` → 本机 `127.0.0.1:8090`（公网仅开放 80/443） |
| 数据库 | Postgres 跑在同机容器，经 `127.0.0.1:15432` 暴露；业务 schema 为 `dtest2` |
| 主机 | Oracle 云主机 |
| 日志 | 由 pm2 捕获，`pm2 logs dtest2-api` 查看 |

数据库连接参数（与 `server/src/db.js` 默认值一致，可由 `server/.env` 或环境变量覆盖）：

| 变量 | 默认值 |
|------|--------|
| `PGHOST` | `127.0.0.1` |
| `PGPORT` | `15432` |
| `PGDATABASE` | `dtest2_harmony` |
| `PGUSER` | `dtest2_app` |
| `PGPASSWORD` | 空（生产在 `.env` 中提供） |

---

## 1. 健康检查

后端提供健康检查端点（公网经 nginx `/api` 反代；本机可直连裸 `/health`）：

```bash
# 公网
curl -fsS https://lsw666.dns.army/api/health

# 本机直连（绕过 nginx）
curl -fsS http://127.0.0.1:8090/health
```

正常响应（HTTP 200，统一响应信封 `{ success, data, error }`）：

```json
{
  "success": true,
  "data": {
    "db": "ok",
    "now": "2026-06-26T03:00:00.000Z",
    "uptime": 86400,
    "version": "0.1.0",
    "nodeEnv": "production",
    "time": "2026-06-26T03:00:00.000Z"
  },
  "error": null
}
```

判读规则：

- **`success: true` 且 HTTP 200** → 服务正常，且数据库连接可用（`data.db === "ok"`，`data.now` 为数据库当前时间）。`data.uptime`（进程运行秒数）骤降说明进程刚重启过；`data.version` 为后端版本；`data.nodeEnv` 应为 `production`。
- **`success: false`**（端点内部捕获到数据库连接失败时返回）→ **异常**，需立即排查数据库容器与连接。
- **HTTP 非 200 / 连接超时 / 无响应** → 进程挂了或 nginx 异常，先看 `pm2 status` 与 `pm2 logs dtest2-api`。

> 说明：健康检查会真正执行一次 `SELECT now()`，因此它同时覆盖「进程存活」与「数据库可达」两层。审计中间件对 `/api/health` 做了豁免，不会污染审计日志。

排障速查：

```bash
pm2 status                 # 进程是否 online
pm2 logs dtest2-api --lines 100
# 数据库是否可连（需要 psql 客户端）
PGPASSWORD=*** psql -h 127.0.0.1 -p 15432 -U dtest2_app -d dtest2_harmony -c 'select 1'
```

---

## 2. 可用性（Uptime）监控

用外部探针定时请求 `/api/health`，在 **非 200 或 `success:false`** 时告警。两种常见做法：

### 方式 A：托管监控服务（推荐，省心）

用 [UptimeRobot](https://uptimerobot.com/) 或 [BetterStack](https://betterstack.com/) 等：

- 监控类型选 **HTTP(s)** 或 **Keyword**。
- URL 填 `https://lsw666.dns.army/api/health`。
- 关键字监控：要求响应体包含 `"success":true`（这样即使 HTTP 200 但 `success:false` 也能判为故障）。
- 探测间隔 1–5 分钟，连续 2 次失败后通过邮件 / 短信 / Webhook 告警。

### 方式 B：自建 cron 探针

在另一台机器（避免与被监控主机同生共死）上放一段 cron 脚本，失败时发通知：

```bash
# 每 2 分钟探一次；非 200 或 success!=true 即告警
*/2 * * * * curl -fsS --max-time 10 https://lsw666.dns.army/api/health | grep -q '"success":true' \
  || echo "[ALERT] dtest2 health check failed @ $(date -Is)" | mail -s "dtest2 DOWN" you@example.com
```

- `curl -f` 在 HTTP 非 2xx 时返回非零，`grep -q '"success":true'` 兜住「200 但业务失败」。
- 告警动作可换成 Webhook（Slack / 钉钉 / 飞书）、Server 酱等。

---

## 3. 数据库备份

备份脚本：`server/scripts/backup-db.sh`（仅导出 `dtest2` schema，gzip 压缩）。

### 用法

```bash
# 用默认配置备份（连接参数自动从 server/.env 读取）
bash server/scripts/backup-db.sh

# 自定义备份目录 / 保留策略
BACKUP_DIR=/data/backups KEEP_DAYS=30 KEEP_COUNT=60 bash server/scripts/backup-db.sh
```

可配项（环境变量）：

| 变量 | 默认 | 说明 |
|------|------|------|
| `BACKUP_DIR` | `~/dtest2-backups` | 备份输出目录，自动创建 |
| `KEEP_DAYS` | `14` | 删除修改时间超过该天数的旧备份 |
| `KEEP_COUNT` | `30` | 仅保留最新 N 份，多余删除 |

输出文件名形如 `dtest2_harmony_YYYYmmdd_HHMMSS.sql.gz`；脚本结束会打印路径与大小，并记录清理了哪些旧备份。密码通过 `PGPASSWORD` 环境变量传给 `pg_dump`，**不会写入文件或日志**。

### crontab 每日定时（每天 03:00）

```cron
0 3 * * * /usr/bin/env bash /home/ubuntu/test2/server/scripts/backup-db.sh >> /home/ubuntu/dtest2-backups/backup.log 2>&1
```

> 将路径替换为实际部署路径。建议把 `backup.log` 一并纳入轮转或定期清理。

---

## 4. 数据库恢复

恢复脚本：`server/scripts/restore-db.sh`，从指定 `.sql.gz` 恢复。

### 用法

```bash
# 必须显式设置 CONFIRM=yes（防误操作护栏）
CONFIRM=yes bash server/scripts/restore-db.sh ~/dtest2-backups/dtest2_harmony_20260626_030000.sql.gz
```

- **未设置 `CONFIRM=yes`** 时脚本只打印警告并退出，不做任何改动。
- 恢复使用 `gunzip -c <file> | psql ... --set ON_ERROR_STOP=1`，SQL 出错即中断。

### 注意事项

- ⚠️ 恢复会**覆盖 `dtest2` schema 现有数据**。执行前**务必先用 `backup-db.sh` 对当前库做一次新备份**。
- 确认目标连接参数（`PGHOST/PGPORT/PGDATABASE/PGUSER`）指向正确实例，避免灌错库。
- 恢复期间可考虑先停掉写流量（如临时 `pm2 stop dtest2-api`），恢复完成后再启动。
- 恢复后用 `curl /api/health` 验证服务与数据库连通。

---

## 5. 日志

后端日志由 pm2 捕获：

```bash
pm2 logs dtest2-api              # 实时跟踪
pm2 logs dtest2-api --lines 200  # 查看最近 200 行
pm2 status                       # 进程状态 / 重启次数 / 内存
pm2 restart dtest2-api           # 重启进程
```

### 日志轮转（建议）

pm2 默认不切割日志，长期运行会让单个日志文件无限增长。安装 `pm2-logrotate` 做轮转：

```bash
pm2 install pm2-logrotate

# 常用配置（按需调整）
pm2 set pm2-logrotate:max_size 10M        # 单文件超过 10M 切割
pm2 set pm2-logrotate:retain 14           # 保留最近 14 个归档
pm2 set pm2-logrotate:compress true       # 旧日志 gzip 压缩
pm2 set pm2-logrotate:rotateInterval '0 0 * * *'  # 每天 0 点轮转
```

> 装好后无需改业务代码，pm2 会自动对 `dtest2-api` 的 stdout/stderr 日志做轮转与压缩。
