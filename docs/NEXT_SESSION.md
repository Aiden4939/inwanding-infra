# 下次對話接手指南（NEXT_SESSION）

> **用途：** 下次開工先讀本檔，再接 `server.md` 與 `docs/ROADMAP.md`。  
> **最後更新：** 2026-06-30  
> **遠端 main：** 見 `git log -1`（`Aiden4939/inwanding-infra`）

---

## LINE Reminder Bot 部署（2026-06-24）

| 項目 | 狀態 |
|------|------|
| compose：`line-bot` + `line-bot-db` + OpenAI/Flex env | ✅ `04bb0ab`, `2408de5` |
| OpenAI key 共用 `TELEGRAM_OPENAI_API_KEY` | ✅ `2408de5` |
| NLU 畸形 datetime 靜默失敗修復 | ✅ `line-reminder-bot` `2e337d8`（**待 redeploy**） |
| 使用者 deploy `line-bot` | ✅ 已部署 |
| Rich Menu | ❌ **需手動** `npm run setup-rich-menu` |
| Flex 卡片 | ⚠️ 查詢提醒 + 有待發送提醒 |

**下一手：**

1. 等 GHCR build 完成 → `git pull` → redeploy `line-bot`
2. 主機 `.env` 確認 `TELEGRAM_OPENAI_API_KEY`
3. Rich Menu / 測試：見 **`line-reminder-bot/docs/NEXT_SESSION.md`**

Bot 專案接手：**`line-reminder-bot/docs/NEXT_SESSION.md`**

---

## Telegram Agent Bot 部署（2026-06-25，進行中）

| 項目 | 狀態 |
|------|------|
| compose / nginx / deploy workflow 已 commit | ✅ `05162e4` |
| GHCR image（telegram-agent-bot repo） | ✅ push main 觸發建置 |
| compose 已補 Cloud dev env 映射（`DEV_RUNTIME`、`CLOUD_*`） | ✅ `63d545a` |
| `.env.example` 已補 Cloud dev 參數與說明 | ✅ `63d545a` |
| compose ops Phase 1（`OPS_*` env + docker.sock） | ✅ 2026-06-30 |
| `.env.example` / `DEPLOY_TELEGRAM_BOT.md` ops 說明 | ✅ 2026-06-30 |
| `telegram-agent-bot` ops Phase 1 image | ⏳ `feat/ops-phase1-executor` **待 merge** |
| 主機 `git pull` + `.env` + tunnel | ⏳ **待做** |
| GitHub Action deploy `telegram-bot` | ❌ 曾失敗：`no such service: telegram-playwright`（主機 compose 過期） |

**下一手：**

1. SSH `web-ubuntu` → `cd ~/inwanding-infra && git pull`
2. `.env` 補齊 Cloud dev 必填（至少 `TELEGRAM_CLOUD_REPOS`）
3. `.env` 補齊 ops 參數（`TELEGRAM_OPS_*`，對照 `.env.example`）
4. `docker compose config` 確認 `DEV_RUNTIME`、`CLOUD_*`、`OPS_*`、docker.sock 掛載
5. `./scripts/setup-telegrambot-tunnel.sh`（首次）
6. 等 `telegram-agent-bot` ops image merge → Actions **Deploy Service (Manual)** → `telegram-bot`
7. Telegram 測試 ops 查詢（容器狀態、log、磁碟、健康檢查）

詳見 **[docs/DEPLOY_TELEGRAM_BOT.md](DEPLOY_TELEGRAM_BOT.md)**。  
Bot 專案接手：**`telegram-agent-bot/docs/NEXT_SESSION.md`**

---

## A. 目前做到哪裡（Web Core）

- 正式 stack 已由 `~/inwanding-infra/docker-compose.yml` 接管（`edge-nginx`、`svc-web`、`svc-api`、`svc-postgres`）
- Nginx 未知 Host → **404**（`default_server` 已修正）
- 健康檢查通過（本機 + 公網 `/health`）
- Git repo 建立、文件化、**SSH remote**、`origin/main` 已同步
- **P0-1** Phase 6 文件 commit — 完成
- **P0-2** Git remote + push — 完成
- **P1-1** 首次正式 DB `pg_dump` 備份 — 完成（2026-06-04）
- **P2-5** `server.md` SST 建立（本里程碑）— 完成
- nginx conf 備份腳本 — 已驗證
- git push 與 MCP PAT — **已分離**（PAT 未 revoke，安全整理暫緩）

