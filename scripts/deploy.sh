#!/usr/bin/env bash
# 標準部署：compose config 驗證 → pull → up -d → nginx -t → reload
# 不修改 .env、不變更 Cloudflare Tunnel、不刪除 volume。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${INFRA_ROOT}/docker-compose.yml"
NGINX_CONTAINER="${NGINX_CONTAINER:-edge-nginx}"

cd "${INFRA_ROOT}"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[ERROR] 找不到 compose: ${COMPOSE_FILE}" >&2
  exit 1
fi

if [[ ! -f "${INFRA_ROOT}/.env" ]]; then
  echo "[WARN] 找不到 .env，compose 可能無法載入變數" >&2
fi

echo "[INFO] === 1/5 docker compose config ==="
docker compose -f "${COMPOSE_FILE}" config >/dev/null
echo "[OK]   compose config 驗證通過"

echo "[INFO] === 2/5 docker compose pull ==="
docker compose -f "${COMPOSE_FILE}" pull

echo "[INFO] === 3/5 docker compose up -d ==="
docker compose -f "${COMPOSE_FILE}" up -d

echo "[INFO] === 4/5 服務狀態 ==="
docker compose -f "${COMPOSE_FILE}" ps

if docker ps --format '{{.Names}}' | grep -qx "${NGINX_CONTAINER}"; then
  echo "[INFO] === 5/5 nginx -t && reload (${NGINX_CONTAINER}) ==="
  docker exec "${NGINX_CONTAINER}" nginx -t
  docker exec "${NGINX_CONTAINER}" nginx -s reload
  echo "[OK]   nginx reload 完成"
else
  echo "[WARN] 找不到 ${NGINX_CONTAINER}，略過 nginx reload" >&2
fi

echo "[INFO] 部署流程結束。請依 docs/DEPLOY.md 執行 curl 驗證。"
