#!/usr/bin/env bash
# 備份 nginx/conf.d 至 backups/nginx-conf.d/（UTC 時間戳檔名）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${INFRA_ROOT}/nginx/conf.d"
DEST_DIR="${INFRA_ROOT}/backups/nginx-conf.d"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[ERROR] 找不到來源目錄: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

shopt -s nullglob
files=("${SRC_DIR}"/*)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "[ERROR] ${SRC_DIR} 內沒有可備份的檔案" >&2
  exit 1
fi

echo "[INFO] 備份 Nginx conf: ${SRC_DIR} -> ${DEST_DIR}"
for f in "${files[@]}"; do
  base="$(basename "${f}")"
  dest="${DEST_DIR}/${base}.${STAMP}.bak"
  cp -a "${f}" "${dest}"
  echo "[OK]   ${f} -> ${dest}"
done

echo "[INFO] 完成。舊備份不會自動刪除，請自行定期清理 ${DEST_DIR}"
