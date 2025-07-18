#!/bin/bash
# scripts/deployment/master_deploy.sh - Fixed paths

set -euo pipefail

# Configuration
DEPLOYMENT_TYPE=${1:-"full"}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT"  # Use the repo itself
LOG_DIR="/var/log/deployment"

# Phase 1: Base installation
phase1_base_installation() {
    update_progress "Base System Installation"
    
    # Execute archinstall with configurations from YOUR repo
    archinstall \
        --config "$PROJECT_ROOT/configs/archinstall/user_configuration.json" \
        --creds "$PROJECT_ROOT/configs/archinstall/user_credentials.json" \
        --silent
    
    echo "Phase 1 completed: Base system installation"
}

# Phase 3: Desktop environment
phase3_desktop_environment() {
    update_progress "Desktop Environment Setup"
    
    # Execute main Ansible playbook from YOUR repo
    cd "$PROJECT_ROOT"
    ansible-playbook -i configs/ansible/inventory/localhost.yml \
                     configs/ansible/playbooks/desktop.yml
    
    echo "Phase 3 completed: Desktop environment setup"
}

# Rest remains the same...