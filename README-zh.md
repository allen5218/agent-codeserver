# agent-codeserver

English: [README.md](./README.md)

一個客製化的 [code-server](https://github.com/coder/code-server) Docker 鏡像，預載了開發工具與 AI 編碼助手。適用於 homelab 與遠端開發場景——只要一個瀏覽器即可存取、且已內建串接好 AI agent 的 VS Code 環境。

## 內容物

基於 `codercom/code-server:4.126.0`（Debian-based）。以多架構鏡像發佈，支援 `linux/amd64` 與 `linux/arm64`。

### AI 編碼助手

| 工具 | 來源 | 說明 |
| ---- | ---- | ---- |
| **Claude Code** | Anthropic 官方 apt repo | 原生二進位於 `/usr/bin/claude`。已停用自動更新；更新隨鏡像重建而來。 |
| **OpenAI Codex CLI** | npm (`@openai/codex`) | 以 user-scope 安裝於 `/home/coder/.npm-global/`，`coder` 不需 root 即可 `npm update`。見下方 sandbox 說明。 |
| **Google Antigravity CLI** (`agy`) | 官方安裝腳本 | 安裝於 `/home/coder/.local/bin/`。 |

#### Codex remote-control（自動啟動）

容器啟動時，entrypoint 會在背景啟動 `codex remote-control`，並由重啟迴圈監督（任何結束後 5 秒重生）。這讓你不必手動 attach shell 即可遠端驅動容器內的 Codex agent。

- 日誌輸出至 `/home/coder/.codex/remote-control.log`。
- 設定 `ENABLE_CODEX_REMOTE=0` 可停用。
- 若 `codex` 不在 `PATH` 上會自動略過。

#### Codex sandbox（bubblewrap）

已安裝 `bubblewrap`，且 `/usr/bin/bwrap` 設為 setuid-root（`chmod 4750`、屬於 `bwrap-users` 群組、`coder` 已加入該群組）。這讓 Codex CLI 在容器內有可用的指令執行沙箱，又不必賦予 `coder` 廣泛的 root 權限。

### 建置與開發工具

- `gcc`、`g++`、`make`（透過 `build-essential`）
- `cmake`、`clangd` — 搭配內建擴充套件進行 C/C++ 開發
- **Python 3**，含 `pip` 與 `venv`
- **Node.js 22 LTS**，含 `npm`
- **uv** — Astral 的 Python 套件與專案管理器，安裝於 `/usr/local/bin/`

### Office 與文件工具

- **LibreOffice** — 完整 office 套件，可透過 `unoserver` 以 headless 方式使用
- `python3-uno` — LibreOffice 腳本用的 Python–UNO 橋接
- `unoserver` — 透過網路 socket 提供 LibreOffice 以供程式化文件轉換

### 壓縮與工具程式

- `tmux` — 終端機多工器
- `zip`、`unzip`、`p7zip-full` — 壓縮檔建立與解壓

### Python 函式庫（系統層級）

預裝這些函式庫，讓 AI agent 不必逐專案建立 venv 即可程式化操作 Office 文件：

- `python-pptx`
- `python-docx`
- `openpyxl`
- `pgcli`
- `unoserver`

### 資料庫客戶端

- `psql`（PostgreSQL 客戶端）
- `pgcli`（具自動補全與語法高亮的 PostgreSQL CLI）

### Headless 瀏覽器（Playwright）

用於從 CLI 驅動 headless 瀏覽器——網頁爬取、自動化、`codegen`：

- **Playwright CLI** — Python 的 `playwright` 套件，透過 `uv tool install` 全域安裝（隔離 venv，指令位於 `/home/coder/.local/bin/playwright`）。
- **Chromium** — build 時預先下載至 `/ms-playwright`（`PLAYWRIGHT_BROWSERS_PATH`），容器一啟動即可用，且不論執行 UID 為何都可讀取。
- 系統函式庫由 Playwright 自帶的 `install-deps` 安裝，永遠與內建的瀏覽器版本相符。

注意事項：

- 容器以**非 root** 使用者執行，所以啟動 Chromium 時請帶 `--no-sandbox`（例如 `chromium.launch(args=["--no-sandbox"])`，或在 CLI 加 `--no-sandbox`）——Chromium 自身的行程內沙箱需要容器未授予的權限。
- runtime 需要較大的 `/dev/shm`，否則 Chromium 在載入大頁面時會崩潰；隨附的 `compose.yml` 已為 `code-server` 服務設定 `shm_size: "1gb"` 與 `init: true`。
- 鏡像層級只提供**全域 CLI**。若某專案要在自己的腳本中 import Playwright，應將其加為專案依賴（例如 `uv add playwright`）；它會自動重用已下載於 `/ms-playwright` 的 Chromium（不會重新下載）。

### 預裝的 VS Code 擴充套件

來源為 [Open VSX](https://open-vsx.org/)：

| 擴充套件 | ID |
| -------- | -- |
| clangd | `llvm-vs-code-extensions.vscode-clangd` |
| Code Runner | `formulahendry.code-runner` |
| VSCode Counter | `uctakeoff.vscode-counter` |
| Prettier | `esbenp.prettier-vscode` |
| CMake | `twxs.cmake` |
| CMake Tools | `ms-vscode.cmake-tools` |
| markdownlint | `DavidAnson.vscode-markdownlint` |
| Ruff | `charliermarsh.ruff` |
| basedpyright | `detachhead.basedpyright` |
| uv Toolkit | `the0807.uv-toolkit` |
| Jupyter | `ms-toolsai.jupyter` |
| Claude Code | `Anthropic.claude-code` |
| Codex | `openai.chatgpt` |

Python 工具鏈使用 **Ruff**（lint/format）與 **basedpyright**（型別檢查）取代 Microsoft Python 擴充套件；build 也會反安裝 `ms-python.vscode-python-envs`，以避免與 `uv` 的環境選擇器衝突。

擴充套件在 build 時烤進 `/opt/extensions-seed/`。容器首次啟動時，一個小型 entrypoint wrapper 會把它們 seed 進使用者的擴充套件目錄，讓它們能在 bind-mount 覆蓋下存活，並在 runtime 仍可由使用者編輯。

## 鏡像

在每次 push 到 `main` 以及 `v*` tag 時發佈至 GitHub Container Registry：

```text
ghcr.io/allen5218/agent-codeserver:<tags>
```

可用的 tag：

- `latest` — 目前的 `main` 分支
- `<short-sha>` — 每個 commit
- `YYYY-MM-DD` — 來自 `main` 的日期快照
- `v*` — release tag

每個 tag 都是涵蓋 `linux/amd64` 與 `linux/arm64` 的多架構 manifest；`docker pull` 會自動選擇正確的架構。CI 會分別在原生 runner 上建置各架構（amd64 用 `ubuntu-latest`、arm64 用 `ubuntu-24.04-arm`），再合併成單一 manifest。

## 部署（Docker Compose）

本 repo 附帶 [`compose.yml`](./compose.yml)，會執行兩個服務：`code-server`（本鏡像）與一個 `cloudflared` tunnel——後者讓你不必開放任何 inbound port 即可對外暴露服務。

### 1. 準備主機目錄

建立 bind-mount 的目標目錄，並把它們交給容器執行時的 UID:GID（必須與 `.env` 中的 `APP_UID`/`APP_GID` 一致）：

```bash
# 建目錄（對應 compose.yml 掛載的 volume）
sudo mkdir -p /opt/docker-stacks/vscode/{data,projects,codex,gemini,claude}

# Claude Code 需要一個既存的 JSON 檔來掛載
echo '{}' | sudo tee /opt/docker-stacks/vscode/claude.json > /dev/null

# 全部 chown 給容器要用的 UID:GID（這裡用 1000:1000，依 .env 調整）
sudo chown -R 1000:1000 /opt/docker-stacks/vscode
```

> `~/.local`（Playwright、Antigravity）與 `~/.npm-global`（Codex）**刻意不掛載**——這些 CLI 是 build 時烤進鏡像的，用空目錄覆蓋會把它們遮蔽掉。只有當你想持久化自行 `npm update` 的 Codex 時，才另外掛 `~/.npm-global`（見下方「建議持久化路徑」）。

### 2. 設定環境變數

```bash
cp .env.example .env
# 編輯 .env：填入 CODE_PASSWORD、APP_UID/APP_GID、CF_TUNNEL_TOKEN
```

完整清單見 [`.env.example`](./.env.example)。

### 3. Cloudflare Tunnel

1. Zero Trust dashboard → **Networks → Tunnels → Create a tunnel**
2. 選 **Cloudflared**，命名（例如 `homelab`）
3. **Copy token** — 這就是 `.env` 裡的 `CF_TUNNEL_TOKEN`
4. 在 **Public Hostname** 頁籤新增一筆：
   - **Subdomain**：`code`
   - **Domain**：`your.dev`
   - **Type**：`HTTP`
   - **URL**：`code-server:8080`（compose 服務名 + 容器內 port，同網段直接解析）

### 4. 啟動

```bash
docker compose up -d
```

開啟 `https://code.your.dev`，用 `CODE_PASSWORD` 登入即可。

## 環境變數

| 變數 | 是否必填 | 用途 |
| ---- | -------- | ---- |
| `PASSWORD` | 是 | code-server 登入密碼 |
| `XDG_DATA_HOME` | 已預設為 `/home/coder/.config` | 將 code-server 設定與擴充套件整合進單一掛載點 |
| `ENABLE_CODEX_REMOTE` | 否（預設 `1`） | 設為 `0` 可略過背景 `codex remote-control` 迴圈的自動啟動 |

上表列出的是**容器側**變數。以 `compose.yml` 部署時，**主機側**的值來自 `.env`：`CODE_PASSWORD`（映射為 `PASSWORD`）、`APP_UID`/`APP_GID`（容器執行身分）、`CF_TUNNEL_TOKEN`（Cloudflare tunnel）。見 [`.env.example`](./.env.example)。

## 建議持久化路徑

將下列路徑掛載為 volume，以在容器重啟後保留狀態：

| 容器路徑 | 保存內容 |
| -------- | -------- |
| `/home/coder/.config` | code-server 設定、快捷鍵、已安裝的擴充套件 |
| `/home/coder/project` | 工作區 / 工作目錄 |
| `/home/coder/.claude` + `/home/coder/.claude.json` | Claude Code 狀態與 OAuth token |
| `/home/coder/.codex` | OpenAI Codex 認證、sessions、歷史與 remote-control 日誌 |
| `/home/coder/.gemini` | Antigravity 任務、MCP 設定與規則 |
| `/home/coder/.npm-global` | user-scope 的 npm prefix；持久化以保留 `npm update` 後的 Codex |

Antigravity CLI 自身的設定（`~/.config/antigravity/`、`~/.config/agy/`）已由 `~/.config` 掛載自動涵蓋。

## Entrypoint

鏡像的 entrypoint 為 `/usr/local/bin/seed-and-run.sh`：

1. 首次執行時，若 `$XDG_DATA_HOME/code-server/extensions/` 為空，會把烤好的擴充套件從 `/opt/extensions-seed/` 複製進去。
2. 除非 `ENABLE_CODEX_REMOTE=0`，否則在背景以監督迴圈啟動 `codex remote-control`（任何結束後 5 秒重啟），日誌輸出至 `/home/coder/.codex/remote-control.log`。
3. 交回原本的 `codercom/code-server` entrypoint，由它處理 `fixuid` 並啟動 `code-server`。

## Agent context 文件

[`agent-docs/`](./agent-docs/) 內含供容器內 AI agent 使用的參考表：

| 檔案 | 由誰讀取 |
| ---- | -------- |
| [`agent-docs/CLAUDE.md`](./agent-docs/CLAUDE.md) | Claude Code（用 `@agent-docs/CLAUDE.md` 指向該檔） |
| [`agent-docs/AGENTS.md`](./agent-docs/AGENTS.md) | OpenAI Codex 及其他遵循 `AGENTS.md` 的 agent |

兩個檔案都記錄了容器內預裝的工具、函式庫位置與範例指令。

## 建置

鏡像透過 GitHub Actions 自動建置：

- push 到 `main`、`v*` tag，以及變更 `Dockerfile`、`entrypoint.sh` 或 workflow 都會觸發建置。
- Renovate 會持續更新 `codercom/code-server` base image、GitHub Action 版本與鏡像 digest。

本機建置：

```bash
docker build -t agent-codeserver:dev .
```

## 授權

MIT — 見 [`LICENSE`](./LICENSE)。

內含的各軟體保留其各自的授權；本 repo 的授權僅適用於此 repo 內的設定、Dockerfile 與 entrypoint 腳本。
