FROM codercom/code-server:4.126.0@sha256:e1f03b5faaefd63ba6c7173a5290c6ec0526ac907f23acfe6bc949dd965279e4
USER root
ENV XDG_DATA_HOME=/home/coder/.config

# ---- 系統套件 ----
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        clangd \
        postgresql-client \
        python3-pip \
        python3-venv \
        python-is-python3 \
        tmux \
        zip \
        unzip \
        p7zip-full \
        libreoffice \
        python3-uno \
        bubblewrap \
    && groupadd -r bwrap-users \
    && usermod -aG bwrap-users coder \
    && chgrp bwrap-users /usr/bin/bwrap \
    && chmod 4750 /usr/bin/bwrap \
    && rm -rf /var/lib/apt/lists/*

# ---- Claude Code（official Anthropic apt repo）----
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
        -o /etc/apt/keyrings/claude-code.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
        > /etc/apt/sources.list.d/claude-code.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends claude-code \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js 22 LTS（給 codex 用）----
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---- uv (Astral) → /usr/local/bin ----
RUN curl -LsSf https://astral.sh/uv/install.sh \
    | INSTALLER_NO_MODIFY_PATH=1 UV_INSTALL_DIR=/usr/local/bin sh

# ---- Python file-manipulation libs（system-wide）----
RUN pip3 install --no-cache-dir --break-system-packages \
        python-pptx \
        python-docx \
        openpyxl \
        pgcli\
        unoserver

# ---- Playwright 瀏覽器存放路徑 + 系統相依函式庫 ----
# 瀏覽器二進位放固定系統路徑（build 時下載一次，container 以任意 UID 執行皆可讀取）。
# 系統函式庫透過 Playwright 自帶的 install-deps 安裝，版本永遠跟著 Playwright 走，
# 不必手動維護一長串 lib* 套件清單。
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN mkdir -p /ms-playwright && chown coder:coder /ms-playwright \
    && apt-get update \
    && uvx playwright install-deps chromium \
    && rm -rf /var/lib/apt/lists/*

# ---- 準備 extension seed 目錄 ----
RUN mkdir -p /opt/extensions-seed && chown coder:coder /opt/extensions-seed

# ---- 切到 coder 裝 user-scope 的東西 ----
USER coder

# ---- AI CLIs（npm user-scope，coder 可自行更新）----
RUN mkdir -p /home/coder/.npm-global \
    && npm config set prefix '/home/coder/.npm-global' \
    && npm install -g @openai/codex

# Antigravity CLI → /home/coder/.local/bin/agy
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# ---- Playwright CLI（uv 全域安裝）+ 預載 Chromium ----
# uv tool install 把 playwright CLI 裝進隔離 venv，指令連結到 /home/coder/.local/bin/playwright。
# 接著下載 Chromium 到 PLAYWRIGHT_BROWSERS_PATH（/ms-playwright），供 agent 直接以 CLI 操作。
RUN uv tool install playwright \
    && playwright install chromium

# Bake VS Code extensions 到 seed 目錄
RUN code-server \
        --extensions-dir /opt/extensions-seed \
        --install-extension llvm-vs-code-extensions.vscode-clangd \
        --install-extension formulahendry.code-runner \
        --install-extension uctakeoff.vscode-counter \
        --install-extension esbenp.prettier-vscode \
        --install-extension twxs.cmake \
        --install-extension DavidAnson.vscode-markdownlint \
        --install-extension ms-vscode.cmake-tools \
        --install-extension charliermarsh.ruff \
        --install-extension detachhead.basedpyright \
        --install-extension the0807.uv-toolkit \
        --install-extension ms-toolsai.jupyter \
        --install-extension Anthropic.claude-code \
        --install-extension openai.chatgpt \
        --uninstall-extension ms-python.vscode-python-envs

# ---- 開放讀取權限 + entrypoint ----
USER root
RUN chmod -R a+rX /opt/extensions-seed /home/coder/.local /home/coder/.npm-global /ms-playwright

COPY entrypoint.sh /usr/local/bin/seed-and-run.sh
RUN chmod +x /usr/local/bin/seed-and-run.sh

# 確保 code-server 開啟的互動式 bash session 也能找到 user-scope 的 CLI 工具
RUN echo 'export PATH="/home/coder/.npm-global/bin:/home/coder/.local/bin:$PATH"' \
    > /etc/profile.d/coder-paths.sh

ENV PATH="/home/coder/.npm-global/bin:/home/coder/.local/bin:${PATH}"

ENTRYPOINT ["/usr/local/bin/seed-and-run.sh"]
CMD ["--bind-addr", "0.0.0.0:8080", "."]
