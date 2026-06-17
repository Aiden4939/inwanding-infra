#!/usr/bin/env bash
# 移除 GitHub Actions self-hosted runner
#
# 用法：
#   export RUNNER_REMOVE_TOKEN='xxxx'   # GitHub UI → Remove runner 取得
#   ./scripts/uninstall-actions-runner.sh
set -euo pipefail

RUNNER_HOME="${RUNNER_HOME:-/home/aiden/actions-runner-infra}"

if [[ ! -d "${RUNNER_HOME}" ]]; then
  echo "[INFO] runner 目錄不存在，無需移除"
  exit 0
fi

cd "${RUNNER_HOME}"

if [[ -f "./svc.sh" ]]; then
  echo "[INFO] 停止並移除 systemd service..."
  sudo ./svc.sh stop || true
  sudo ./svc.sh uninstall || true
fi

if [[ -f "./config.sh" && -n "${RUNNER_REMOVE_TOKEN:-}" ]]; then
  echo "[INFO] 從 GitHub 取消註冊 runner..."
  ./config.sh remove --token "${RUNNER_REMOVE_TOKEN}"
elif [[ -f "./.runner" ]]; then
  echo "[WARN] 未提供 RUNNER_REMOVE_TOKEN，略過 GitHub 端 unregister（請至 UI 手動 Remove）" >&2
fi

cd /home/aiden
rm -rf "${RUNNER_HOME}"
echo "[OK]   runner 已移除"
