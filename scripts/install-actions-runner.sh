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

echo "[INFO] 準備 runsvc.sh..."
cp -f ./bin/runsvc.sh ./runsvc.sh
chmod 755 ./runsvc.sh

USER_UNIT_DIR="${HOME}/.config/systemd/user"
USER_UNIT_FILE="${USER_UNIT_DIR}/actions.runner.inwanding-infra.service"
mkdir -p "${USER_UNIT_DIR}"

cat > "${USER_UNIT_FILE}" <<EOF
[Unit]
Description=GitHub Actions Runner (Aiden4939-inwanding-infra.web-ubuntu-infra)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${RUNNER_HOME}/runsvc.sh
WorkingDirectory=${RUNNER_HOME}
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "[INFO] 啟動 user systemd service..."
systemctl --user daemon-reload
systemctl --user enable --now actions.runner.inwanding-infra.service
systemctl --user status actions.runner.inwanding-infra.service --no-pager || true

echo "[INFO] 若要開機後自動運行（無需登入），請手動執行："
echo "  sudo loginctl enable-linger ${RUNNER_USER}"

echo "[OK]   runner 安裝完成。請至 GitHub → Settings → Actions → Runners 確認 Online/Idle"
