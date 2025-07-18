#!/bin/bash
# scripts/first_boot_setup.sh - Automated Ansible bootstrap

set -euo pipefail

# Configuration
REPO_URL="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
ANSIBLE_DIR="/opt/ansible-desktop"
LOG_FILE="/var/log/first-boot-setup.log"
USER="lyeosmaouli"
STATUS_FILE="/var/lib/first-boot-status"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Progress tracking
update_status() {
    local status=$1
    local message=$2
    local stage=${3:-0}
    
    cat > "$STATUS_FILE" << EOF
{
    "status": "$status",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "stage": $stage,
    "total_stages": 7
}
EOF
    
    log "[$stage/7] $message"
}

# Network connectivity validation with retries
validate_network() {
    local max_attempts=10
    local delay=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ping -c 1 -W 1 8.8.8.8 > /dev/null 2>&1; then
            log "Network connectivity confirmed"
            return 0
        fi
        
        log "Network attempt $attempt failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Network connectivity failed after $max_attempts attempts"
    return 1
}

# SSH key generation and GitHub integration
setup_ssh_keys() {
    local ssh_dir="/home/$USER/.ssh"
    
    # Create SSH directory
    sudo -u "$USER" mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate SSH key
    sudo -u "$USER" ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N ""
    
    # Configure SSH client
    cat > "$ssh_dir/config" << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
EOF
    
    chown -R "$USER:$USER" "$ssh_dir"
    chmod 600 "$ssh_dir/config"
    
    log "SSH keys generated for user $USER"
}

# Repository cloning with error handling
clone_repository() {
    local clone_dir="$ANSIBLE_DIR"
    
    # Remove existing directory if present
    [ -d "$clone_dir" ] && rm -rf "$clone_dir"
    
    # Clone repository
    if sudo -u "$USER" git clone "$REPO_URL" "$clone_dir"; then
        log "Repository cloned successfully"
        chown -R "$USER:$USER" "$clone_dir"
        return 0
    else
        log "ERROR: Failed to clone repository"
        return 1
    fi
}

# Ansible bootstrap
bootstrap_ansible() {
    cd "$ANSIBLE_DIR"
    
    # Install Python dependencies
    sudo -u "$USER" pip install --user -r requirements.txt
    
    # Install Ansible collections
    sudo -u "$USER" ansible-galaxy collection install -r requirements.yml
    
    # Run initial Ansible playbook
    sudo -u "$USER" ansible-playbook -i inventory/localhost.yml playbooks/bootstrap.yml
    
    log "Ansible bootstrap completed"
}

# Execute Ansible desktop setup
run_ansible_desktop() {
    cd "$ANSIBLE_DIR"
    
    # Execute main desktop playbook
    sudo -u "$USER" ansible-playbook -i inventory/localhost.yml playbooks/desktop.yml
    
    log "Ansible desktop setup completed"
}

# Main execution
main() {
    update_status "starting" "Initializing first-boot setup" 1
    
    update_status "network" "Validating network connectivity" 2
    validate_network || exit 1
    
    update_status "ssh" "Setting up SSH keys" 3
    setup_ssh_keys
    
    update_status "clone" "Cloning repository" 4
    clone_repository || exit 1
    
    update_status "bootstrap" "Bootstrapping Ansible" 5
    bootstrap_ansible || exit 1
    
    update_status "desktop" "Running desktop setup" 6
    run_ansible_desktop || exit 1
    
    update_status "complete" "First-boot setup completed successfully" 7
    
    # Disable first-boot service
    systemctl disable first-boot-setup.service
    
    log "First-boot setup completed successfully"
}

# Error handling
trap 'update_status "error" "First-boot setup failed" && exit 1' ERR

main "$@"