#!/bin/bash
# Master Deployment Script for Arch Linux Hyprland Automation
# Provides profile management and orchestrates the complete deployment process

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILES_DIR="$PROJECT_ROOT/profiles"
CONFIGS_DIR="$PROJECT_ROOT/configs"
LOG_FILE="/var/log/master_deploy.log"

# Default values
PROFILE="work"
DRY_RUN=false
VERBOSE=false
SKIP_CONFIRMATION=false
BACKUP_ENABLED=true
DEPLOYMENT_MODE="full"

# Available profiles
AVAILABLE_PROFILES=("work" "personal" "development" "minimal")

# Available deployment modes
AVAILABLE_MODES=("full" "bootstrap" "desktop" "security" "maintenance" "power")

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
    log "INFO: $1"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}DEBUG: $1${NC}"
        log "DEBUG: $1"
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Master deployment script for Arch Linux Hyprland automation system.

OPTIONS:
    -p, --profile PROFILE       Deployment profile (${AVAILABLE_PROFILES[*]})
    -m, --mode MODE            Deployment mode (${AVAILABLE_MODES[*]})
    -d, --dry-run              Show what would be done without executing
    -v, --verbose              Enable verbose output
    -y, --yes                  Skip confirmation prompts
    -b, --no-backup           Disable configuration backup
    -h, --help                 Show this help message

PROFILES:
    work         Work laptop configuration (security focused)
    personal     Personal use configuration (multimedia focused)
    development  Development environment setup
    minimal      Minimal installation for testing

DEPLOYMENT MODES:
    full         Complete system deployment (bootstrap + desktop + security + power)
    bootstrap    Initial system setup only
    desktop      Desktop environment setup only
    security     Security hardening only
    maintenance  System maintenance tasks
    power        Power management configuration only

EXAMPLES:
    $0 --profile work --mode full
    $0 -p development -m desktop -v
    $0 --dry-run --profile personal
    $0 -m maintenance -y

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -m|--mode)
                DEPLOYMENT_MODE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -b|--no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

# Validate inputs
validate_inputs() {
    # Validate profile
    if [[ ! " ${AVAILABLE_PROFILES[*]} " =~ " ${PROFILE} " ]]; then
        error "Invalid profile: $PROFILE. Available profiles: ${AVAILABLE_PROFILES[*]}"
    fi
    
    # Validate deployment mode
    if [[ ! " ${AVAILABLE_MODES[*]} " =~ " ${DEPLOYMENT_MODE} " ]]; then
        error "Invalid deployment mode: $DEPLOYMENT_MODE. Available modes: ${AVAILABLE_MODES[*]}"
    fi
    
    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only"
    fi
    
    # Check for required directories
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        error "Project root directory not found: $PROJECT_ROOT"
    fi
}

# Display system information
show_system_info() {
    info "System Information:"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Hostname: $(hostnamectl --static)"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $2 " available, " $4 " free"}')"
    echo ""
}

# Display deployment plan
show_deployment_plan() {
    info "Deployment Plan:"
    echo "  Profile: $PROFILE"
    echo "  Mode: $DEPLOYMENT_MODE"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  Configuration: $PROFILES_DIR/$PROFILE"
    echo "  Dry Run: $DRY_RUN"
    echo "  Backup Enabled: $BACKUP_ENABLED"
    echo "  Log File: $LOG_FILE"
    echo ""
    
    case $DEPLOYMENT_MODE in
        full)
            echo "  Steps: Bootstrap → Desktop → Security → Power Management"
            ;;
        bootstrap)
            echo "  Steps: Initial system setup and base configuration"
            ;;
        desktop)
            echo "  Steps: Hyprland desktop environment installation"
            ;;
        security)
            echo "  Steps: Security hardening and firewall configuration"
            ;;
        maintenance)
            echo "  Steps: System cleanup and maintenance tasks"
            ;;
        power)
            echo "  Steps: Power management and thermal optimization"
            ;;
    esac
    echo ""
}

# Backup existing configuration
backup_configuration() {
    if [[ "$BACKUP_ENABLED" == false ]]; then
        info "Configuration backup disabled"
        return 0
    fi
    
    info "Creating configuration backup..."
    
    local backup_dir="/backup/system-config-$(date +%Y%m%d-%H%M%S)"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would create backup at: $backup_dir"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    
    # Backup important configuration directories
    local backup_paths=(
        "/etc"
        "/home/$USER/.config"
        "/usr/local/bin"
        "/var/lib"
    )
    
    for path in "${backup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            debug "Backing up: $path"
            cp -r "$path" "$backup_dir/" 2>/dev/null || warn "Could not backup: $path"
        fi
    done
    
    success "Configuration backup created at: $backup_dir"
}

# Load profile configuration
load_profile() {
    local profile_dir="$PROFILES_DIR/$PROFILE"
    local profile_config="$profile_dir/config.yml"
    
    if [[ ! -d "$profile_dir" ]]; then
        warn "Profile directory not found: $profile_dir. Using default configuration."
        return 0
    fi
    
    if [[ ! -f "$profile_config" ]]; then
        warn "Profile configuration not found: $profile_config. Using default configuration."
        return 0
    fi
    
    info "Loading profile configuration: $PROFILE"
    debug "Profile directory: $profile_dir"
    debug "Profile config: $profile_config"
    
    # Export profile configuration for ansible
    export ANSIBLE_VARS_FILE="$profile_config"
    export DEPLOYMENT_PROFILE="$PROFILE"
}

