# Web Core Infra 後續規劃（ROADMAP）

適用 repo：`~/inwanding-infra`  
主機：`web-ubuntu`  
最後對照現況：2026-06-04

本文僅為規劃與追蹤，**不代表已排程執行**。實際操作前請依各項「是否需要批准」與 SOP 進行。

---

## 目前已完成（Baseline）

| 項目 | 狀態 |
|------|------|
| 正式 stack 由 `~/inwanding-infra/docker-compose.yml` 接管 | 完成 |
| DB volume 沿用 `nginx_pg_data`（external） | 完成 |
| Nginx 未知 Host → 404（`default_server`） | 完成 |
| Phase 3 健康檢查（本機 + 公網 /health） | 完成 |
| Git init、首次 commit（`d34b343`） | 完成 |
| README / DEPLOY / RESTORE 初稿 | 完成 |
| `scripts/backup-nginx-conf.sh` 試跑驗證 | 完成 |
| `scripts/deploy.sh`、`backup-db-volume.sh` | 完成 |
| Cloudflare Tunnel → `127.0.0.1:8080` | 完成，無需變更 |
| Git remote（SSH）+ push | 完成（`git@github.com:Aiden4939/inwanding-infra.git`） |
| Phase 6 文件補強 | 完成（commit `88dd9fa`） |
| **P1-1 首次 DB 邏輯備份** | **完成**（2026-06-04 UTC，`appdb_20260604T040732Z.sql.gz`） |
| `pg_data` / `app-whoami` / 舊 `~/infra/nginx` 清理 | **未完成** |
| `svc-web` 換正式 frontend image | **未完成**（產品層） |
| `server.md` 與 repo docs 同步 | **完成**（2026-06-04，`~/inwanding-infra/server.md`） |
| `web-ubuntu` RAM 升級（4GB → ≥6GB） | **未完成** |
| 監控 / 告警可執行落地 | **未完成**（P3-3 已規劃） |

---

## P0 — 版本控管與文件收斂

優先讓 repo 成為可交接、可追蹤的單一真相來源。

### P0-1：提交 Phase 6 文件變更

| 欄位 | 內容 |
|------|------|
| **目標** | 將已驗證的 nginx conf 備份說明納入 git，與現場操作一致 |
| **完成條件** | `README.md`、`docs/DEPLOY.md`、`docs/RESTORE.md` 變更已 commit；`git status` clean（不含 `backups/`） |
| **風險等級** | 低 |
| **是否需要批准** | 否（僅文件） |
| **建議順序** | 1 |

### P0-2：設定 Git remote 並首次 push

| 欄位 | 內容 |
|------|------|
| **目標** | 將 infra 設定異地備份於 Git 託管（建議 private repo） |
| **完成條件** | `git remote add origin <URL>`、`git push -u origin main` 成功；遠端可見 compose / nginx / docs / scripts |
| **風險等級** | 低（注意勿 push `.env`；`.gitignore` 已排除） |
| **是否需要批准** | **是**（需提供 remote URL、確認 repo 可見性） |
| **建議順序** | 2 |

### P0-3：建立變更紀錄習慣

| 欄位 | 內容 |
|------|------|
| **目標** | 每次改 conf / compose / 部署前有小步 commit，便於 rollback |
| **完成條件** | README 或 DEPLOY 已註明「改動前先 commit」；團隊知悉流程 |
| **風險等級** | 低 |
| **是否需要批准** | 否 |
| **建議順序** | 3（與 P0-2 並行推廣） |

---

## P1 — 備份、還原與維運可執行性

讓備份與還原從「文件 + 骨架」變成「驗證過的操作」。

### P1-1：首次試跑 DB 邏輯備份（`backup-db-volume.sh`）— **已完成**

| 欄位 | 內容 |
|------|------|
| **目標** | 產出第一份可還原的 `pg_dump` 壓縮檔至 `backups/postgres/` |
| **完成條件** | 存在非空的 `appdb_<UTC>.sql.gz`；`gunzip -c … \| head` 可見 SQL；腳本 exit 0 |
| **完成日期** | **2026-06-04 UTC** |
| **備份檔** | `backups/postgres/appdb_20260604T040732Z.sql.gz`（372B；當時 DB 無 user tables，偏小屬正常） |
| **風險等級** | 低～中（`pg_dump` 讀取為主，正式寫入風險低；需注意磁碟與短暫 I/O） |
| **是否需要批准** | **是**（正式 DB 相關操作） |
| **建議順序** | 4 |

### P1-2：驗證 DB 還原 SOP（可選：非正式資料演練）

| 欄位 | 內容 |
|------|------|
| **目標** | 確認 RESTORE.md 的 pg_dump 還原步驟可行（建議維護窗口、先停 `svc-api`） |
| **完成條件** | 在批准前提下完成一次還原演練或逐條 checklist 簽核；文件補充實際踩坑（若有） |
| **風險等級** | **高**（可能覆寫 `appdb` 資料） |
| **是否需要批准** | **是** |
| **建議順序** | 5（依賴 P1-1 已有備份檔） |

