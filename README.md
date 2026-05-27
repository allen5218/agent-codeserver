# agent-codeserver

A customized [code-server](https://github.com/coder/code-server) Docker image preloaded with developer tooling and AI coding assistants. Intended for homelab and remote-development setups where you want a single browser-accessible VS Code environment with AI agents already wired in.

## What’s inside

Built on `codercom/code-server:4.121.0` (Debian-based, `linux/amd64`).

### AI coding assistants

|Tool                              |Source                           |Notes                                                                                      |
|----------------------------------|---------------------------------|-------------------------------------------------------------------------------------------|
|**Claude Code**                   |Official Anthropic apt repository|Native binary at `/usr/bin/claude`. Auto-update disabled; updates arrive via image rebuild.|
|**OpenAI Codex CLI**              |npm (`@openai/codex`)            |                                                                                           |
|**Google Antigravity CLI** (`agy`)|Official install script          |Installed to `/home/coder/.local/bin/`.                                                    |

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
|Python        |`ms-python.python`                     |
|Jupyter       |`ms-toolsai.jupyter`                   |
|Claude Code   |`Anthropic.claude-code`                |
|ChatGPT       |`openai.chatgpt`                       |

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

Built for `linux/amd64`.

## Environment

|Variable       |Required                        |Purpose                                                           |
|---------------|--------------------------------|------------------------------------------------------------------|
|`PASSWORD`     |Yes                             |code-server login password                                        |
|`XDG_DATA_HOME`|Pre-set to `/home/coder/.config`|Consolidates code-server config and extensions into a single mount|

## Suggested persistent paths

Mount these as volumes to preserve state across container restarts:

|Container path                                    |Holds                                                      |
|--------------------------------------------------|-----------------------------------------------------------|
|`/home/coder/.config`                             |code-server settings, keybindings, and installed extensions|
|`/home/coder/project`                             |Workspace / working directory                              |
|`/home/coder/.claude` + `/home/coder/.claude.json`|Claude Code state and OAuth token                          |
|`/home/coder/.codex`                              |OpenAI Codex auth, sessions, and history                   |
|`/home/coder/.gemini`                             |Antigravity tasks, MCP configs, and rules                  |

The Antigravity CLI’s own settings (`~/.config/antigravity/`, `~/.config/agy/`) are covered by the `~/.config` mount automatically.

## Entrypoint

The image entrypoint is `/usr/local/bin/seed-and-run.sh`:

1. On first run, copies baked extensions from `/opt/extensions-seed/` into `$XDG_DATA_HOME/code-server/extensions/` if that directory is empty.
1. Delegates to the original `codercom/code-server` entrypoint, which handles `fixuid` and launches `code-server`.

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
