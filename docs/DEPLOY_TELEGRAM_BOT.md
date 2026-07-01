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
       ├─ ops    → HTTP Health Check（Docker 查詢預設停用）
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
LINE_OPENAI_API_KEY=sk-...             # 可選：僅 LINE bot 使用；未填則沿用 TELEGRAM_OPENAI_API_KEY
TELEGRAM_INTERNAL_API_SECRET=隨機字串
TELEGRAM_CURSOR_API_KEY=...          # 若要使用開發任務
TELEGRAM_LLM_MODEL=gpt-4o-mini
TELEGRAM_AGENT_MODEL=composer-2.5
TELEGRAM_INTENT_ROUTER=llm
TELEGRAM_DEV_BRIEF_REPLY=true
TELEGRAM_RUN_TIMEOUT_MS=600000
TELEGRAM_SCRAPE_MODE=inline
TELEGRAM_SCRAPE_TIMEOUT_MS=120000
TELEGRAM_WORKSPACE_HOST_PATH=/home/aiden/inwanding
TELEGRAM_DEFAULT_CWD=/workspace
TELEGRAM_ALLOWED_CWD_ROOTS=/workspace
TELEGRAM_WEBHOOK_URL=https://tgbot.inwanding.com/telegram/webhook

# ops（Phase 0A：Bot 不掛載 docker.sock）
TELEGRAM_OPS_ENABLED=true
TELEGRAM_OPS_DOCKER_ENABLED=false
TELEGRAM_OPS_ALLOWED_CONTAINERS=svc-telegram-bot,svc-telegram-playwright,svc-line-bot,edge-nginx
# 選填。以下 URL 的 service key 與 port 已從 docker-compose.yml 驗證：
TELEGRAM_OPS_HEALTH_URLS=http://api:3000/health,http://line-bot:3000/health,http://telegram-playwright:3100/health,http://telegram-bot:3001/health
TELEGRAM_OPS_COMMAND_TIMEOUT_MS=30000
TELEGRAM_OPS_LOG_TAIL_LINES=50
```

### `.env` 變數對照（避免填了但沒生效）

| infra `.env` key | 容器內 env key | 服務 | 說明 |
|---|---|---|---|
| `TELEGRAM_OPENAI_API_KEY` | `OPENAI_API_KEY` | `telegram-bot` | Telegram bot OpenAI 金鑰 |
| `LINE_OPENAI_API_KEY`（優先） / `TELEGRAM_OPENAI_API_KEY`（回退） | `OPENAI_API_KEY` | `line-bot` | LINE bot OpenAI 金鑰 |
| `TELEGRAM_CURSOR_API_KEY` | `CURSOR_API_KEY` | `telegram-bot` | Cursor SDK 開發任務 |
| `TELEGRAM_INTERNAL_API_SECRET` | `INTERNAL_API_SECRET` | `telegram-bot` | 內部 API 驗證 |
| `TELEGRAM_WEBHOOK_URL` | `WEBHOOK_URL` | `telegram-bot` | Telegram webhook 目標 URL |
| `TELEGRAM_OPS_ENABLED` | `OPS_ENABLED` | `telegram-bot` | 啟用 ops 意圖（Phase 1 查詢型操作） |
| `TELEGRAM_OPS_DOCKER_ENABLED` | `OPS_DOCKER_ENABLED` | `telegram-bot` | 啟用 `docker_ps` / `tail_logs`（**Production 應保持 false**） |
| `TELEGRAM_OPS_ALLOWED_CONTAINERS` | `OPS_ALLOWED_CONTAINERS` | `telegram-bot` | 逗號分隔容器白名單（遠端為 `svc-*` / `edge-nginx`） |
| `TELEGRAM_OPS_HEALTH_URLS` | `OPS_HEALTH_URLS` | `telegram-bot` | 逗號分隔 HTTP 健康檢查 URL |
| `TELEGRAM_OPS_COMMAND_TIMEOUT_MS` | `OPS_COMMAND_TIMEOUT_MS` | `telegram-bot` | 單次 ops 指令逾時（毫秒） |
| `TELEGRAM_OPS_LOG_TAIL_LINES` | `OPS_LOG_TAIL_LINES` | `telegram-bot` | `tail_logs` 預設行數 |

### ops 與安全邊界（Phase 0A）

**Production 的 `telegram-bot` 服務不得掛載 `/var/run/docker.sock`。**

`:ro` 掛載僅限制 socket 檔案本身的寫入，**無法**限制 Docker Engine API。Bot 容器若可連線 socket，等同具備 Host 高權限。

| action | 說明 | 預設狀態 |
|---|---|---|
| `check_health` | HTTP 健康檢查 | ✅ 啟用 |
| `docker_ps` | 容器狀態 | ⛔ 預設停用 |
| `tail_logs` | 容器最近 log | ⛔ 預設停用 |
| `disk_usage` | 主機磁碟 | ⛔ 已停用（無安全 Host 通道） |

**`TELEGRAM_OPS_HEALTH_URLS` 建議值（已從 compose service key 驗證）：**

| URL | compose service | port |
|-----|-----------------|------|
| `http://api:3000/health` | `api` | 3000 |
| `http://line-bot:3000/health` | `line-bot` | 3000 |
| `http://telegram-playwright:3100/health` | `telegram-playwright` | 3100 |
| `http://telegram-bot:3001/health` | `telegram-bot` | 3001 |

未設定時，bot 預設檢查自身與 playwright service。

**注意：**

- Docker 容器狀態／日誌若需恢復，應透過未來 **Ops Gateway**（獨立服務），而非 Bot 直連 socket。
- 查看 container log 請暫時 SSH 至主機：`docker compose logs --tail=50 <service>`

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
- **ops 查詢**預設僅 HTTP Health Check；**不得**為 Bot 掛載 docker.sock。
- SQLite 資料在 volume `telegram_bot_data`，**勿隨意刪除**。
- 若只改 nginx conf，備份後 `nginx -t` → `reload` 即可，不必重建 bot 容器。

## Rollback

```bash
# 部署前記錄 image（見下方 digest 指令）
IMAGE_ID=$(docker inspect svc-telegram-bot --format '{{.Image}}')
docker inspect svc-telegram-bot --format 'Configured image: {{.Config.Image}}'
docker image inspect "$IMAGE_ID" --format 'Image ID: {{.Id}} Digests: {{json .RepoDigests}}'

# 還原 nginx conf（見 docs/RESTORE.md）
# 或 pull 前一版 image 後 up -d
docker compose pull telegram-bot@sha256:<previous-digest>
docker compose up -d telegram-bot
```

## Phase 0A 部署後驗證（唯讀）

```bash
# 確認 Bot 不再掛載 docker.sock
docker inspect svc-telegram-bot --format '{{json .Mounts}}'
# 預期：輸出中不應含 /var/run/docker.sock

# 確認 Docker Ops 已停用
docker exec svc-telegram-bot printenv OPS_DOCKER_ENABLED
# 預期：false

# 確認 image 不含 docker CLI（需新 image 部署後）
docker exec svc-telegram-bot sh -lc 'command -v docker || true'
# 預期：無輸出

# 健康檢查（經 edge-nginx）
curl -sS http://127.0.0.1:8080/health -H "Host: tgbot.inwanding.com"
```