### P1-3：備份保留策略與（可選）cron

| 欄位 | 內容 |
|------|------|
| **目標** | 定義 nginx conf / DB dump 保留天數、目錄清理責任；必要時排程 |
| **完成條件** | 文件載明保留政策；若上 cron：有註明路徑、log、且不刪 `nginx_pg_data` |
| **風險等級** | 低（cron 設錯路徑為中） |
| **是否需要批准** | **是**（若新增 cron 或自動刪檔） |
| **建議順序** | 6 |

### P1-4：將 `deploy.sh` 納入標準部署演練

| 欄位 | 內容 |
|------|------|
| **目標** | 在維護窗口用腳本走完 config → pull → up → nginx reload，並跑 DEPLOY 驗證清單 |
| **完成條件** | 一次演練記錄；服務 curl 全通過；無非預期 container 重建 |
| **風險等級** | 中（`up -d` 可能重啟 api） |
| **是否需要批准** | **是**（涉及正式部署） |
| **建議順序** | 7 |

---

## P2 — 技術債盤點與低風險清理

不影響正式流量前提下的整理；**刪除類一律需批准**。

### P2-1：調查 Docker volume `pg_data`（只讀）

| 欄位 | 內容 |
|------|------|
| **目標** | 確認 `pg_data` 是否為切換至 `nginx_pg_data` 前的殘留、是否含需保留資料 |
| **完成條件** | 比對兩 volume 建立時間、大小、目錄檔案數；書面結論（保留 / 封存 / 待刪） |
| **風險等級** | 低（僅調查） |
| **是否需要批准** | 否（調查）；**刪除 volume 需另案批准** |
| **建議順序** | 8 |

### P2-2：處理殘留容器 `app-whoami`

| 欄位 | 內容 |
|------|------|
| **目標** | 移除舊 compose project `nginx` 遺留、無 published port 的測試容器 |
| **完成條件** | 確認無依賴後 `stop` + `rm`；`docker ps` 不再見 `app-whoami` |
| **風險等級** | 低（與現行 8080 stack 網路隔離） |
| **是否需要批准** | **是** |
| **建議順序** | 9 |

### P2-3：舊目錄 `~/infra/nginx` 定位

| 欄位 | 內容 |
|------|------|
| **目標** | 標記為 legacy，避免誤用舊 `compose.yml` 操作正式服務 |
| **完成條件** | README 已警告；可選：在目錄加 `LEGACY.md` 或搬至 `archive/`（**不移除資料除非批准**） |
| **風險等級** | 低 |
| **是否需要批准** | **是**（若搬移 / 刪除舊目錄） |
| **建議順序** | 10 |

### P2-4：Secrets 與 `.env` 治理

| 欄位 | 內容 |
|------|------|
| **目標** | 確認密碼輪替流程、備份不含 `.env` 進 git |
| **完成條件** | 文件載明輪替步驟；必要時更新 `.env.example` 註解（不提交真實密碼） |
| **風險等級** | 中（改 `.env` 會重啟 api/db） |
| **是否需要批准** | **是**（若實際輪替密碼） |
| **建議順序** | 11 |

### P2-5：同步更新 `server.md` — **本里程碑已完成（2026-06-04）**

| 欄位 | 內容 |
|------|------|
| **目標** | 在重要 infra 變更完成後，同步更新專案 **Single Source of Truth** `server.md` |
| **完成條件** | ① `~/inwanding-infra/server.md` 已建立並反映現況 ② 與 README、DEPLOY、RESTORE、ROADMAP 一致 ③ 修訂紀錄已註 2026-06-04 |
| **後續** | **橫向任務**：P1-4、P2-6 等里程碑後再次更新 `server.md` 修訂紀錄即可 |
| **風險等級** | 低 |
| **是否需要批准** | 否（僅文件） |
| **建議順序** | 13（可重複） |

### P2-6：`web-ubuntu` RAM 升級

| 欄位 | 內容 |
|------|------|
| **目標** | 將 `web-ubuntu` VM 的 RAM 由目前 **4GB** 提升至至少 **6GB**（或更高），降低同機多服務記憶體壓力 |
| **理由** | 主機同時承載 **cloudflared**、**edge-nginx**、**svc-web**、**svc-api**、**svc-postgres**、**tailscaled** 等，4GB 偏緊，易在部署或備份時出現 swap / OOM 風險 |
| **完成條件** | ①  hypervisor / 雲控制台 RAM 調整完成且 `free -h` 顯示 ≥6GB ② 必要時重啟 VM 或依序重啟服務後 stack 正常 ③ `docker ps` 四核心容器皆 Up ④ DEPLOY 章節 curl 清單全通（含 `not-exist` → 404、`/health` → 200）⑤ `systemctl is-active cloudflared`、`tailscaled` 為 active |
| **風險等級** | 中（維護窗口、重啟期間短暫不可用） |
| **是否需要批准** | **是**（涉及 VM 規格與可能重啟） |
| **建議順序** | 12（建議於 P1-1 首次 DB 備份後、P3 監控上線前；與 P2-4 可並行規劃） |

