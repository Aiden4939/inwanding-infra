# Self-hosted Runner SOP

適用主機：`web-ubuntu`  
適用 repo：`Aiden4939/inwanding-infra`  
Runner 目錄：`/home/aiden/actions-runner-infra`  
Labels：`self-hosted,linux,x64,web-ubuntu,deploy,infra`

## 設計原則

- repo-level runner，只服務 `inwanding-infra`
- deploy 只用手動觸發（`workflow_dispatch`）
- 不修改 `.env`、Cloudflare Tunnel、nginx conf、compose 拓樸
- 一次只允許一個 deploy job（workflow `concurrency`）

## 1. 取得 Registration Token（GitHub UI）

1. 開啟 https://github.com/Aiden4939/inwanding-infra/settings/actions/runners/new
2. 選 **Linux / x64**
3. 複製 `--token` 後面的 registration token（短時效，約 1 小時）

## 2. 安裝 Runner（主機）

```bash
cd ~/inwanding-infra
export RUNNER_REGISTRATION_TOKEN='貼上 token'
./scripts/install-actions-runner.sh
```

驗證：

- GitHub UI：Runners 頁面顯示 `web-ubuntu-infra` 為 **Idle**
- 主機：`systemctl --user status actions.runner.inwanding-infra.service`

開機自動運行（建議，需 sudo 一次）：

```bash
sudo loginctl enable-linger aiden
```

## 3. 手動 Deploy（GitHub UI）

1. 開啟 https://github.com/Aiden4939/inwanding-infra/actions/workflows/deploy.yml
2. 點 **Run workflow**
3. 選 service：
   - `line-bot`（預設）
   - `api`
4. 執行後檢查 job log 與 health check 結果

## 4. Workflow 行為

deploy workflow 會在 runner 上執行：

1. `docker compose config`
2. `docker compose pull <service>`
3. `docker compose up -d <service>`
4. `docker compose ps`
5. health check（本機 nginx Host header）

Health check URL：

| service | Host header |
|---------|-------------|
| line-bot | `linebot.inwanding.com` |
| api | `api.inwanding.com` |

## 5. Rollback（移除 Runner）

1. GitHub UI → Runners → 選 runner → **Remove** → 取得 remove token
2. 主機執行：

```bash
cd ~/inwanding-infra
export RUNNER_REMOVE_TOKEN='貼上 remove token'
./scripts/uninstall-actions-runner.sh
```

## 6. 風險提醒

- runner 具備主機命令執行能力，請限制 repo 寫入權限
- 不要將 registration/remove token 提交 git
- 現階段請勿改成 `push main` 自動部署正式環境
