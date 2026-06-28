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

## Headless browser / web scraping (Playwright)

A global `playwright` CLI is preinstalled (Python, via `uv tool install`) at
`/home/coder/.local/bin/playwright`. Chromium is pre-downloaded at `/ms-playwright`
(`PLAYWRIGHT_BROWSERS_PATH`), ready on container start — no `playwright install` needed.

**Container runs as non-root, so always launch Chromium with `--no-sandbox`** (otherwise
"No usable sandbox" crash).

```bash
uv add playwright            # add to the project (reuses the preloaded Chromium)
uv run python - <<'PY'
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--no-sandbox"])   # headless by default
    page = browser.new_page()
    page.goto("https://example.com")
    print(page.title())
    browser.close()
PY
```

The global CLI handles version/tooling; a project's scraping code is the project's own
dependency.

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
