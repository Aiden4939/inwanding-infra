#!/usr/bin/env bash
# 新增 tgbot.inwanding.com 至 Cloudflare Tunnel ingress（需 sudo）
set -euo pipefail

CONFIG="/etc/cloudflared/config.yml"
BACKUP="/etc/cloudflared/config.yml.bak.$(date -u +%Y%m%dT%H%M%SZ)"

if grep -q 'hostname: tgbot.inwanding.com' "$CONFIG" 2>/dev/null; then
  echo "[OK]   tgbot.inwanding.com 已存在於 $CONFIG"
else
  echo "[INFO] 備份 $CONFIG -> $BACKUP"
  cp "$CONFIG" "$BACKUP"
  awk '
    /hostname: linebot.inwanding.com/ { print; getline; print; print ""; print "  - hostname: tgbot.inwanding.com"; print "    service: http://127.0.0.1:8080"; next }
    { print }
  ' "$BACKUP" > /tmp/cloudflared-config.yml.$$
  mv /tmp/cloudflared-config.yml.$$ "$CONFIG"
  echo "[OK]   已新增 tgbot.inwanding.com"
fi

echo "[INFO] 重啟 cloudflared..."
systemctl restart cloudflared
systemctl is-active --quiet cloudflared && echo "[OK]   cloudflared 運行中"

echo "[INFO] 建立 Cloudflare DNS 路由（CNAME → tunnel）..."
if command -v cloudflared >/dev/null 2>&1; then
  cloudflared tunnel route dns inwanding-tunnel tgbot.inwanding.com || true
else
  echo "[WARN] 找不到 cloudflared CLI，請至 Cloudflare Dashboard 手動新增 CNAME："
  echo "       tgbot.inwanding.com → <tunnel-id>.cfargotunnel.com"
fi

echo "[INFO] 等待 DNS 傳播（約 10–60 秒）後驗證："
echo "  curl -s https://tgbot.inwanding.com/health"
