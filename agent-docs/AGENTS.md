# Container Environment for AI Agents

This is a `codercom/code-server`-based dev container (Debian-based; published for
`linux/amd64` and `linux/arm64`). The notes below describe tools that are available
to agents running inside it.

---

## Paths

| Binary / tool | Location |
| ------------- | -------- |
| `claude` | `/usr/bin/claude` |
| `codex` | npm global (on `PATH`) |
| `agy` | `/home/coder/.local/bin/agy` |
| `uv` | `/usr/local/bin/uv` |
| `playwright` | `/home/coder/.local/bin/playwright` |
| `unoconvert` | installed with `unoserver` pip package |

---

## Python

Prefer `uv` for project-level work; system-wide libraries are available without any venv.

```bash
python3 script.py
uv run python script.py   # auto-creates venv in project
uv add <pkg>              # add to current project's pyproject.toml
```

### Pre-installed libraries (no install needed)

| Library | Use case |
| ------- | -------- |
| `python-pptx` | Create / modify PowerPoint files |
| `python-docx` | Create / modify Word documents |
| `openpyxl` | Create / modify Excel workbooks |
| `pgcli` | PostgreSQL CLI |
| `unoserver` | LibreOffice document conversion |

---

## Office document conversion

### One-shot (LibreOffice headless)

```bash
libreoffice --headless --convert-to pdf input.docx
libreoffice --headless --convert-to docx input.odt --outdir /tmp/
```

Supported formats include: pdf, docx, xlsx, pptx, odt, ods, odp, txt, html, csv.

### Batch / repeated conversions (unoserver)

Start the daemon once and reuse it for multiple files — much faster than spawning LibreOffice per file.

```bash
unoserver --daemon          # start in background (default port 2003)
unoconvert --convert-to pdf in.docx out.pdf
unoconvert --convert-to xlsx in.ods out.xlsx
pkill -f unoserver          # stop when done
```

---

## Database access

```bash
psql  -h <host> -U <user> -d <db> -c "SELECT 1;"
pgcli -h <host> -U <user> -d <db>
```

`psql` is the standard PostgreSQL client; `pgcli` adds autocomplete and syntax highlighting.

---

## Node.js (v22 LTS)

```bash
node -e "console.log('hello')"
npm install
npx ts-node script.ts
```

---

## Headless browser / web scraping (Playwright)

A global `playwright` CLI is preinstalled (Python package, via `uv tool install`).
Chromium is pre-downloaded at `/ms-playwright` (`PLAYWRIGHT_BROWSERS_PATH`) and is ready
the moment the container starts — no `playwright install` needed.

**The container runs as a non-root user, so always launch Chromium with `--no-sandbox`**,
otherwise it crashes with "No usable sandbox".

```bash
playwright --version
```

For scraping, add Playwright to the project and write a script — it reuses the preloaded
Chromium (no second download):

```bash
uv add playwright
uv run python - <<'PY'
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--no-sandbox"])   # headless by default
    page = browser.new_page()
    page.goto("https://example.com")
    print(page.title())
    page.screenshot(path="shot.png")
    browser.close()
PY
```

Only the global CLI is provided image-wide; a project's own scraping code is the project's
own dependency (`uv add playwright`).

---

## C / C++ build tools

```bash
gcc -o out main.c && ./out
g++ -std=c++17 -o out main.cpp && ./out
make
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
```

---

## Archives

```bash
zip -r archive.zip dir/     # create zip
unzip archive.zip           # extract zip
7z a archive.7z dir/        # create 7z / zip / tar
7z x archive.7z             # extract any supported format
tar -czf archive.tar.gz dir/
tar -xzf archive.tar.gz
```

---

## Long-running processes

Use `tmux` to keep daemons (e.g. `unoserver`) running across shell invocations:

```bash
tmux new-session -d -s bg 'unoserver --daemon'
# ... do work ...
tmux kill-session -t bg
```
