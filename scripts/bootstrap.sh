#!/bin/bash
# Bootstrap script for Arch Linux Ansible Pull setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

# Update system and install essential packages
log_info "Updating system packages..."
sudo pacman -Syu --noconfirm

log_info "Installing essential packages..."
sudo pacman -S --needed --noconfirm \
    ansible \
    git \
    openssh \
    python-passlib \
    python-bcrypt

# Install ansible collections
log_info "Installing Ansible collections..."
ansible-galaxy collection install -r ansible/requirements.yml

# Create ansible user for automated runs
log_info "Creating ansible user..."
sudo useradd -m -s /bin/bash -G wheel ansible || true
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh

# Generate SSH key for GitHub access
log_info "Generating SSH key for GitHub..."
if [[ ! -f /home/ansible/.ssh/id_ed25519 ]]; then
    sudo -u ansible ssh-keygen -t ed25519 -N "" -f /home/ansible/.ssh/id_ed25519 -C "ansible-pull@$(hostname)"
fi

# Configure SSH for GitHub
sudo -u ansible tee /home/ansible/.ssh/config > /dev/null <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF

sudo chmod 600 /home/ansible/.ssh/config
sudo chown ansible:ansible /home/ansible/.ssh/config

# Display public key for GitHub setup
log_info "Add this public key to GitHub as a deploy key:"
echo "----------------------------------------"
sudo cat /home/ansible/.ssh/id_ed25519.pub
echo "----------------------------------------"

# Set up sudo access for ansible user
log_info "Configuring sudo access for ansible user..."
sudo tee /etc/sudoers.d/ansible > /dev/null <<EOF
ansible ALL=(ALL) NOPASSWD: ALL
EOF

# Create ansible working directory
sudo mkdir -p /opt/ansible-pull
sudo chown ansible:ansible /opt/ansible-pull

log_info "Bootstrap complete!"
log_info "Next steps:"
log_info "1. Add the SSH key above to GitHub as a deploy key"
log_info "2. Run: sudo -u ansible ansible-pull -U git@github.com:LyeosMaouli/lm_archlinux_desktop.git -d /opt/ansible-pull ansible/local.yml"