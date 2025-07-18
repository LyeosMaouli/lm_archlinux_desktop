#!/bin/bash
# scripts/master_deploy.sh - Complete deployment orchestration

set -euo pipefail

# Configuration
DEPLOYMENT_TYPE=${1:-"full"}
TARGET_HOST=${2:-"localhost"}
LOG_DIR="/var/log/deployment"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_LOG="$LOG_DIR/deployment_$TIMESTAMP.log"

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$DEPLOYMENT_LOG")
    exec 2> >(tee -a "$DEPLOYMENT_LOG" >&2)
}

# Progress tracking
TOTAL_PHASES=4
CURRENT_PHASE=0

update_progress() {
    local phase_name=$1
    CURRENT_PHASE=$((CURRENT_PHASE + 1))
    local percentage=$((CURRENT_PHASE * 100 / TOTAL_PHASES))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$CURRENT_PHASE/$TOTAL_PHASES] ($percentage%) $phase_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Phase 0: Pre-installation
phase0_pre_installation() {
    update_progress "Pre-Installation Setup"
    
    # Hardware validation
    ./scripts/validate_hardware.sh
    
    # USB preparation
    ./scripts/prepare_usb.sh
    
    echo "Phase 0 completed: Pre-installation setup"
}

# Phase 1: Base installation
phase1_base_installation() {
    update_progress "Base System Installation"
    
    # Execute archinstall with configurations
    archinstall \
        --config configs/archinstall/user_configuration.json \
        --creds configs/archinstall/user_credentials.json \
        --silent
    
    echo "Phase 1 completed: Base system installation"
}

# Phase 2: System transition
phase2_system_transition() {
    update_progress "System Transition and Bootstrap"
    
    # Wait for system boot and first-boot service
    echo "Waiting for first-boot service completion..."
    
    # Monitor first-boot status
    while [ ! -f /var/lib/first-boot-complete ]; do
        if [ -f /var/lib/first-boot-status ]; then
            cat /var/lib/first-boot-status | jq -r '.message'
        fi
        sleep 10
    done
    
    echo "Phase 2 completed: System transition"
}

# Phase 3: Desktop environment
phase3_desktop_environment() {
    update_progress "Desktop Environment Setup"
    
    # Execute main Ansible playbook
    cd /opt/ansible-desktop
    ansible-playbook -i inventory/localhost.yml playbooks/desktop.yml
    
    echo "Phase 3 completed: Desktop environment setup"
}

# Validation and testing
validate_deployment() {
    echo "Validating deployment..."
    
    # Check services
    systemctl --failed --no-legend | grep -q "" && {
        echo "WARNING: Some services failed"
        systemctl --failed
    }
    
    # Check Hyprland
    if pgrep -x "Hyprland" > /dev/null; then
        echo "✓ Hyprland is running"
    else
        echo "✗ Hyprland is not running"
    fi
    
    # Check user environment
    if [ -f "/home/lyeosmaouli/.config/hypr/hyprland.conf" ]; then
        echo "✓ User environment configured"
    else
        echo "✗ User environment not configured"
    fi
    
    echo "Validation completed"
}

# Main deployment
main() {
    setup_logging
    
    echo "Starting unified Arch Linux Hyprland deployment"
    echo "Target: $TARGET_HOST"
    echo "Type: $DEPLOYMENT_TYPE"
    echo "Timestamp: $TIMESTAMP"
    
    case "$DEPLOYMENT_TYPE" in
        "full")
            phase0_pre_installation
            phase1_base_installation
            phase2_system_transition
            phase3_desktop_environment
            ;;
        "desktop-only")
            phase3_desktop_environment
            ;;
        "transition")
            phase2_system_transition
            phase3_desktop_environment
            ;;
        *)
            echo "Invalid deployment type: $DEPLOYMENT_TYPE"
            exit 1
            ;;
    esac
    
    validate_deployment
    
    echo "Deployment completed successfully!"
    echo "Log file: $DEPLOYMENT_LOG"
}

# Error handling
trap 'echo "Deployment failed at phase $CURRENT_PHASE"; exit 1' ERR

main "$@"