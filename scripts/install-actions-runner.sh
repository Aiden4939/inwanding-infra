#!/usr/bin/env bash
# 安裝並註冊 GitHub Actions self-hosted runner（repo-level, inwanding-infra）
#
# 用法：
#   export RUNNER_REGISTRATION_TOKEN='xxxx'   # 從 GitHub UI 取得，短時效
#   ./scripts/install-actions-runner.sh
#
# 回滾：
#   export RUNNER_REMOVE_TOKEN='xxxx'         # 從 GitHub UI Remove runner 取得
#   ./scripts/uninstall-actions-runner.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNNER_HOME="${RUNNER_HOME:-/home/aiden/actions-runner-infra}"
RUNNER_VERSION="${RUNNER_VERSION:-2.335.1}"
RUNNER_REPO_URL="${RUNNER_REPO_URL:-https://github.com/Aiden4939/inwanding-infra}"
RUNNER_NAME="${RUNNER_NAME:-web-ubuntu-infra}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64,web-ubuntu,deploy,infra}"
RUNNER_USER="${RUNNER_USER:-aiden}"

if [[ "$(id -un)" != "${RUNNER_USER}" ]]; then
  echo "[ERROR] 請以 ${RUNNER_USER} 執行此腳本" >&2
  exit 1
fi

if [[ -z "${RUNNER_REGISTRATION_TOKEN:-}" ]]; then
  echo "[ERROR] 缺少 RUNNER_REGISTRATION_TOKEN" >&2
  echo "取得方式：GitHub → Aiden4939/inwanding-infra → Settings → Actions → Runners → New self-hosted runner" >&2
  exit 1
fi

mkdir -p "${RUNNER_HOME}"
cd "${RUNNER_HOME}"

TARBALL="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

if [[ ! -f "./config.sh" ]]; then
  echo "[INFO] 下載 runner v${RUNNER_VERSION}..."
  curl -fsSL -o "${TARBALL}" -L "${DOWNLOAD_URL}"
  tar xzf "${TARBALL}"
  rm -f "${TARBALL}"
fi

if [[ -f "./.runner" ]]; then
  echo "[WARN] runner 似乎已註冊，略過 config.sh（若要重裝請先執行 uninstall-actions-runner.sh）"
else
  echo "[INFO] 註冊 runner: ${RUNNER_NAME}"
  ./config.sh \
    --url "${RUNNER_REPO_URL}" \
    --token "${RUNNER_REGISTRATION_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --unattended \
    --replace
fi

echo "[INFO] 安裝 systemd service（需要 sudo 密碼）..."
sudo ./svc.sh install "${RUNNER_USER}"
sudo ./svc.sh start
sudo ./svc.sh status

echo "[OK]   runner 安裝完成。請至 GitHub → Settings → Actions → Runners 確認 Online/Idle"
