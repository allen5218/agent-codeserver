#!/bin/bash
set -e

EXT_DIR="${XDG_DATA_HOME:-/home/coder/.config}/code-server/extensions"

# 首次啟動（bind-mount 是空的）就把 baked extensions seed 進去
if [ ! -d "$EXT_DIR" ] || [ -z "$(ls -A "$EXT_DIR" 2>/dev/null)" ]; then
    mkdir -p "$EXT_DIR"
    cp -rn /opt/extensions-seed/. "$EXT_DIR/" 2>/dev/null || true
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
