# Container Environment

This is a `codercom/code-server`-based dev container with the following tools pre-installed.

---

## AI coding assistants

| CLI | Binary | Notes |
| --- | ------ | ----- |
| Claude Code | `claude` | This process. Installed via Anthropic apt repo. |
| OpenAI Codex | `codex` | npm global `@openai/codex`. |
| Google Antigravity | `agy` | At `/home/coder/.local/bin/agy`. |

---

## Python

```bash
python3 --version          # system Python 3
uv run python script.py    # preferred: uv manages venvs automatically
uv add <pkg>               # add dependency to current project
uv pip install <pkg>       # pip-style install inside uv venv
pip3 install --user <pkg>  # fallback
```

`uv` is at `/usr/local/bin/uv`. Prefer it over bare `pip3` for project work.

### Pre-installed system-wide libraries

| Package | Purpose |
| ------- | ------- |
| `python-pptx` | Read/write PowerPoint (.pptx) |
| `python-docx` | Read/write Word (.docx) |
| `openpyxl` | Read/write Excel (.xlsx) |
| `pgcli` | PostgreSQL CLI with autocomplete |
| `unoserver` | LibreOffice conversion server |

---

## Office document conversion (LibreOffice / unoserver)

### Headless LibreOffice (one-shot)

```bash
libreoffice --headless --convert-to pdf file.docx
libreoffice --headless --convert-to docx file.odt --outdir /tmp/
```

### unoserver (faster for multiple conversions)

```bash
unoserver &                         # start daemon (port 2003 by default)
unoconvert --convert-to pdf in.docx out.pdf
unoconvert --convert-to xlsx in.ods out.xlsx
kill %1                             # stop daemon when done
```

---

## Node.js

```bash
node --version    # Node 22 LTS
npm install       # install project deps
npx <tool>        # run without global install
```

---

## Headless browser / web scraping (Playwright CLI)

`playwright-cli` ([`@playwright/cli`](https://www.npmjs.com/package/@playwright/cli)) is
preinstalled globally at `/home/coder/.npm-global/bin/playwright-cli` — Microsoft's
agent-oriented Playwright CLI. It drives a real, **headless** Chromium (pre-downloaded at
`/ms-playwright`) via concise, stateful commands. Runs as the non-root user with no
`--no-sandbox` needed.

The `playwright-cli` skill is auto-installed into `~/.claude/skills/` on first container
start, so you can also just use the skill. The CLI is stateful — `open` starts a session,
later commands act on it until `close`.

```bash
playwright-cli open https://example.com        # start a headless session
playwright-cli snapshot                         # page snapshot with element refs
playwright-cli click <ref>                      # act on a ref from the snapshot
playwright-cli eval "() => document.title"      # run JS in the page
playwright-cli screenshot --filename shot.png   # default: .playwright-cli/page-*.png
playwright-cli close
```

Run `playwright-cli --help` for the full command list (navigation, keyboard/mouse, tabs,
storage/auth state, PDF, tracing, etc.).

---

## Build / compile (C/C++)

```bash
gcc -o out main.c
g++ -o out main.cpp
make              # uses Makefile
cmake -B build && cmake --build build
```

`clangd` is available for LSP support.

---

## Database

```bash
psql -h <host> -U <user> -d <db>
pgcli -h <host> -U <user> -d <db>   # with autocomplete + syntax highlighting
```

---

## Archives

```bash
zip -r archive.zip dir/
unzip archive.zip
7z a archive.7z dir/
7z x archive.7z
tar -czf archive.tar.gz dir/
```

---

## Terminal multiplexer

```bash
tmux new -s main       # new session named "main"
tmux attach -t main    # reattach
```

Use tmux to run long-running background processes (e.g. `unoserver`) while continuing to work in the main shell.
