FROM codercom/code-server:4.121.0
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
        tmux \
        zip \
        unzip \
        p7zip-full \
        libreoffice \ 
        python3-uno \ 
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
        --install-extension ms-python.python \
        --install-extension ms-toolsai.jupyter \
        --install-extension Anthropic.claude-code \
        --install-extension openai.chatgpt

# ---- 開放讀取權限 + entrypoint ----
USER root
RUN chmod -R a+rX /opt/extensions-seed /home/coder/.local

COPY entrypoint.sh /usr/local/bin/seed-and-run.sh
RUN chmod +x /usr/local/bin/seed-and-run.sh

ENV PATH="/home/coder/.local/bin:${PATH}"

ENTRYPOINT ["/usr/local/bin/seed-and-run.sh"]
CMD ["--bind-addr", "0.0.0.0:8080", "."]

