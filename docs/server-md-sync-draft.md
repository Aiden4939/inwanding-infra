# server.md 同步草稿（P2-5）

> **用途：** 供你複製到專案 SST `server.md`（本機未找到該檔路徑，請自行貼到正確位置）。  
> **對照日期：** 2026-06-04 UTC  
> **來源：** `~/inwanding-infra` repo 文件與現場檢查

---

## 建議更新章節一覽

| 章節（建議標題） | 動作 | 原因 |
|------------------|------|------|
| 主機 / 環境 | 修改 | 確認主機名 `web-ubuntu`、RAM 仍 4GB（P2-6 未做） |
| 正式 Infra 路徑 | **新增或改寫** | 單一真相改為 `~/inwanding-infra` |
| Stack 架構 | 修改 | tunnel → nginx → web/api/db |
| Nginx / 路由 | 修改 | 未知 Host → 404（`default_server`） |
| 資料庫 | 修改 | volume `nginx_pg_data`；非 `pg_data` |
| 備份與還原 | **新增或改寫** | nginx conf + 首次 DB dump 已完成 |
| Git / 部署 | 修改 | remote SSH；GitHub repo；勿用舊 `~/infra/nginx` |
| 認證 / 安全 | 新增（簡短） | git 已 SSH；MCP PAT 與 git 分離（PAT 未 revoke） |
| 下一步 | 修改 | 對齊 ROADMAP P1-3+ |

---

## 建議正文（可整段貼入或改寫）

### 主機

- **主機名：** `web-ubuntu`
- **角色：** Web Core（edge nginx + API + PostgreSQL + tunnel）
- **RAM：** 4GB（規劃升至 ≥6GB，見 ROADMAP P2-6，尚未執行）

### 正式 Infra 目錄（Single Source of Truth for compose）

| 項目 | 路徑 / 值 |
|------|-----------|
| Compose | `~/inwanding-infra/docker-compose.yml` |
| Nginx conf | `~/inwanding-infra/nginx/conf.d/default.conf` |
| 環境變數 | `~/inwanding-infra/.env`（**勿提交 git**） |
| Infra Git repo | `git@github.com:Aiden4939/inwanding-infra.git` |
| 舊目錄（僅參考） | `~/infra/nginx` — **勿用此 compose 操作正式服務** |

### 流量架構

```
Internet
  → cloudflared（/etc/cloudflared/config.yml）
  → 127.0.0.1:8080（edge-nginx）
       ├─ inwanding.com / www.inwanding.com → svc-web:80（目前 whoami 占位）
       ├─ api.inwanding.com                 → svc-api:3000
       └─ 其他 Host（default_server）       → 404
  → svc-api → svc-postgres（Docker volume: nginx_pg_data）
```

### 容器一覽

| 容器 | 服務 | 備註 |
|------|------|------|
| `edge-nginx` | nginx | `127.0.0.1:8080→80` |
| `svc-web` | web | `traefik/whoami` 占位 |
| `svc-api` | api | `ghcr.io/aiden4939/inwanding-api:latest` |
| `svc-postgres` | db | PostgreSQL 16 |

殘留（不影響 8080）：`app-whoami`（舊 project `nginx`，待 ROADMAP P2-2 決策）。

### 資料庫

- **正式 volume：** `nginx_pg_data`（compose 內別名 `pg_data`，`external: true`）
- **DB：** `appdb` / user `appuser`
- **歷史 volume `pg_data`：** 可能存在，正式 stack **未掛載**；刪除前需比對（P2-1）

### 備份策略（本機）

| 類型 | 腳本 | 輸出目錄 | 狀態 |
|------|------|----------|------|
| Nginx conf | `./scripts/backup-nginx-conf.sh` | `backups/nginx-conf.d/` | 已驗證 |
| PostgreSQL | `./scripts/backup-db-volume.sh` | `backups/postgres/` | **2026-06-04 首次正式備份完成** |

**首次 DB 備份紀錄：**

- 檔案：`~/inwanding-infra/backups/postgres/appdb_20260604T040732Z.sql.gz`
- 大小：372 bytes（gzip）
- 說明：當時 `appdb` 幾無 user tables，dump 偏小屬正常；日後有 migration 後備份會變大

`backups/` **不進 git**。還原見 `inwanding-infra/docs/RESTORE.md`（還原為高風險，需批准）。

### 部署與 Git

- 部署 SOP：`~/inwanding-infra/docs/DEPLOY.md`
- 標準部署：`./scripts/deploy.sh`（需維護窗口意識）
- **Git push：** SSH（`~/.ssh/id_ed25519_github_inwanding`）
- **GitHub MCP：** 仍可能使用 PAT（`~/.cursor/mcp.json`）；與 git **已分離**；PAT **尚未 revoke**（安全整理進行中）

### 健康檢查（快速）

```bash
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health   # 200
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 404
docker compose -f ~/inwanding-infra/docker-compose.yml ps
```

### 下一步（與 ROADMAP 對齊）

1. P1-3：備份保留策略 / 可選 cron  
2. P1-4：`deploy.sh` 演練  
3. P2-5：將本草稿併入正式 `server.md` 後刪減重複  
4. P2-6：RAM 4GB → ≥6GB（需批准）  
5. P2-1 / P2-2：`pg_data` 調查、`app-whoami` 清理（需批准）  
6. P3-1：正式 frontend 取代 whoami  

### 修訂紀錄（server.md 內建議保留）

| 日期 | 變更摘要 |
|------|----------|
| 2026-06-04 | 對齊 inwanding-infra：P1-1 DB 備份、git SSH、nginx default_server |

---

## 與舊版 server.md 常見差異（請自行核對）

若舊版仍寫以下內容，應改為現況：

- [ ] 正式 compose 在 `~/infra/nginx` → 改為 `~/inwanding-infra`
- [ ] DB volume 名為 `pg_data` only → 改為 **`nginx_pg_data`**
- [ ] 未知 Host 可能 200 → 已改 **404**（`default_server`）
- [ ] 無 DB 備份紀錄 → 補上 **2026-06-04** 首次 dump
- [ ] git HTTPS only → 改 **SSH remote**
- [ ] 無 GitHub repo → 補 `Aiden4939/inwanding-infra`

---

## 檔案位置

請將上述內容合併進你的 **`server.md` 實際路徑**（本 agent 在 `web-ubuntu` 的 `/home/aiden` 下**未找到** `server.md`）。  
合併完成後可刪除或縮短本草稿檔，避免雙 SST。
