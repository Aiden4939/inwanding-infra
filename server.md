# Web Core 伺服器狀態（server.md）

> **Single Source of Truth** for `web-ubuntu` Web Core infra.  
> **最後更新：** 2026-06-04 UTC  
> **詳細 SOP：** 見本 repo `README.md`、`docs/DEPLOY.md`、`docs/RESTORE.md`、`docs/ROADMAP.md`

---

## 主機

| 項目 | 值 |
|------|-----|
| 主機名 | `web-ubuntu` |
| 角色 | Web Core（edge nginx + API + PostgreSQL + Cloudflare Tunnel） |
| RAM | 4GB（規劃 ≥6GB，見 ROADMAP P2-6，**尚未執行**） |

---

## 正式 Infra 目錄

| 項目 | 路徑 / 值 |
|------|-----------|
| Compose | `~/inwanding-infra/docker-compose.yml` |
| Nginx conf | `~/inwanding-infra/nginx/conf.d/default.conf` |
| 環境變數 | `~/inwanding-infra/.env`（**勿提交 git**） |
| Git remote | `git@github.com:Aiden4939/inwanding-infra.git`（SSH） |
| SSH key | `~/.ssh/id_ed25519_github_inwanding` |
| 舊目錄（僅參考） | `~/infra/nginx` — **勿用此 compose 操作正式服務** |

---

## 流量架構

```
Internet
  → cloudflared（/etc/cloudflared/config.yml）
  → 127.0.0.1:8080（edge-nginx）
       ├─ inwanding.com / www.inwanding.com → svc-web:80（whoami 占位）
       ├─ api.inwanding.com                 → svc-api:3000
       └─ 其他 Host（default_server）       → 404
  → svc-api → svc-postgres（volume: nginx_pg_data）
```

---

## 容器

| 容器 | 服務 | 備註 |
|------|------|------|
| `edge-nginx` | nginx | `127.0.0.1:8080→80` |
| `svc-web` | web | `traefik/whoami` 占位 |
| `svc-api` | api | `ghcr.io/aiden4939/inwanding-api:latest` |
| `svc-postgres` | db | PostgreSQL 16 |

**殘留（不影響 8080）：** `app-whoami`（舊 compose project `nginx`，待 P2-2 決策）。

---

## 資料庫

- **正式 volume：** `nginx_pg_data`（compose 別名 `pg_data`，`external: true`）
- **Database / user：** `appdb` / `appuser`
- **歷史 volume `pg_data`：** 可能存在，正式 stack **未掛載**；刪除前需比對（P2-1）

---

## 備份（本機，`backups/` 不進 git）

| 類型 | 腳本 | 目錄 | 狀態 |
|------|------|------|------|
| Nginx conf | `./scripts/backup-nginx-conf.sh` | `backups/nginx-conf.d/` | 已驗證 |
| PostgreSQL | `./scripts/backup-db-volume.sh` | `backups/postgres/` | **2026-06-04 首次正式備份** |

**最新 DB 備份：**

- `~/inwanding-infra/backups/postgres/appdb_20260604T040732Z.sql.gz`（372B gzip）
- 當時 `appdb` 幾無 user tables；migration 後應定期重跑備份

還原 SOP：`docs/RESTORE.md`（**高風險**，需批准）。

---

## 部署與認證

- 部署：`docs/DEPLOY.md`、`./scripts/deploy.sh`
- **Git：** SSH（與 MCP PAT **已分離**）
- **GitHub MCP：** `~/.cursor/mcp.json`（PAT **尚未 revoke**，安全整理待定）

---

## 健康檢查（快速）

```bash
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health   # 200
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 404
docker compose -f ~/inwanding-infra/docker-compose.yml ps
```

---

## 下一步（ROADMAP 摘要）

1. P1-3：備份保留策略  
2. P1-4：`deploy.sh` 演練  
3. P2-6：RAM 升級（需批准）  
4. P2-1 / P2-2：`pg_data` 調查、`app-whoami` 清理（需批准）  
5. P3-1：正式 frontend 取代 whoami  

---

## 修訂紀錄

| 日期 | 摘要 |
|------|------|
| 2026-06-04 | 初版 SST：inwanding-infra 接管、nginx 404 fallback、git SSH、P1-1 DB 備份 |
