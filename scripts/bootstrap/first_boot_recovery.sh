#!/bin/bash
# scripts/bootstrap/first_boot_recovery.sh - Comprehensive recovery system

set -euo pipefail

# Configuration
RECOVERY_LOG="/var/log/recovery.log"
STATUS_FILE="/var/lib/first-boot-status"
RECOVERY_CONFIG="/opt/lm_archlinux_desktop/configs/recovery/recovery_config.yml"
BACKUP_DIR="/var/backups/system-recovery"
MAX_RECOVERY_ATTEMPTS=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$RECOVERY_LOG"
    
    case $level in
        ERROR)
            echo -e "${RED}[$level]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[$level]${NC} $message"
            ;;
        INFO)
            echo -e "${GREEN}[$level]${NC} $message"
            ;;
        DEBUG)
            echo -e "${BLUE}[$level]${NC} $message"
            ;;
    esac
}

# Error detection and analysis
analyze_failure() {
    log "INFO" "Analyzing system failure..."
    
    local failure_type="unknown"
    local failure_stage="unknown"
    
    # Check status file for last known state
    if [ -f "$STATUS_FILE" ]; then
        local last_status=$(jq -r '.status // "unknown"' "$STATUS_FILE" 2>/dev/null || echo "unknown")
        local last_stage=$(jq -r '.stage // 0' "$STATUS_FILE" 2>/dev/null || echo "0")
        
        log "INFO" "Last known status: $last_status (stage $last_stage)"
        
        case $last_status in
            "network")
                failure_type="network"
                ;;
            "clone")
                failure_type="repository"
                ;;
            "bootstrap")
                failure_type="ansible"
                ;;
            "desktop")
                failure_type="desktop"
                ;;
        esac
        
        failure_stage=$last_stage
    fi
    
    # Additional failure detection
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        failure_type="network"
        log "WARN" "Network connectivity issues detected"
    fi
    
    if ! systemctl --quiet is-active NetworkManager; then
        failure_type="network"
        log "WARN" "NetworkManager not running"
    fi
    
    if [ ! -d "/opt/lm_archlinux_desktop" ]; then
        failure_type="repository"
        log "WARN" "Repository not cloned"
    fi
    
    echo "$failure_type:$failure_stage"
}

# Network recovery
recover_network() {
    log "INFO" "Attempting network recovery..."
    
    # Restart NetworkManager
    systemctl restart NetworkManager
    sleep 5
    
    # Try to reconnect to known networks
    if command -v nmcli &>/dev/null; then
        nmcli device wifi rescan
        nmcli connection up id "$(nmcli -t -f NAME connection show | head -1)" || true
    fi
    
    # Wait for connectivity
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if ping -c 1 8.8.8.8 &>/dev/null; then
            log "INFO" "Network connectivity restored"
            return 0
        fi
        sleep 2
        attempts=$((attempts + 1))
    done
    
    log "ERROR" "Failed to restore network connectivity"
    return 1
}

# Repository recovery
recover_repository() {
    log "INFO" "Attempting repository recovery..."
    
    local repo_dir="/opt/lm_archlinux_desktop"
    local repo_url="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
    
    # Remove corrupted repository
    [ -d "$repo_dir" ] && rm -rf "$repo_dir"
    
    # Ensure network is available
    if ! ping -c 1 github.com &>/dev/null; then
        log "WARN" "No connectivity to GitHub, attempting network recovery first"
        recover_network || return 1
    fi
    
    # Clone repository
    if git clone "$repo_url" "$repo_dir"; then
        chown -R lyeosmaouli:lyeosmaouli "$repo_dir"
        log "INFO" "Repository successfully recovered"
        return 0
    else
        log "ERROR" "Failed to clone repository"
        return 1
    fi
}

