#!/bin/bash
set -e

EXT_DIR="${XDG_DATA_HOME:-/home/coder/.config}/code-server/extensions"

# 首次啟動（bind-mount 是空的）就把 baked extensions seed 進去
if [ ! -d "$EXT_DIR" ] || [ -z "$(ls -A "$EXT_DIR" 2>/dev/null)" ]; then
    mkdir -p "$EXT_DIR"
    cp -rn /opt/extensions-seed/. "$EXT_DIR/" 2>/dev/null || true
fi

# 首次啟動時把 Playwright CLI 的 agent skills 裝進各 agent 的「全域」skills 目錄。
# 三者路徑不同且都是掛載 volume，故在 runtime 產生並寫入（持久化）：
#   Claude Code → ~/.claude/skills            (--skills claude 格式)
#   Codex       → ~/.codex/skills             (--skills agents 格式)
#   Antigravity → ~/.gemini/antigravity-cli/skills (同 agents 格式)
# cp -n 不覆蓋使用者既有檔案，保留可編輯性；失敗不影響 code-server 啟動。
HOME_DIR="${HOME:-/home/coder}"
if command -v playwright-cli >/dev/null 2>&1 && {
        [ ! -d "$HOME_DIR/.claude/skills/playwright-cli" ] ||
        [ ! -d "$HOME_DIR/.codex/skills/playwright-cli" ] ||
        [ ! -d "$HOME_DIR/.gemini/antigravity-cli/skills/playwright-cli" ]; }; then
    PW_TMP="$(mktemp -d)"
    ( cd "$PW_TMP" && playwright-cli install --skills claude && playwright-cli install --skills agents ) >/dev/null 2>&1 || true
    if [ -d "$PW_TMP/.claude/skills/playwright-cli" ]; then
        mkdir -p "$HOME_DIR/.claude/skills"
        cp -rn "$PW_TMP/.claude/skills/playwright-cli" "$HOME_DIR/.claude/skills/" 2>/dev/null || true
    fi
    if [ -d "$PW_TMP/.agents/skills/playwright-cli" ]; then
        mkdir -p "$HOME_DIR/.codex/skills" "$HOME_DIR/.gemini/antigravity-cli/skills"
        cp -rn "$PW_TMP/.agents/skills/playwright-cli" "$HOME_DIR/.codex/skills/" 2>/dev/null || true
        cp -rn "$PW_TMP/.agents/skills/playwright-cli" "$HOME_DIR/.gemini/antigravity-cli/skills/" 2>/dev/null || true
    fi
    rm -rf "$PW_TMP"
fi

# 背景啟動 codex remote-control（可用 ENABLE_CODEX_REMOTE=0 關閉）
if [ "${ENABLE_CODEX_REMOTE:-1}" != "0" ] && command -v codex >/dev/null 2>&1; then
    (
        while true; do
            echo "[codex] $(date '+%F %T') starting remote-control..."
            codex remote-control || true
            echo "[codex] $(date '+%F %T') exited, restarting in 5s..."
            sleep 5
        done
    ) >> "${HOME:-/home/coder}/.codex/remote-control.log" 2>&1 &
fi

# 交回原本的 codercom entrypoint（會處理 fixuid 跟 dumb-init）
exec /usr/bin/entrypoint.sh "$@"
