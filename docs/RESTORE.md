# 還原 SOP（RESTORE）

本文描述還原流程與注意事項。標有 **（僅 SOP，勿在未確認前執行）** 的步驟請先在測試環境或維護窗口演練，並由負責人批准。

## 備份檔位置（本 repo）

| 類型 | 預設路徑 | 產生方式 |
|------|----------|----------|
| Nginx conf | `~/inwanding-infra/backups/nginx-conf.d/<檔名>.<UTC>.bak` | `./scripts/backup-nginx-conf.sh` |
| PostgreSQL dump | `~/inwanding-infra/backups/postgres/appdb_<UTC>.sql.gz` | `./scripts/backup-db-volume.sh`（**2026-06-04 正式試跑成功**） |

`backups/` 目錄在 `.gitignore` 中，**不會**進版控。

Nginx 備份腳本行為摘要：從 `nginx/conf.d/` 複製到 `backups/nginx-conf.d/`，檔名附加 UTC 時間戳（如 `default.conf.20260603T094039Z.bak`），**不刪除**舊 `.bak`。

正式 DB 資料仍在 Docker volume：**`nginx_pg_data`**（掛載於 `svc-postgres:/var/lib/postgresql/data`）。

另有歷史 volume `pg_data` 可能存在於主機上，**目前正式 stack 未使用**；在未比對前勿刪除。

---

## 1. Nginx 設定還原

### 適用情境

誤改 `nginx/conf.d/default.conf` 導致路由錯誤或 502。

### 步驟

```bash
cd ~/inwanding-infra

# 1) 列出備份（新到舊）
ls -lt backups/nginx-conf.d/
# 例：default.conf.20260603T094039Z.bak

# 2) 覆寫前先備份「目前」狀態（避免還原錯版本）
./scripts/backup-nginx-conf.sh

# 3) 設定要還原的檔案（請改成實際檔名）
BACKUP=backups/nginx-conf.d/default.conf.20260603T094039Z.bak
TARGET=nginx/conf.d/default.conf

# 4) 還原前可先比對差異
diff -u "$TARGET" "$BACKUP" || true

# 5) 還原
cp -a "$BACKUP" "$TARGET"

# 6) 驗證並 reload（失敗則不要 reload）
docker exec edge-nginx nginx -t
docker exec edge-nginx nginx -s reload

# 7) 驗證（見 DEPLOY.md）
curl -sI -H "Host: inwanding.com" http://127.0.0.1:8080/
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 預期 404
```

不需重建 `edge-nginx` 容器（bind mount 會反映主機檔案）。還原僅影響主機上的 conf 檔，**在 `nginx -t` 成功前不要 reload**。

---

## 2. PostgreSQL 還原（邏輯備份：pg_dump）

### 還原前應先確認

- [ ] 已取得正確的 `.sql.gz` 備份檔與時間點
- [ ] 了解還原會**覆寫**目前 `appdb` 內資料
- [ ] 已通知維護窗口（API 會短暫不可用）

### 建議停用的服務順序

為避免還原時仍有寫入，建議：

1. 停止寫入端：`docker stop svc-api`（或 `docker compose stop api`）
2. （可選）僅讀需求時可保留 `edge-nginx`，對外可能回 502/503
3. **不要**在還原過程中刪除 volume `nginx_pg_data`

還原完成後：

```bash
docker compose start api
# 或 docker compose up -d
```

### 還原指令範本 **（僅 SOP，勿在未確認前執行）**

```bash
BACKUP_FILE=~/inwanding-infra/backups/postgres/appdb_YYYYMMDDTHHMMSSZ.sql.gz

# 確認檔案存在
ls -l "$BACKUP_FILE"

docker stop svc-api

gunzip -c "$BACKUP_FILE" | docker exec -i svc-postgres \
  psql -U appuser -d appdb

docker start svc-api
```

還原後驗證：

```bash
docker exec svc-postgres psql -U appuser -d appdb -c 'SELECT 1;'
curl -s -H "Host: api.inwanding.com" http://127.0.0.1:8080/health
```

---

## 3. Volume 層級還原 **（僅 SOP，高風險）**

適用於整個 volume 損毀、需從離線副本還原的極端情況。

**（僅 SOP，勿在未確認前執行）**

1. 停止依賴 DB 的所有服務：`docker compose stop api db nginx`（依實際維護策略調整）
2. 確認替代資料來源（例如另一台主機複製的 `_data` 目錄或 volume 匯出檔）
3. 在**不刪除**現有 `nginx_pg_data` 前，先重新命名備份舊 volume 或做完整檔案系統快照
4. 將資料放回 `/var/lib/docker/volumes/nginx_pg_data/_data`（需 root，且 Docker 未掛載該 volume）
5. `docker compose up -d` 並完整跑 DEPLOY 驗證章節

未經演練不要執行 volume 覆寫。

---

## 4. 還原前檢查清單（通用）

- [ ] 已記錄目前 `docker compose ps` 與 image digest
- [ ] 已有 Nginx conf 與 DB 備份
- [ ] 已確認 Cloudflare Tunnel 仍指向 `127.0.0.1:8080`（通常無需變更）
- [ ] 已排除誤用 `~/infra/nginx` 舊 compose
- [ ] 還原步驟有第二人覆核或維護單號

## 5. 不屬於本 SOP 的項目

- 刪除 `app-whoami`、`pg_data` volume — 需另案確認
- 修改 `/etc/cloudflared/config.yml` — 僅在 tunnel 路由變更時處理
- 移動或刪除 `~/infra/nginx` — 不在此還原流程