---

## B. 目前正式真實狀態

| 項目 | 值 |
|------|-----|
| 主機 | `web-ubuntu` |
| 正式 compose | `~/inwanding-infra/docker-compose.yml` |
| Git remote | `git@github.com:Aiden4939/inwanding-infra.git`（SSH） |
| SSH key | `~/.ssh/id_ed25519_github_inwanding` |
| DB volume | **`nginx_pg_data`**（compose 別名 `pg_data`，external） |
| Tunnel | `/etc/cloudflared/config.yml` → `127.0.0.1:8080`（**勿改，除非驗證失敗**） |
| Nginx conf | `~/inwanding-infra/nginx/conf.d/default.conf` |

**備份現況（本機，`backups/` 不進 git）：**

| 類型 | 最新紀錄 |
|------|----------|
| Nginx conf | `backups/nginx-conf.d/*.bak`（腳本已驗證） |
| PostgreSQL | `backups/postgres/appdb_20260604T040732Z.sql.gz`（372B；DB 幾無 user tables） |

**占位 / 殘留：**

- `svc-web` → `traefik/whoami`（**非正式前端**）
- `app-whoami` → 舊 project 殘留，**不影響 8080**
- volume `pg_data` → 可能存在，**正式 stack 未使用**

**文件狀態：** README、DEPLOY、RESTORE、ROADMAP、`server.md` 已同步；`deploy.sh` 有骨架、**尚未演練**；DB **還原 SOP 未演練**。

---

## C. 下一次應先做什麼

**依序優先（建議）：**

1. **P1-3** — 備份保留策略（文件化即可開始；cron 需批准）
2. **P1-4** — `deploy.sh` 維護窗口演練（需批准）
3. **P2-1** — `pg_data` volume 只讀調查（低風險）

**先做：** P1-3（低風險、補齊維運政策）  
**不要先做：**

- P1-2 DB 還原演練（**高風險**）
- P2-2 刪 `app-whoami`、刪 `pg_data`（需批准）
- P2-6 RAM 升級、P3 監控導入（需批准 / 較大變更）
- MCP PAT revoke / 清 History（安全整理後續，暫緩）

---

## D. 哪些事先不要碰

- 刪除 **`nginx_pg_data`**
- 修改 **`.env`**、**cloudflared**、**nginx conf**、**compose 拓樸**（除非明確新任務）
- **DB restore** 或未批准之 volume 覆寫
- **revoke** 現有 MCP PAT（git 已改 SSH，但 MCP 仍可能依賴）
- 刪 **`~/infra/nginx`**、**`app-whoami`**、**`pg_data`**（未批准前）

---

## E. 下次開工前先讀哪些文件

1. **[docs/NEXT_SESSION.md](NEXT_SESSION.md)**（本檔）
2. **[server.md](../server.md)** — SST 現況
3. **[docs/ROADMAP.md](ROADMAP.md)** — 完整規劃與批准項
4. **[README.md](../README.md)** — 日常指令與禁止事項
5. 若要做部署/備份：**[DEPLOY.md](DEPLOY.md)**、**[RESTORE.md](RESTORE.md)**

---

## F. 一句話交接摘要

`web-ubuntu` 上 Web Core 已由 **`~/inwanding-infra`** 正式接管，流量為 cloudflared → nginx:8080 → web/api，DB 在 **`nginx_pg_data`**。Infra 已文件化並 push 至 GitHub（**SSH**），首次 **DB 與 nginx 備份腳本皆已驗證**。`server.md` 為 SST。下一主線是 **P1-3 備份保留策略**，再來 **P1-4 deploy 演練**；高風險還原、刪除殘留、RAM、監控、MCP 安全收尾均**暫緩**待批准。
