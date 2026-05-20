# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Pin these for course reproducibility
ARG GNAT_TOOLCHAIN=gnat_native=15.1.2
ARG GNATPROVE_CRATE=gnatprove

# Basic build + runtime deps commonly needed by Alire crates / Ada tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils \
    adduser sudo \
    build-essential pkg-config \
    python3 python3-venv \
    z3 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for VS Code devcontainers
ARG USERNAME=vscode
RUN adduser --disabled-password --gecos "" "${USERNAME}" \
 && usermod -aG sudo "${USERNAME}" \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# Install Alire (static binary release)
# If you prefer, you can swap this for apt-based install, but the release binary is usually more predictable.
ARG ALIRE_VERSION=2.1.0
RUN curl -fsSL -o /tmp/alr.zip \
    "https://github.com/alire-project/alire/releases/download/v${ALIRE_VERSION}/alr-${ALIRE_VERSION}-bin-x86_64-linux.zip" \
 && unzip -q /tmp/alr.zip -d /usr/local \
 && rm -f /tmp/alr.zip \
 && chmod +x /usr/local/bin/alr

# Ensure vscode user's local bin is on PATH
ENV PATH=/home/vscode/.local/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER ${USERNAME}
WORKDIR /home/vscode

# Pre-create local bin
RUN mkdir -p /home/vscode/.local/bin

# Update Alire index and install/select a pinned GNAT toolchain
RUN alr index --update-all \
 && alr toolchain --select gnat_native=15.1.2 gprbuild=25.0.1

# diagnostics
RUN set -eux; \
    echo "PATH=$PATH"; \
    alr --version; \
    alr toolchain || true; \
    echo "--- command -v gprbuild"; \
    command -v gprbuild || true; \
    echo "--- alr exec -- which gprbuild"; \
    alr exec -- which gprbuild || true; \
    echo "--- alr exec -- gprbuild --version"; \
    alr exec -- gprbuild --version || true

# Install GNATprove into ~/.local (so VS Code extension can find them on PATH)
RUN set -eux; \
    mkdir -p /home/vscode/.cache/alr-tools; \
    cd /home/vscode/.cache/alr-tools; \
    if [ ! -f tools/alire.toml ]; then \
      alr --non-interactive init --bin tools; \
    fi; \
    cd tools; \
    \
    # Install GNATprove into ~/.local
    alr exec -- alr install --prefix=/home/vscode/.local "${GNATPROVE_CRATE}"; \
    /home/vscode/.local/bin/gnatprove --version

# Put GNAT toolchain binaries on PATH for the extension by creating stable symlinks into ~/.local/bin.
# This avoids PATHs containing hashes under ~/.local/share/alire/toolchains/...
RUN set -eux; \
    cd /home/vscode/.cache/alr-tools/tools; \
    mkdir -p /home/vscode/.local/bin; \
    ln -sf "$(alr exec -- which gnat)"      /home/vscode/.local/bin/gnat; \
    ln -sf "$(alr exec -- which gcc)"       /home/vscode/.local/bin/gcc; \
    ln -sf "$(alr exec -- which gnatmake || true)"  /home/vscode/.local/bin/gnatmake; \
    ln -sf "$(alr exec -- which gprbuild)"  /home/vscode/.local/bin/gprbuild; \
    ln -sf "$(alr exec -- which gnatbind || true)"  /home/vscode/.local/bin/gnatbind; \
    ln -sf "$(alr exec -- which gnatlink || true)"  /home/vscode/.local/bin/gnatlink; \
    ln -sf "$(alr exec -- which gnatls || true)"    /home/vscode/.local/bin/gnatls; \
    ln -sf "$(alr exec -- which gprconfig || true)" /home/vscode/.local/bin/gprconfig; \
    ln -sf "$(command -v /home/vscode/.local/bin/gnatprove >/dev/null 2>&1 && echo /home/vscode/.local/bin/gnatprove || alr exec -- which gnatprove || true)" \
           /home/vscode/.local/bin/gnatprove || true

# Helpful defaults for interactive shells
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.bashrc
