# Web Core 伺服器狀態（server.md）

> **Single Source of Truth** for `web-ubuntu` Web Core infra.  
> **最後更新：** 2026-06-04 UTC  
> **接手入口：** [docs/NEXT_SESSION.md](docs/NEXT_SESSION.md)  
> **詳細 SOP：** `README.md`、`docs/DEPLOY.md`、`docs/RESTORE.md`、`docs/ROADMAP.md`

---

## 里程碑摘要（目前已完成）

| 項目 | 狀態 |
|------|------|
| 正式 stack 由 `~/inwanding-infra/docker-compose.yml` 接管 | ✅ |
| DB volume `nginx_pg_data`（external） | ✅ |
| Nginx 未知 Host → 404（`default_server`） | ✅ |
| 健康檢查（本機 + 公網） | ✅ |
| Git repo + 文件（README / DEPLOY / RESTORE / ROADMAP） | ✅ |
| **P0-1** 文件 commit | ✅ |
| **P0-2** GitHub remote + push | ✅（SSH：`git@github.com:Aiden4939/inwanding-infra.git`） |
| **P1-1** 首次正式 DB 備份 | ✅ 2026-06-04 |
| **P2-5** 本階段 `server.md` 同步 | ✅ |
| nginx / DB 備份腳本試跑 | ✅ |
| git push 與 MCP PAT 分離 | ✅（PAT 未 revoke） |

---

## 主機

| 項目 | 值 |
|------|-----|
| 主機名 | `web-ubuntu` |
| 角色 | Web Core（edge nginx + API + PostgreSQL + Cloudflare Tunnel + tailscaled） |
| RAM | 4GB（規劃 ≥6GB，ROADMAP **P2-6**，**尚未執行**） |

---

## 正式 Infra 目錄

| 項目 | 路徑 / 值 |
|------|-----------|
| Compose | `~/inwanding-infra/docker-compose.yml` |
| Nginx conf | `~/inwanding-infra/nginx/conf.d/default.conf` |
| 環境變數 | `~/inwanding-infra/.env`（**勿提交 git**） |
| Git remote | `git@github.com:Aiden4939/inwanding-infra.git`（**SSH**） |
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
| `svc-web` | web | `traefik/whoami` **占位** |
| `svc-api` | api | `ghcr.io/aiden4939/inwanding-api:latest` |
| `svc-postgres` | db | PostgreSQL 16 |

**殘留（不影響 8080）：** `app-whoami`（舊 project `nginx`，ROADMAP **P2-2**，待批准）。

---

## 資料庫

- **正式 volume：** `nginx_pg_data`（compose 別名 `pg_data`，`external: true`）
- **Database / user：** `appdb` / `appuser`
- **歷史 volume `pg_data`：** 可能存在，正式 stack **未掛載**（ROADMAP **P2-1** 只讀調查）

---

## 備份與文件（本機 `backups/` 不進 git）

| 類型 | 腳本 | 目錄 | 狀態 |
|------|------|------|------|
| Nginx conf | `./scripts/backup-nginx-conf.sh` | `backups/nginx-conf.d/` | ✅ 已驗證 |
| PostgreSQL | `./scripts/backup-db-volume.sh` | `backups/postgres/` | ✅ **2026-06-04 首次正式備份** |

**最新 DB 備份：** `backups/postgres/appdb_20260604T040732Z.sql.gz`（372B gzip；當時幾無 user tables）

| 文件 | 狀態 |
|------|------|
| `docs/DEPLOY.md` | ✅ 可用；`deploy.sh` **尚未演練**（P1-4） |
| `docs/RESTORE.md` | ✅ 可用；DB 還原 **未演練**（P1-2，高風險） |
| `docs/ROADMAP.md` | ✅ 追蹤中 |
| `docs/NEXT_SESSION.md` | ✅ 下次接手 |

還原：**高風險**，需批准（見 RESTORE.md）。

---

## 部署與認證

- 標準部署：`./scripts/deploy.sh` + `docs/DEPLOY.md`（**演練待 P1-4**）
- **Git push：** SSH（與 MCP PAT **已分離**）
- **GitHub MCP：** `~/.cursor/mcp.json`（PAT **尚未 revoke**；安全整理**暫緩**）
- **Cloudflare Tunnel：** 指向 `127.0.0.1:8080`，**目前勿改**

---

## 尚未完成（摘要）

| 類別 | 項目 |
|------|------|
| 維運 | P1-3 備份保留策略；P1-4 deploy 演練 |
| 高風險 | P1-2 DB 還原演練 |
| 清理 | P2-1 `pg_data` 調查；P2-2 `app-whoami`；P2-3 舊目錄定位 |
| 主機 | P2-6 RAM 4GB→≥6GB |
| 產品 | P3-1 正式 web 取代 whoami |
| 可觀測 | P3-3 監控告警落地 |
| 安全 | MCP PAT 後續整理（revoke / env / History）— **暫緩** |

---

## 下一階段主線（建議）

1. **P1-3** — 備份保留策略（低風險，可先文件化）
2. **P1-4** — `deploy.sh` 演練（需維護窗口、需批准）
3. **P2-1** — `pg_data` 只讀調查

詳見 [docs/NEXT_SESSION.md](docs/NEXT_SESSION.md) 與 [docs/ROADMAP.md](docs/ROADMAP.md)。

---

## 健康檢查（快速）

```bash
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health   # 200
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 404
docker compose -f ~/inwanding-infra/docker-compose.yml ps
```

---

## 修訂紀錄

| 日期 | 摘要 |
|------|------|
| 2026-06-04 | 初版 SST：stack 接管、404 fallback、git SSH、P1-1 備份 |
| 2026-06-04 | 收尾：里程碑表、未完成項、下一主線、NEXT_SESSION 連結 |
