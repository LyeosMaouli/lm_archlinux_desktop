# Multi-stage build for Arch Linux Desktop Automation Development Environment
FROM archlinux:latest as base

# Set metadata
LABEL maintainer="Arch Linux Desktop Automation Team"
LABEL description="Development environment for Arch Linux desktop automation"
LABEL version="1.0.0"

# Configure pacman and update system
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Syu --noconfirm

# Install base development tools
RUN pacman -S --noconfirm \
    # Core development tools
    base-devel \
    git \
    curl \
    wget \
    vim \
    nano \
    tree \
    htop \
    unzip \
    zip \
    rsync \
    # Shell and scripting
    bash \
    bash-completion \
    shellcheck \
    shfmt \
    # Python and Ansible
    python \
    python-pip \
    python-yaml \
    python-jinja \
    python-cryptography \
    ansible \
    ansible-lint \
    # Networking and security
    openssh \
    gnupg \
    # Container and virtualization
    docker \
    docker compose \
    # Documentation
    man-db \
    man-pages \
    # Additional utilities
    jq \
    yq \
    make \
    cmake \
    gcc \
    # Testing tools
    bats \
    # Archive tools
    tar \
    gzip \
    xz

# Create development user
RUN useradd -m -G wheel -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/devuser/.local/bin && \
    chown -R devuser:devuser /home/devuser

# Configure Git safe directories (for container usage)
RUN git config --system --add safe.directory '*'

# Install additional Python packages for development
USER devuser
WORKDIR /home/devuser

RUN pip install --user --no-cache-dir \
    ansible-core \
    ansible-runner \
    molecule \
    molecule-docker \
    yamllint \
    jinja2-cli \
    pytest \
    pytest-ansible \
    requests \
    cryptography \
    passlib \
    bcrypt

# Configure shell environment
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'export ANSIBLE_CONFIG="${WORKSPACE_ROOT:-/workspace}/configs/ansible/ansible.cfg"' >> ~/.bashrc && \
    echo 'export ANSIBLE_ROLES_PATH="${WORKSPACE_ROOT:-/workspace}/configs/ansible/roles"' >> ~/.bashrc && \
    echo 'export ANSIBLE_INVENTORY="${WORKSPACE_ROOT:-/workspace}/configs/ansible/inventory"' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias la="ls -la"' >> ~/.bashrc && \
    echo 'alias deploy="cd ${WORKSPACE_ROOT:-/workspace} && ./scripts/deploy.sh"' >> ~/.bashrc && \
    echo 'alias test-install="cd ${WORKSPACE_ROOT:-/workspace} && ./scripts/testing/test_installation.sh"' >> ~/.bashrc

# Create workspace directory
USER root
RUN mkdir -p /workspace && chown devuser:devuser /workspace

# Switch back to development user
USER devuser
WORKDIR /workspace

# Set default command
CMD ["/bin/bash"]

# Development stage with additional tools
FROM base as development

USER root

# Install additional development and debugging tools
RUN pacman -S --noconfirm \
    # Enhanced development tools
    gdb \
    valgrind \
    strace \
    lsof \
    tcpdump \
    wireshark-cli \
    # Code quality tools  
    clang \
    clang-tools-extra \
    # Documentation tools
    pandoc \
    texlive-core \
    # Container debugging
    dive \
    # Network tools
    nmap \
    netcat \
    # Performance tools
    perf \
    # Additional utilities
    fd \
    ripgrep \
    bat \
    exa \
    fzf

USER devuser

# Install additional development Python packages
RUN pip install --user --no-cache-dir \
    black \
    flake8 \
    mypy \
    pre-commit \
    bandit \
    safety \
    coverage \
    tox \
    sphinx \
    mkdocs \
    mkdocs-material

# Configure advanced shell environment
RUN echo '# Enhanced development aliases' >> ~/.bashrc && \
    echo 'alias cat="bat"' >> ~/.bashrc && \
    echo 'alias ls="exa"' >> ~/.bashrc && \
    echo 'alias find="fd"' >> ~/.bashrc && \
    echo 'alias grep="rg"' >> ~/.bashrc && \
    echo 'alias ansible-test="cd ${WORKSPACE_ROOT:-/workspace} && molecule test"' >> ~/.bashrc && \
    echo 'alias pre-commit-install="cd ${WORKSPACE_ROOT:-/workspace} && pre-commit install"' >> ~/.bashrc && \
    echo 'alias format-code="cd ${WORKSPACE_ROOT:-/workspace} && black . && shfmt -w -i 4 scripts/"' >> ~/.bashrc

# Production-ready stage (minimal)
FROM base as production

USER devuser

# Configure minimal production environment
RUN echo '# Production environment' >> ~/.bashrc && \
    echo 'export DEPLOYMENT_ENV=production' >> ~/.bashrc

# Set production entrypoint
WORKDIR /workspace
CMD ["/bin/bash", "-c", "source ~/.bashrc && exec bash"]

# Default target is development
FROM development as final