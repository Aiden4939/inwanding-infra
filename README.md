# inwanding-infra

Web Core 基礎設施設定庫：Docker Compose、Nginx 邊界代理、PostgreSQL volume 宣告與維運文件。

正式環境由本目錄的 `docker-compose.yml` 接管；Cloudflare Tunnel 將公網流量轉到本機 `127.0.0.1:8080`。

## 正式架構

```
Internet
  → cloudflared（/etc/cloudflared/config.yml）
  → 127.0.0.1:8080（edge-nginx）
       ├─ inwanding.com / www.inwanding.com → svc-web:80
       ├─ api.inwanding.com                 → svc-api:3000
       └─ 其他 Host（default_server）       → 404
  → svc-api → svc-postgres（volume: nginx_pg_data）
```

| 容器 | 用途 |
|------|------|
| `edge-nginx` | 反向代理、Host 分流 |
| `svc-web` | 前端（目前為 whoami 占位） |
| `svc-api` | API（`ghcr.io/aiden4939/inwanding-api:latest`） |
| `svc-postgres` | PostgreSQL 16 |

## 目錄結構

```
inwanding-infra/
├── docker-compose.yml    # 正式 stack 定義
├── .env.example          # 環境變數範例（可提交）
├── .env                  # 正式密碼（勿提交，見 .gitignore）
├── nginx/conf.d/         # Nginx 設定（bind mount 進 edge-nginx）
├── scripts/              # 備份、部署腳本
├── docs/                 # DEPLOY / RESTORE SOP
└── backups/              # 本機備份輸出（勿提交 git）
```

## 正式路徑對照

| 項目 | 路徑 |
|------|------|
| Compose | `~/inwanding-infra/docker-compose.yml` |
| Nginx conf | `~/inwanding-infra/nginx/conf.d/default.conf` |
| 環境變數 | `~/inwanding-infra/.env` |
| DB Docker volume | `nginx_pg_data`（compose 內別名 `pg_data`，`external: true`） |
| Cloudflare Tunnel | `/etc/cloudflared/config.yml`（系統層，不在此 repo） |

舊目錄 `~/infra/nginx` 僅供歷史參考，**請勿**以此目錄的 compose 操作正式服務。

## 日常常用指令

在 repo 根目錄執行：

```bash
cd ~/inwanding-infra

# 狀態
docker compose ps
docker compose logs -f nginx
docker compose logs -f api

# 驗證 Nginx（不 reload）
docker exec edge-nginx nginx -t

# 本機 HTTP 檢查（經 edge-nginx）
curl -sI -H "Host: inwanding.com" http://127.0.0.1:8080/
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 預期 404

# 部署（詳見 docs/DEPLOY.md）
./scripts/deploy.sh
```

## 備份腳本（需手動執行）

```bash
./scripts/backup-nginx-conf.sh
./scripts/backup-db-volume.sh   # 執行前請閱讀腳本註解與 docs/RESTORE.md
```

腳本**不會**自動排程；請勿在未確認前加入 cron。

## 禁止事項

- **不要刪除** Docker volume `nginx_pg_data`（正式 DB 資料）。
- **不要提交** `.env` 或 `backups/` 內容到 git。
- **不要在未備份前**直接覆寫 `nginx/conf.d/*.conf`；改動後務必 `nginx -t` 再 reload。
- **不要**用 `~/infra/nginx` 的 compose 取代本 repo 操作正式 stack。
- **不要**在未確認前刪除其他容器（例如 `app-whoami`）或 volume（例如 `pg_data`）。

## 相關文件

- [docs/DEPLOY.md](docs/DEPLOY.md) — 部署與驗證流程
- [docs/RESTORE.md](docs/RESTORE.md) — 還原 SOP（含僅供參考的進階步驟）