# Ansible recovery
recover_ansible() {
    log "INFO" "Attempting Ansible recovery..."
    
    local repo_dir="/opt/lm_archlinux_desktop"
    
    # Ensure repository exists
    if [ ! -d "$repo_dir" ]; then
        recover_repository || return 1
    fi
    
    cd "$repo_dir"
    
    # Install/update Ansible dependencies
    pip install --user -r requirements.txt || {
        log "WARN" "Failed to install Python requirements, trying system packages"
        pacman -S --noconfirm python-pip ansible || return 1
    }
    
    # Install Ansible collections
    sudo -u lyeosmaouli ansible-galaxy collection install -r configs/ansible/requirements.yml --force
    
    # Run minimal bootstrap playbook
    if sudo -u lyeosmaouli ansible-playbook \
        -i configs/ansible/inventory/localhost.yml \
        configs/ansible/playbooks/bootstrap.yml \
        --tags="essential"; then
        log "INFO" "Ansible recovery successful"
        return 0
    else
        log "ERROR" "Ansible recovery failed"
        return 1
    fi
}

# Desktop recovery
recover_desktop() {
    log "INFO" "Attempting desktop recovery..."
    
    # Check if user session exists
    if ! id lyeosmaouli &>/dev/null; then
        log "ERROR" "User lyeosmaouli does not exist"
        return 1
    fi
    
    # Restart display manager
    systemctl restart sddm
    
    # Reset user configuration to defaults
    local user_config="/home/lyeosmaouli/.config"
    local backup_config="/home/lyeosmaouli/.config.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "$user_config" ]; then
        mv "$user_config" "$backup_config"
        log "INFO" "User config backed up to $backup_config"
    fi
    
    # Create basic configuration
    sudo -u lyeosmaouli mkdir -p "$user_config/hypr"
    sudo -u lyeosmaouli cp /usr/share/hyprland/hyprland.conf "$user_config/hypr/" 2>/dev/null || {
        log "WARN" "Default Hyprland config not found, creating minimal config"
        sudo -u lyeosmaouli cat > "$user_config/hypr/hyprland.conf" << 'EOF'
# Minimal Hyprland configuration
monitor=,preferred,auto,1

exec-once = waybar
exec-once = sddm

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
}

bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive
bind = SUPER, M, exit
EOF
    }
    
    log "INFO" "Desktop recovery completed"
    return 0
}

# Fallback to minimal system
fallback_minimal() {
    log "INFO" "Implementing fallback to minimal system..."
    
    # Ensure essential services are running
    local essential_services=(
        "NetworkManager"
        "sshd"
        "systemd-timesyncd"
    )
    
    for service in "${essential_services[@]}"; do
        if ! systemctl --quiet is-active "$service"; then
            systemctl start "$service"
            systemctl enable "$service"
            log "INFO" "Started essential service: $service"
        fi
    done
    
    # Create minimal user environment
    if id lyeosmaouli &>/dev/null; then
        # Ensure user has sudo access
        usermod -aG wheel lyeosmaouli
        
        # Create basic shell environment
        sudo -u lyeosmaouli cat > /home/lyeosmaouli/.bashrc << 'EOF'
# Minimal bashrc for recovery
export PS1='\u@\h:\w\$ '
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

alias ll='ls -la'
alias la='ls -la'
alias l='ls -CF'

# Recovery helpers
alias logs='journalctl -xe'
alias net='nmtui'
alias recovery='sudo systemctl start first-boot-recovery.service'
EOF
        
        chown lyeosmaouli:lyeosmaouli /home/lyeosmaouli/.bashrc
    fi
    
    # Create recovery information file
    cat > /home/lyeosmaouli/RECOVERY_INFO.txt << EOF
SYSTEM RECOVERY MODE
==================

Your system has been set to minimal recovery mode.

Available commands:
- logs: View system logs
- net: Configure network
- recovery: Restart recovery process

To manually continue setup:
1. Check network: ping google.com
2. Go to project: cd /opt/lm_archlinux_desktop
3. Run setup: ./scripts/bootstrap/first_boot_setup.sh

For support, check logs in: /var/log/recovery.log
EOF
    
    chown lyeosmaouli:lyeosmaouli /home/lyeosmaouli/RECOVERY_INFO.txt
    
    log "INFO" "Minimal system fallback completed"
    log "INFO" "User can login and run recovery manually"
}

