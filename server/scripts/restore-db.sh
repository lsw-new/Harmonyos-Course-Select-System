#!/usr/bin/env bash
#
# restore-db.sh —— 从 backup-db.sh 生成的 .sql.gz 恢复 dtest2 数据库
#
# 用途：
#   将指定的 gzip 压缩备份解压后用 psql 导入目标数据库。
#
# ⚠️ 危险操作：本脚本会把备份内容直接灌入目标库的 dtest2 schema，
#   覆盖 / 重建其中的表与数据。务必在执行前：
#     1) 先用 backup-db.sh 对当前库做一次新备份；
#     2) 确认目标连接参数（PGHOST/PGPORT/PGDATABASE/PGUSER）指向正确实例。
#
# 用法：
#   CONFIRM=yes bash server/scripts/restore-db.sh <备份文件.sql.gz>
#
#   未设置 CONFIRM=yes 时脚本只打印警告并退出（防误操作护栏）。
#
# 连接参数（与 backup-db.sh / db.js 一致，可经环境变量或 server/.env 覆盖）：
#   PGHOST      默认 127.0.0.1
#   PGPORT      默认 15432
#   PGDATABASE  默认 dtest2_harmony
#   PGUSER      默认 dtest2_app
#   PGPASSWORD  默认 空

set -euo pipefail

# ---- 定位脚本与项目目录 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- 参数校验 ----
BACKUP_FILE="${1:-}"
if [[ -z "${BACKUP_FILE}" ]]; then
  echo "[restore-db] 用法：CONFIRM=yes bash server/scripts/restore-db.sh <备份文件.sql.gz>" >&2
  exit 2
fi
if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "[restore-db] 找不到备份文件：${BACKUP_FILE}" >&2
  exit 2
fi

# ---- 加载 server/.env（密码等敏感配置）----
if [[ -f "${SERVER_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SERVER_DIR}/.env"
  set +a
fi

# ---- 连接参数 ----
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-15432}"
PGDATABASE="${PGDATABASE:-dtest2_harmony}"
PGUSER="${PGUSER:-dtest2_app}"
PGPASSWORD="${PGPASSWORD:-}"
export PGPASSWORD

# ---- 安全护栏：必须显式 CONFIRM=yes ----
if [[ "${CONFIRM:-}" != "yes" ]]; then
  echo "============================================================" >&2
  echo "[restore-db] ⚠️  即将把备份恢复到数据库，这会覆盖 dtest2 schema 现有数据！" >&2
  echo "[restore-db]     目标库：${PGDATABASE} @ ${PGHOST}:${PGPORT}（用户 ${PGUSER}）" >&2
  echo "[restore-db]     备份文件：${BACKUP_FILE}" >&2
  echo "[restore-db]" >&2
  echo "[restore-db] 已取消。确认无误后请改用：" >&2
  echo "[restore-db]     CONFIRM=yes bash server/scripts/restore-db.sh '${BACKUP_FILE}'" >&2
  echo "============================================================" >&2
  exit 1
fi

# ---- 失败处理 ----
on_error() {
  local code=$?
  echo "[restore-db] 失败：命令在第 ${BASH_LINENO[0]} 行退出，退出码 ${code}" >&2
  exit "${code}"
}
trap on_error ERR

echo "[restore-db] 开始恢复：${BACKUP_FILE} -> ${PGDATABASE} @ ${PGHOST}:${PGPORT}"

# ---- 解压并导入；ON_ERROR_STOP=1 让 SQL 出错即中断 ----
gunzip -c "${BACKUP_FILE}" \
  | psql \
      --host="${PGHOST}" \
      --port="${PGPORT}" \
      --username="${PGUSER}" \
      --dbname="${PGDATABASE}" \
      --set ON_ERROR_STOP=1 \
      --quiet

# 检查管道首段（gunzip）是否成功
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  echo "[restore-db] gunzip 解压失败，恢复未完成" >&2
  exit 1
fi

echo "[restore-db] 恢复完成。建议随后用 curl /api/health 验证服务与数据库连通。"