---

## P3 — 產品與可觀測性（較長期）

### P3-1：替換 `svc-web` 為正式前端 image

| 欄位 | 內容 |
|------|------|
| **目標** | `inwanding.com` / `www` 不再回 whoami，改為正式靜態站或應用 |
| **完成條件** | compose 更新 image；部署後 curl / 瀏覽器驗證；nginx conf 無需改或已同步調整 |
| **風險等級** | 中 |
| **是否需要批准** | **是**（產品 + 部署決策） |
| **建議順序** | 14 |

### P3-2：API 對外路徑與文件一致

| 欄位 | 內容 |
|------|------|
| **目標** | 釐清 `api.inwanding.com/` 404 是否為預期；健康檢查與對外文件統一（如僅文件化 `/health`） |
| **完成條件** | README/DEPLOY 註明對外 API 入口路徑；可選實作 `/` redirect |
| **風險等級** | 低～中 |
| **是否需要批准** | **是**（若改 API 應用行為） |
| **建議順序** | 15 |

### P3-3：監控、告警與值班

| 欄位 | 內容 |
|------|------|
| **目標** | 對主機資源、container 存活、API 健康與對外可用性建立**可驗證**的觀測與告警，而非僅文件概念 |
| **完成條件** | 以下四類皆已落地，且各有一條**可重現的驗證方式**（指令、dashboard URL、或最近一次告警紀錄）：① **主機** CPU / RAM / disk：至少一種（例：`node_exporter` + Grafana、`netdata`、或雲監控 agent）— 驗證：能看到 `web-ubuntu` 最近 24h 曲線或 `df -h` / `free -h` 定期快照 ② **Container 存活**：至少一種（例：cron `docker ps` 檢查四容器名、或 compose healthcheck）— 驗證：模擬 `svc-api` stop 時能在約定時間內觸發失敗狀態 ③ **API `/health`**：至少一種外部或排程探測（例：UptimeRobot、cron `curl -fsS https://api.inwanding.com/health`）— 驗證：保存最近 7 天成功紀錄或監控面板綠燈 ④ **告警 / 通知**：至少一種收件方式（Email、Telegram、Slack、webhook 等）— 驗證：提供一次測試告警截圖或 log 時間戳。另：文件載明值班 / 升級聯絡人 |
| **風險等級** | 低（實作錯誤導致誤報為中） |
| **是否需要批准** | **是**（若引入新服務、SaaS 或對外連線） |
| **建議順序** | 16（建議於 P2-6 RAM 升級後，避免 4GB 下監控 agent 與本 stack 搶記憶體） |

### P3-4：多環境 / DR（可選）

| 欄位 | 內容 |
|------|------|
| **目標** | 定義第二台主機或冷備策略、RTO/RPO |
| **完成條件** | DR 文件 + 還原演練週期 |
| **風險等級** | 中～高 |
| **是否需要批准** | **是** |
| **建議順序** | 17 |

---

## 建議總順序（一覽）

```
P0-1 → P0-2 → P0-3
  → P1-1 → P1-2 → P1-3 → P1-4
    → P2-1 → P2-2 → P2-3 → P2-4
      → P2-6（RAM 升級）
        → P2-5（server.md 同步；里程碑後可重複）
          → P3-1 → P3-2 → P3-3 → P3-4
```

| 順序 | 代號 | 摘要 |
|------|------|------|
| 1–3 | P0 | 文件 commit、remote、變更習慣 |
| 4–7 | P1 | DB 備份、還原演練、保留策略、deploy 演練 |
| 8–11 | P2-1～4 | pg_data 調查、whoami、legacy、secrets |
| 12 | P2-6 | web-ubuntu RAM 4GB → ≥6GB |
| 13 | P2-5 | 同步 `server.md`（里程碑後） |
| 14–17 | P3 | 正式 web、API 文件、監控告警、DR |

**近期最值得先做（低風險、高價值）：** P1-3（備份保留策略）、P1-4（deploy 演練）、P2-5（`server.md` 同步，里程碑後可重複）。

**明確暫緩（除非你另行指示）：** 刪除 `nginx_pg_data`、修改 cloudflared、未批准之 DB 還原演練、未批准之 volume/容器刪除。

---

## 不在此 ROADMAP 內執行的事項

以下需另開議題或明確指示，**不**當作預設下一步：

- 變更 Cloudflare Tunnel ingress（目前驗證正常）
- 刪除 `nginx_pg_data` 或覆寫 volume 實體目錄
- 大改 compose 拓樸或新增未要求之服務
- 將 `backups/` 提交至 git

---

## 修訂紀錄

| 日期 | 說明 |
|------|------|
| 2026-06-03 | 初版：依 Phase 1–6 現況與 repo 狀態建立 |
| 2026-06-03 | 增補 P2-5 `server.md`、P2-6 RAM 升級；強化 P3-3 監控完成條件；調整建議總順序 |
| 2026-06-04 | P1-1 首次 DB 備份完成；`server.md` SST 建立；文件同步 |
