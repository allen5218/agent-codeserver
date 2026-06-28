# agent-codeserver

繁體中文版：[README-zh.md](./README-zh.md)

A customized [code-server](https://github.com/coder/code-server) Docker image preloaded with developer tooling and AI coding assistants. Intended for homelab and remote-development setups where you want a single browser-accessible VS Code environment with AI agents already wired in.

## What’s inside

Built on `codercom/code-server:4.126.0` (Debian-based). Published as a multi-arch image for `linux/amd64` and `linux/arm64`.

### AI coding assistants

|Tool                              |Source                           |Notes                                                                                                                  |
|----------------------------------|---------------------------------|-----------------------------------------------------------------------------------------------------------------------|
|**Claude Code**                   |Official Anthropic apt repository|Native binary at `/usr/bin/claude`. Auto-update disabled; updates arrive via image rebuild.                            |
|**OpenAI Codex CLI**              |npm (`@openai/codex`)            |Installed user-scope under `/home/coder/.npm-global/` so `coder` can `npm update` it without root. See sandbox note below.|
|**Google Antigravity CLI** (`agy`)|Official install script          |Installed to `/home/coder/.local/bin/`.                                                                                |

#### Codex remote-control (auto-started)

On container start the entrypoint launches `codex remote-control` in the background, supervised by a restart loop (re-spawns 5s after any exit). This lets you drive the in-container Codex agent remotely without manually attaching a shell.

- Logs stream to `/home/coder/.codex/remote-control.log`.
- Disable it by setting `ENABLE_CODEX_REMOTE=0`.
- Skipped automatically if the `codex` binary is not on `PATH`.

#### Codex sandbox (bubblewrap)

`bubblewrap` is installed and `/usr/bin/bwrap` is configured setuid-root (`chmod 4750`, owned by the `bwrap-users` group, with `coder` added to it). This gives Codex CLI a working command-execution sandbox inside the container without granting `coder` broad root access.

### Build and development tools

- `gcc`, `g++`, `make` (via `build-essential`)
- `cmake`, `clangd` — for C/C++ work alongside the bundled extensions
- **Python 3** with `pip` and `venv`
- **Node.js 22 LTS** with `npm`
- **uv** — Astral’s Python package and project manager, installed to `/usr/local/bin/`

### Office and document tools

- **LibreOffice** — full office suite, usable headlessly via `unoserver`
- `python3-uno` — Python–UNO bridge for LibreOffice scripting
- `unoserver` — exposes LibreOffice over a network socket for programmatic document conversion

### Archive and utility tools

- `tmux` — terminal multiplexer
- `zip`, `unzip`, `p7zip-full` — archive creation and extraction

### Python libraries (system-wide)

Installed so AI agents can manipulate Office documents programmatically without per-project venv setup:

- `python-pptx`
- `python-docx`
- `openpyxl`
- `pgcli`
- `unoserver`

### Database clients

- `psql` (PostgreSQL client)
- `pgcli` (PostgreSQL CLI with autocomplete and syntax highlighting)

### Headless browser (Playwright)

For driving a headless browser from the CLI — page scraping, automation, `codegen`:

- **Playwright CLI** — the Python `playwright` package, installed globally via `uv tool install` (isolated venv, command at `/home/coder/.local/bin/playwright`).
- **Chromium** — pre-downloaded at build time into `/ms-playwright` (`PLAYWRIGHT_BROWSERS_PATH`), so it is available the moment the container starts and is readable regardless of the runtime UID.
- System libraries are installed via Playwright's own `install-deps`, so they always match the bundled browser version.

Notes:

- The container runs as a **non-root** user, so launch Chromium with `--no-sandbox` (e.g. `chromium.launch(args=["--no-sandbox"])`, or `--no-sandbox` on the CLI) — the in-process Chromium sandbox needs privileges the container does not grant.
- The runtime needs a large `/dev/shm` or Chromium will crash on big pages; the supplied `compose.yml` sets `shm_size: "1gb"` and `init: true` for the `code-server` service.
- Only the **global CLI** is provided. A project that imports Playwright in its own scripts should add it as a project dependency (e.g. `uv add playwright`); it will reuse the already-downloaded Chromium in `/ms-playwright` automatically (no second download).

### Pre-installed VS Code extensions

Sourced from [Open VSX](https://open-vsx.org/):

|Extension     |ID                                     |
|--------------|---------------------------------------|
|clangd        |`llvm-vs-code-extensions.vscode-clangd`|
|Code Runner   |`formulahendry.code-runner`            |
|VSCode Counter|`uctakeoff.vscode-counter`             |
|Prettier      |`esbenp.prettier-vscode`               |
|CMake         |`twxs.cmake`                           |
|CMake Tools   |`ms-vscode.cmake-tools`                |
|markdownlint  |`DavidAnson.vscode-markdownlint`       |
|Ruff          |`charliermarsh.ruff`                   |
|basedpyright  |`detachhead.basedpyright`              |
|uv Toolkit    |`the0807.uv-toolkit`                   |
|Jupyter       |`ms-toolsai.jupyter`                   |
|Claude Code   |`Anthropic.claude-code`                |
|Codex         |`openai.chatgpt`                       |

Python tooling uses **Ruff** (lint/format) and **basedpyright** (type checking) instead of the Microsoft Python extension; the build also uninstalls `ms-python.vscode-python-envs` to avoid env-picker conflicts with `uv`.

Extensions are baked into `/opt/extensions-seed/` at build time. On first container start, a small entrypoint wrapper seeds them into the user’s extensions directory so they survive bind-mount overlays and remain user-editable at runtime.

## Image

Published to GitHub Container Registry on every push to `main` and on `v*` tags:

```text
ghcr.io/allen5218/agent-codeserver:<tags>
```

Available tags:

- `latest` — current `main` branch
- `<short-sha>` — every commit
- `YYYY-MM-DD` — date-stamped snapshots from `main`
- `v*` — release tags

Each tag is a multi-arch manifest covering `linux/amd64` and `linux/arm64`; `docker pull` automatically selects the right architecture. CI builds each architecture natively (amd64 on `ubuntu-latest`, arm64 on `ubuntu-24.04-arm`) and merges them into a single manifest.

## Deployment (Docker Compose)

The repo ships a [`compose.yml`](./compose.yml) running two services: `code-server` (this image) and a `cloudflared` tunnel that exposes it without opening any inbound ports. The image is **multi-arch**: the same `compose.yml` works on both `linux/amd64` and `linux/arm64` because it is pinned to a multi-arch manifest-list digest, and Docker pulls the matching architecture automatically.

### 1. Get the deployment files

Clone the repo (or just copy `compose.yml` and `.env.example` out of it — those two files are all you need to deploy):

```bash
git clone https://github.com/allen5218/agent-codeserver.git
cd agent-codeserver
```

Run every remaining step from this directory — it holds both `compose.yml` and `.env.example`, and is where `docker compose` looks for them.

### 2. Prepare host directories

These are the bind-mount targets referenced by `compose.yml`. They live under `/opt/docker-stacks/vscode`, **separate from the cloned repo**. Create them and hand them to the UID:GID the container will run as (must match `APP_UID`/`APP_GID` in `.env`):

```bash
# Create the bind-mount targets (matching the volumes in compose.yml)
sudo mkdir -p /opt/docker-stacks/vscode/{data,projects,codex,gemini,claude}

# Claude Code needs an existing JSON file to mount
echo '{}' | sudo tee /opt/docker-stacks/vscode/claude.json > /dev/null

# chown everything to the UID:GID the container runs as (1000:1000 here; match .env)
sudo chown -R 1000:1000 /opt/docker-stacks/vscode
```

> `~/.local` (Playwright, Antigravity) and `~/.npm-global` (Codex) are **deliberately not mounted** — these CLIs are baked into the image at build time, and overlaying an empty host directory would shadow them. Only mount `~/.npm-global` if you want to persist a Codex that you `npm update` yourself (see Suggested persistent paths below).

### 3. Configure environment

From the cloned repo (where `.env.example` lives):

```bash
cp .env.example .env
# Edit .env: set CODE_PASSWORD, APP_UID/APP_GID, CF_TUNNEL_TOKEN
```

See [`.env.example`](./.env.example) for the full list.

### 4. Cloudflare Tunnel

1. Zero Trust dashboard → **Networks → Tunnels → Create a tunnel**
2. Choose **Cloudflared** and name it (e.g. `homelab`)
3. **Copy token** — this is `CF_TUNNEL_TOKEN` in `.env`
4. On the **Public Hostname** tab, add an entry:
   - **Subdomain**: `code`
   - **Domain**: `your.dev`
   - **Type**: `HTTP`
   - **URL**: `code-server:8080` (the compose service name + in-container port, resolved on the shared network)

### 5. Start

```bash
docker compose up -d
```

Open `https://code.your.dev` and log in with `CODE_PASSWORD`.

## Environment

|Variable              |Required                        |Purpose                                                                     |
|----------------------|--------------------------------|----------------------------------------------------------------------------|
|`PASSWORD`            |Yes                             |code-server login password                                                  |
|`XDG_DATA_HOME`       |Pre-set to `/home/coder/.config`|Consolidates code-server config and extensions into a single mount          |
|`ENABLE_CODEX_REMOTE` |No (defaults to `1`)            |Set to `0` to skip auto-starting the background `codex remote-control` loop |

The table above lists **container-side** variables. When deploying with `compose.yml`, the **host-side** values come from `.env`: `CODE_PASSWORD` (mapped to `PASSWORD`), `APP_UID`/`APP_GID` (container run-as identity), and `CF_TUNNEL_TOKEN` (Cloudflare tunnel). See [`.env.example`](./.env.example).

## Suggested persistent paths

Mount these as volumes to preserve state across container restarts:

|Container path                                    |Holds                                                      |
|--------------------------------------------------|-----------------------------------------------------------|
|`/home/coder/.config`                             |code-server settings, keybindings, and installed extensions|
|`/home/coder/project`                             |Workspace / working directory                              |
|`/home/coder/.claude` + `/home/coder/.claude.json`|Claude Code state and OAuth token                          |
|`/home/coder/.codex`                              |OpenAI Codex auth, sessions, history, and remote-control log|
|`/home/coder/.gemini`                             |Antigravity tasks, MCP configs, and rules                  |
|`/home/coder/.npm-global`                         |User-scope npm prefix; persist to keep `npm update`d Codex  |

The Antigravity CLI’s own settings (`~/.config/antigravity/`, `~/.config/agy/`) are covered by the `~/.config` mount automatically.

## Entrypoint

The image entrypoint is `/usr/local/bin/seed-and-run.sh`:

1. On first run, copies baked extensions from `/opt/extensions-seed/` into `$XDG_DATA_HOME/code-server/extensions/` if that directory is empty.
1. Unless `ENABLE_CODEX_REMOTE=0`, starts `codex remote-control` in the background under a supervisor loop (restarts 5s after any exit), logging to `/home/coder/.codex/remote-control.log`.
1. Delegates to the original `codercom/code-server` entrypoint, which handles `fixuid` and launches `code-server`.

## Agent context docs

[`agent-docs/`](./agent-docs/) contains reference sheets for AI agents running inside the container:

| File | Read by |
| ---- | ------- |
| [`agent-docs/CLAUDE.md`](./agent-docs/CLAUDE.md) | Claude Code (point it at the file with `@agent-docs/CLAUDE.md`) |
| [`agent-docs/AGENTS.md`](./agent-docs/AGENTS.md) | OpenAI Codex and other agents that honour `AGENTS.md` |

Both files document the pre-installed tools, library locations, and example commands available in the container.

## Build

The image builds automatically via GitHub Actions:

- Pushes to `main`, `v*` tags, and changes to `Dockerfile`, `entrypoint.sh`, or the workflow trigger a build.
- Renovate keeps the `codercom/code-server` base image, GitHub Action versions, and image digests current.

To build locally:

```bash
docker build -t agent-codeserver:dev .
```

## License

MIT — see [`LICENSE`](./LICENSE).

Bundled software retains its own license; this repository’s license applies only to the configuration, Dockerfile, and entrypoint script in this repo.