# Execute ansible playbook
run_ansible_playbook() {
    local playbook="$1"
    local tags="${2:-}"
    
    info "Running Ansible playbook: $playbook"
    
    local ansible_cmd="ansible-playbook"
    local ansible_args=(
        "-i" "$CONFIGS_DIR/ansible/inventory/localhost.yml"
        "$CONFIGS_DIR/ansible/playbooks/$playbook.yml"
    )
    
    # Add tags if specified
    if [[ -n "$tags" ]]; then
        ansible_args+=("--tags" "$tags")
    fi
    
    # Add extra variables
    if [[ -n "${ANSIBLE_VARS_FILE:-}" ]]; then
        ansible_args+=("--extra-vars" "@$ANSIBLE_VARS_FILE")
    fi
    
    ansible_args+=("--extra-vars" "deployment_profile=$PROFILE")
    
    # Add verbose flag if enabled
    if [[ "$VERBOSE" == true ]]; then
        ansible_args+=("-v")
    fi
    
    # Execute or show dry run
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would execute: $ansible_cmd ${ansible_args[*]}"
        ansible_args+=("--check" "--diff")
    fi
    
    debug "Ansible command: $ansible_cmd ${ansible_args[*]}"
    
    if ! "$ansible_cmd" "${ansible_args[@]}"; then
        error "Ansible playbook failed: $playbook"
    fi
    
    success "Ansible playbook completed: $playbook"
}

# Execute deployment based on mode
execute_deployment() {
    info "Starting deployment: $DEPLOYMENT_MODE"
    
    case $DEPLOYMENT_MODE in
        full)
            run_ansible_playbook "bootstrap"
            run_ansible_playbook "desktop"
            run_ansible_playbook "security"
            # Only include power management if profile supports it
            if [[ "$PROFILE" != "minimal" ]]; then
                info "Including power management for profile: $PROFILE"
                # Power management would be included in local.yml or as separate playbook
            fi
            ;;
        bootstrap)
            run_ansible_playbook "bootstrap"
            ;;
        desktop)
            run_ansible_playbook "desktop"
            ;;
        security)
            run_ansible_playbook "security"
            ;;
        maintenance)
            run_ansible_playbook "maintenance"
            ;;
        power)
            # Run power management specific tasks
            run_ansible_playbook "bootstrap" "power"
            ;;
    esac
}

# Post-deployment tasks
post_deployment() {
    info "Running post-deployment tasks..."
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would run post-deployment validation"
        return 0
    fi
    
    # Validate key services
    local services=("NetworkManager" "sshd")
    
    if [[ "$DEPLOYMENT_MODE" == "full" || "$DEPLOYMENT_MODE" == "desktop" ]]; then
        services+=("sddm")
    fi
    
    if [[ "$DEPLOYMENT_MODE" == "full" || "$DEPLOYMENT_MODE" == "power" ]]; then
        services+=("tlp" "thermald")
    fi
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success "Service $service is running"
        else
            warn "Service $service is not running"
        fi
    done
    
    # Check for reboot requirement
    if [[ -f /var/run/reboot-required ]]; then
        warn "System reboot required to complete deployment"
    fi
}

# Generate deployment report
generate_report() {
    local report_file="/tmp/deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    info "Generating deployment report..."
    
    cat > "$report_file" << EOF
Arch Linux Hyprland Deployment Report
=====================================
Generated: $(date)
Profile: $PROFILE
Mode: $DEPLOYMENT_MODE
Dry Run: $DRY_RUN

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
- Kernel: $(uname -r)
- Hostname: $(hostnamectl --static)

Deployment Status:
- Started: $(head -1 "$LOG_FILE" | cut -d' ' -f1-2 || echo "Unknown")
- Completed: $(date)
- Log File: $LOG_FILE

Services Status:
$(systemctl --type=service --state=active --no-pager --no-legend | head -10 || echo "Could not retrieve services")

Next Steps:
1. Review the deployment log: $LOG_FILE
2. Test desktop environment functionality
3. Verify security configurations
4. Consider rebooting if kernel was updated

EOF

    success "Deployment report generated: $report_file"
}

# Main function
main() {
    echo -e "${BLUE}Arch Linux Hyprland Master Deployment Script${NC}"
    echo "=============================================="
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate inputs
    validate_inputs
    
    # Show system info
    show_system_info
    
    # Show deployment plan
    show_deployment_plan
    
    # Confirmation prompt
    if [[ "$SKIP_CONFIRMATION" == false && "$DRY_RUN" == false ]]; then
        echo -n "Proceed with deployment? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Start deployment
    info "Starting deployment process..."
    
    # Create backup
    backup_configuration
    
    # Load profile
    load_profile
    
    # Execute deployment
    execute_deployment
    
    # Post-deployment tasks
    post_deployment
    
    # Generate report
    generate_report
    
    success "Deployment completed successfully!"
    
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo -e "${GREEN}Deployment Summary:${NC}"
        echo "  Profile: $PROFILE"
        echo "  Mode: $DEPLOYMENT_MODE"
        echo "  Log: $LOG_FILE"
        echo "  Report: /tmp/deployment-report-$(date +%Y%m%d)*.txt"
        echo ""
        echo -e "${YELLOW}Consider rebooting to ensure all changes take effect.${NC}"
    fi
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi