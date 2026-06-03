#!/usr/bin/env bash
# 透過 pg_dump 備份 appdb（資料來自 volume nginx_pg_data / 容器 svc-postgres）
# 輸出: backups/postgres/appdb_<UTC>.sql.gz
# 注意: 本腳本不會刪除舊備份；執行前請確認磁碟空間與維護窗口。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${INFRA_ROOT}/backups/postgres"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
CONTAINER="${POSTGRES_CONTAINER:-svc-postgres}"
DB_USER="${POSTGRES_USER:-appuser}"
DB_NAME="${POSTGRES_DB:-appdb}"
OUT_FILE="${DEST_DIR}/appdb_${STAMP}.sql.gz"

mkdir -p "${DEST_DIR}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "[ERROR] 容器未運行: ${CONTAINER}" >&2
  exit 1
fi

echo "[INFO] 開始 pg_dump: container=${CONTAINER} db=${DB_NAME} user=${DB_USER}"
echo "[INFO] 輸出: ${OUT_FILE}"

docker exec "${CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" --no-owner --no-acl \
  | gzip -c > "${OUT_FILE}"

if [[ ! -s "${OUT_FILE}" ]]; then
  echo "[ERROR] 備份檔為空: ${OUT_FILE}" >&2
  exit 1
fi

ls -lh "${OUT_FILE}"
echo "[INFO] 完成。還原方式見 docs/RESTORE.md（執行前請勿在未確認下覆寫正式 DB）"
