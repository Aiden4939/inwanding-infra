# Telegram Agent Bot 部署 SOP

適用：`telegram-agent-bot` 部署至 `web-ubuntu`（`~/inwanding-infra`）。

## 架構

```
Telegram 伺服器
  → https://tgbot.inwanding.com/telegram/webhook
  → cloudflared → edge-nginx:8080
  → svc-telegram-bot:3001
       ├─ scrape → svc-telegram-playwright:3100
       ├─ dev    → Cursor SDK（讀 /workspace 掛載）
       └─ chat   → OpenAI
  → SQLite volume: telegram_bot_data
```

## 前置條件

- [ ] `telegram-agent-bot` 已 push 至 GitHub，且 GHCR image 已建置：
  - `ghcr.io/aiden4939/telegram-agent-bot:latest`
  - `ghcr.io/aiden4939/telegram-playwright-service:latest`
- [ ] 主機 `~/inwanding-infra` 已 `git pull`
- [ ] `.env` 已填入 Telegram / OpenAI / Cursor 相關變數（對照 `.env.example`）
- [ ] 主機上有程式碼目錄（預設 `/home/aiden/inwanding`），供 dev 任務掛載為 `/workspace`

## 首次部署步驟

### 1. 設定 `.env`

在 `~/inwanding-infra/.env` 新增（勿提交 git）：

```env
TELEGRAM_BOT_TOKEN=...
ALLOWED_TELEGRAM_USER_IDS=你的_telegram_user_id
TELEGRAM_OPENAI_API_KEY=sk-...
TELEGRAM_INTERNAL_API_SECRET=隨機字串
TELEGRAM_CURSOR_API_KEY=...          # 若要使用開發任務
TELEGRAM_WORKSPACE_HOST_PATH=/home/aiden/inwanding
TELEGRAM_DEFAULT_CWD=/workspace
TELEGRAM_ALLOWED_CWD_ROOTS=/workspace
TELEGRAM_WEBHOOK_URL=https://tgbot.inwanding.com/telegram/webhook
```

### 2. Cloudflare Tunnel + DNS

```bash
cd ~/inwanding-infra
./scripts/setup-telegrambot-tunnel.sh
```

或手動在 `/etc/cloudflared/config.yml` 加入：

```yaml
  - hostname: tgbot.inwanding.com
    service: http://127.0.0.1:8080
```

### 3. 部署容器

```bash
cd ~/inwanding-infra
./scripts/backup-nginx-conf.sh    # 建議
docker compose config
docker compose pull telegram-playwright telegram-bot
docker compose up -d telegram-playwright telegram-bot
docker exec edge-nginx nginx -t && docker exec edge-nginx nginx -s reload
```

或透過 GitHub Actions：**Deploy Service (Manual)** → 選 `telegram-bot`。

### 4. 驗證

```bash
# 本機（繞過 Cloudflare）
curl -s http://127.0.0.1:8080/health -H "Host: tgbot.inwanding.com"
# 預期：{"ok":true}

# 公網
curl -s https://tgbot.inwanding.com/health

# 日誌
docker compose logs -f telegram-bot telegram-playwright
```

在 Telegram 對 Bot 傳 `/status` 或測試訊息。

## 更新部署

image 有新版本時：

```bash
cd ~/inwanding-infra
docker compose pull telegram-playwright telegram-bot
docker compose up -d telegram-playwright telegram-bot
```

## 注意事項

- Bot 使用 **webhook 模式**，`WEBHOOK_URL` 必須是 HTTPS 公網網址。
- **開發任務**需 `TELEGRAM_CURSOR_API_KEY`，且容器內 `/workspace` 必須能讀到程式碼。
- SQLite 資料在 volume `telegram_bot_data`，**勿隨意刪除**。
- 若只改 nginx conf，備份後 `nginx -t` → `reload` 即可，不必重建 bot 容器。

## Rollback

```bash
# 還原 nginx conf（見 docs/RESTORE.md）
# 或 pull 前一版 image tag 後 up -d
docker compose pull telegram-bot@sha256:<previous-digest>
docker compose up -d telegram-bot
```