# Main recovery logic
main_recovery() {
    log "INFO" "Starting system recovery process..."
    
    # Check recovery attempt count
    local attempt_file="/var/lib/recovery_attempts"
    local attempts=0
    
    if [ -f "$attempt_file" ]; then
        attempts=$(cat "$attempt_file")
    fi
    
    attempts=$((attempts + 1))
    echo "$attempts" > "$attempt_file"
    
    log "INFO" "Recovery attempt: $attempts/$MAX_RECOVERY_ATTEMPTS"
    
    if [ $attempts -gt $MAX_RECOVERY_ATTEMPTS ]; then
        log "ERROR" "Maximum recovery attempts exceeded, falling back to minimal system"
        fallback_minimal
        return 0
    fi
    
    # Analyze failure
    local failure_info=$(analyze_failure)
    local failure_type=$(echo "$failure_info" | cut -d: -f1)
    local failure_stage=$(echo "$failure_info" | cut -d: -f2)
    
    log "INFO" "Detected failure type: $failure_type at stage: $failure_stage"
    
    # Attempt recovery based on failure type
    case $failure_type in
        "network")
            if recover_network; then
                log "INFO" "Network recovery successful, restarting main setup"
                systemctl start first-boot-setup.service
                return 0
            fi
            ;;
        "repository")
            if recover_repository && recover_network; then
                log "INFO" "Repository recovery successful, restarting main setup"
                systemctl start first-boot-setup.service
                return 0
            fi
            ;;
        "ansible")
            if recover_ansible; then
                log "INFO" "Ansible recovery successful, continuing setup"
                systemctl start first-boot-setup.service
                return 0
            fi
            ;;
        "desktop")
            if recover_desktop; then
                log "INFO" "Desktop recovery successful"
                return 0
            fi
            ;;
    esac
    
    # If specific recovery failed, try full recovery sequence
    log "WARN" "Specific recovery failed, attempting full recovery sequence"
    
    if recover_network && recover_repository && recover_ansible; then
        log "INFO" "Full recovery successful, restarting setup"
        systemctl start first-boot-setup.service
        return 0
    else
        log "ERROR" "Full recovery failed, implementing fallback"
        fallback_minimal
        return 1
    fi
}

# Create system backup before recovery
create_recovery_backup() {
    log "INFO" "Creating recovery backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup important files
    local backup_files=(
        "/etc/hostname"
        "/etc/hosts"
        "/etc/NetworkManager"
        "/home/lyeosmaouli/.bashrc"
        "/var/lib/first-boot-status"
    )
    
    for file in "${backup_files[@]}"; do
        if [ -e "$file" ]; then
            cp -r "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    log "INFO" "Recovery backup created in $BACKUP_DIR"
}

# Main execution
main() {
    log "INFO" "Recovery service started"
    
    # Create backup
    create_recovery_backup
    
    # Run recovery
    if main_recovery; then
        log "INFO" "Recovery completed successfully"
        
        # Reset attempt counter on success
        rm -f "/var/lib/recovery_attempts"
        
        # Update status
        cat > "$STATUS_FILE" << EOF
{
    "status": "recovered",
    "message": "System recovery completed successfully",
    "timestamp": "$(date -Iseconds)",
    "stage": 8,
    "total_stages": 8
}
EOF
        
        exit 0
    else
        log "ERROR" "Recovery failed, system is in minimal state"
        exit 1
    fi
}

# Error handling
trap 'log "ERROR" "Recovery script encountered an error"; exit 1' ERR

main "$@"