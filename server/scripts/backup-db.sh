#!/usr/bin/env bash
#
# backup-db.sh —— dtest2 Postgres 数据库备份脚本（仅备份 dtest2 schema）
#
# 用途：
#   用 pg_dump 导出 dtest2 schema 并 gzip 压缩，落到本地备份目录，
#   并按保留策略（天数 / 数量）清理过期旧备份。供运维手动执行或 cron 定时调用。
#
# 用法：
#   bash server/scripts/backup-db.sh
#
# 连接参数（与 server/src/db.js 默认值保持一致，可经环境变量或 server/.env 覆盖）：
#   PGHOST      数据库主机          默认 127.0.0.1
#   PGPORT      数据库端口          默认 15432
#   PGDATABASE  数据库名            默认 dtest2_harmony
#   PGUSER      数据库用户          默认 dtest2_app
#   PGPASSWORD  数据库密码          默认 空（生产请务必在 .env / 环境变量中提供）
#
# 备份相关可配项：
#   BACKUP_DIR  备份输出目录        默认 ~/dtest2-backups
#   KEEP_DAYS   按天数保留          默认 14（删除修改时间超过该天数的 .sql.gz）
#   KEEP_COUNT  按数量保留          默认 30（按时间倒序，仅保留最新 N 份）
#
# cron 示例（每日 03:00 备份，日志追加到 ~/dtest2-backups/backup.log）：
#   0 3 * * * /usr/bin/env bash /home/ubuntu/test2/server/scripts/backup-db.sh >> /home/ubuntu/dtest2-backups/backup.log 2>&1
#
# 注意：密码通过 PGPASSWORD 环境变量传给 pg_dump，绝不写入文件或打印到日志。

set -euo pipefail

# ---- 定位脚本与项目目录 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- 若存在 server/.env 则加载（兼容已有部署，密码等敏感配置从此读取）----
if [[ -f "${SERVER_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SERVER_DIR}/.env"
  set +a
fi

# ---- 连接参数（缺失则取与 db.js 一致的默认值）----
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-15432}"
PGDATABASE="${PGDATABASE:-dtest2_harmony}"
PGUSER="${PGUSER:-dtest2_app}"
PGPASSWORD="${PGPASSWORD:-}"
export PGPASSWORD

# ---- 备份配置 ----
BACKUP_DIR="${BACKUP_DIR:-${HOME}/dtest2-backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
KEEP_COUNT="${KEEP_COUNT:-30}"
SCHEMA="dtest2"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTFILE="${BACKUP_DIR}/${PGDATABASE}_${TIMESTAMP}.sql.gz"

# ---- 失败处理：任一命令非零退出都会触发 trap ----
on_error() {
  local code=$?
  echo "[backup-db] 失败：命令在第 ${BASH_LINENO[0]} 行退出，退出码 ${code}" >&2
  # 清理可能产生的不完整文件
  if [[ -f "${OUTFILE}" ]]; then
    rm -f "${OUTFILE}"
    echo "[backup-db] 已删除不完整的备份文件：${OUTFILE}" >&2
  fi
  exit "${code}"
}
trap on_error ERR

# ---- 准备目录 ----
mkdir -p "${BACKUP_DIR}"

echo "[backup-db] 开始备份 schema='${SCHEMA}' db='${PGDATABASE}' @ ${PGHOST}:${PGPORT} （用户 ${PGUSER}）"

# ---- 执行 pg_dump 并 gzip；PIPESTATUS 检查管道首段（pg_dump）是否成功 ----
pg_dump \
  --host="${PGHOST}" \
  --port="${PGPORT}" \
  --username="${PGUSER}" \
  --dbname="${PGDATABASE}" \
  --schema="${SCHEMA}" \
  --no-owner \
  --no-privileges \
  | gzip -9 > "${OUTFILE}"

# 管道下 pg_dump 的退出码在 PIPESTATUS[0]（set -e 不会捕获非末段失败）
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  echo "[backup-db] pg_dump 返回非零，备份失败" >&2
  rm -f "${OUTFILE}"
  exit 1
fi

# ---- 结果报告 ----
SIZE="$(du -h "${OUTFILE}" | cut -f1)"
echo "[backup-db] 备份完成：${OUTFILE} （大小 ${SIZE}）"

# ---- 保留策略 1：按天数删除过期备份 ----
echo "[backup-db] 清理：删除修改时间超过 ${KEEP_DAYS} 天的旧备份"
while IFS= read -r -d '' old; do
  echo "[backup-db]   删除（超期 ${KEEP_DAYS} 天）：${old}"
  rm -f "${old}"
done < <(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "${PGDATABASE}_*.sql.gz" -mtime "+${KEEP_DAYS}" -print0)

# ---- 保留策略 2：按数量保留最新 KEEP_COUNT 份，多余的删除 ----
echo "[backup-db] 清理：仅保留最新 ${KEEP_COUNT} 份备份"
mapfile -t ALL_BACKUPS < <(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "${PGDATABASE}_*.sql.gz" -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
if [[ "${#ALL_BACKUPS[@]}" -gt "${KEEP_COUNT}" ]]; then
  for ((i = KEEP_COUNT; i < ${#ALL_BACKUPS[@]}; i++)); do
    echo "[backup-db]   删除（超量第 $((i + 1)) 份）：${ALL_BACKUPS[i]}"
    rm -f "${ALL_BACKUPS[i]}"
  done
fi

echo "[backup-db] 全部完成。当前备份目录：${BACKUP_DIR}"
