FROM codercom/code-server:4.121.0
USER root
# 跟 runtime 一致，讓 build 階段的路徑邏輯對齊
ENV XDG_DATA_HOME=/home/coder/.config

# ---- 系統套件 ----
# build-essential 涵蓋 gcc/g++/make
# clangd 給 clangd extension 用；cmake 給 cmake-tools 用
# tmux 給長時 session 用
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        clangd \
        postgresql-client \
        python3-pip \
        python3-venv \
        tmux \
        curl ca-certificates git \
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
        pgcli

# ---- AI CLIs（npm global）----
RUN npm install -g @openai/codex

# ---- 準備 extension seed 目錄 ----
RUN mkdir -p /opt/extensions-seed && chown coder:coder /opt/extensions-seed

# ---- 切到 coder 裝 user-scope 的東西 ----
USER coder

# Antigravity CLI → /home/coder/.local/bin/agy
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

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
        --install-extension ms-python.python

# ---- 開放讀取權限 + entrypoint ----
USER root
RUN chmod -R a+rX /opt/extensions-seed /home/coder/.local

COPY entrypoint.sh /usr/local/bin/seed-and-run.sh
RUN chmod +x /usr/local/bin/seed-and-run.sh

# 讓 agy 跟其他 user-local binary 都在 PATH
ENV PATH="/home/coder/.local/bin:${PATH}"

ENTRYPOINT ["/usr/local/bin/seed-and-run.sh"]
CMD []
