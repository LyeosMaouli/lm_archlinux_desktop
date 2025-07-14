#!/bin/bash
# scripts/setup-ansible-pull.sh

set -euo pipefail

REPO_URL="git@github.com:LyeosMaouli/lm_archlinux_desktop.git"
ANSIBLE_DIR="/opt/ansible-pull"

# Install dependencies
pacman -Sy --noconfirm ansible git

# Clone repository
git clone "$REPO_URL" "$ANSIBLE_DIR"

# Set proper permissions
chmod 600 "$ANSIBLE_DIR/ssh/lm-archlinux-deploy"
chmod 644 "$ANSIBLE_DIR/ssh/lm-archlinux-deploy.pub"

# Run bootstrap playbook
ansible-playbook -i localhost, -c local "$ANSIBLE_DIR/ansible/playbooks/bootstrap.yml"

# Enable service
systemctl enable --now ansible-pull.timer

echo "Ansible Pull setup completed successfully!"