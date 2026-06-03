# 部署 SOP（DEPLOY）

適用目錄：`~/inwanding-infra`  
適用主機：正式 Ubuntu（`web-ubuntu`）  
Cloudflare Tunnel：**不在此流程修改**（維持指向 `http://127.0.0.1:8080`）。

## 部署前檢查

- [ ] 目前在 repo 根目錄：`cd ~/inwanding-infra`
- [ ] `.env` 存在且變數完整（對照 `.env.example`）
- [ ] 正式容器由本 compose 管理：`docker compose ps` 應見 `edge-nginx`、`svc-web`、`svc-api`、`svc-postgres`
- [ ] 無計畫中的 DB volume 異動（`nginx_pg_data` 保持 `external: true`）
- [ ] 若會改 Nginx conf：已先執行 `./scripts/backup-nginx-conf.sh`

## Compose 設定驗證

僅驗證語法與合併結果，不啟動新服務：

```bash
cd ~/inwanding-infra
docker compose config
```

確認輸出中：

- `nginx` 對外為 `127.0.0.1:8080:80`
- `db` volume 為 `nginx_pg_data`

## 標準部署流程（pull + up）

建議使用腳本（內含檢查步驟）：

```bash
./scripts/deploy.sh
```

或手動執行：

```bash
cd ~/inwanding-infra
docker compose pull          # 僅影響有 image 變更的服務（如 api）
docker compose up -d         # 依 diff 重建/重啟容器
docker compose ps
```

**注意：**

- `up -d` 可能短暫重啟 `svc-api`；`edge-nginx` 若僅 conf 變更可優先只 reload（見下節）。
- 不要在此流程修改 `.env` 內容，除非已評估影響並有 DB/設定備份。

## 僅變更 Nginx 設定時

1. 編輯 `nginx/conf.d/default.conf`
2. 備份：`./scripts/backup-nginx-conf.sh`
3. 測試與 reload：

```bash
docker exec edge-nginx nginx -t
docker exec edge-nginx nginx -s reload
```

bind mount 為唯讀；改主機檔後不需重建 `edge-nginx` 容器。

## 部署後驗證

```bash
# 本機（繞過 Cloudflare，直接打 edge-nginx）
curl -sI -H "Host: inwanding.com" http://127.0.0.1:8080/
curl -sI -H "Host: www.inwanding.com" http://127.0.0.1:8080/
curl -sI -H "Host: api.inwanding.com" http://127.0.0.1:8080/health
curl -sI -H "Host: not-exist.inwanding.com" http://127.0.0.1:8080/   # 預期 404

# 公網（經 Tunnel + Cloudflare）
curl -sI https://inwanding.com/
curl -sI https://www.inwanding.com/
curl -sI https://api.inwanding.com/health

# 日誌
docker compose logs --tail=50 nginx api
```

API 根路徑 `/` 回 404 若應用未實作屬正常；以 `/health` 為準。

## Rollback 概念

| 變更類型 | 還原方式 |
|----------|----------|
| Nginx conf | 從 `backups/nginx-conf.d/` 還原檔案 → `nginx -t` → `reload`（見 [RESTORE.md](RESTORE.md)） |
| Compose / image | `docker compose pull` 前一版 image tag，或還原 `docker-compose.yml` git commit 後 `up -d` |
| `.env` | 還原備份檔後 `docker compose up -d`（可能重啟 api/db，**高風險**） |
| DB 資料 | 見 [RESTORE.md](RESTORE.md)；**勿**在未停服與確認前覆寫 volume |

建議每次部署前：`git commit` 或至少備份 conf，以便對照 diff。
