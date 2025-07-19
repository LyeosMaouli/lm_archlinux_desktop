#!/bin/bash
# Master Automated Deployment Script
# This script orchestrates the complete automated installation and deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/deployment_config.yml}"
LOG_FILE="/var/log/master_auto_deploy.log"

# Default configuration URL for download
CONFIG_URL="https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/deployment_config.yml"

# System state detection
LIVE_ISO=false
INSTALLED_SYSTEM=false
VM_ENVIRONMENT=false

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

header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
    log "PHASE: $1"
}

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Arch Linux Hyprland Desktop Automation System            ║
║                                                               ║
║     🚀 Automated Installation & Configuration               ║
║     🖥️  Modern Wayland Desktop Environment                   ║
║     🔒 Enterprise-Grade Security                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Detect system state
detect_system_state() {
    info "Detecting system environment..."
    
    # Check if running on live ISO
    if [[ -f /usr/bin/pacstrap ]] && [[ -d /run/archiso ]]; then
        LIVE_ISO=true
        info "Running on Arch Linux live ISO"
    elif [[ -d /home ]] && [[ -f /etc/arch-release ]]; then
        INSTALLED_SYSTEM=true
        info "Running on installed Arch Linux system"
    else
        error "Unable to determine system state"
    fi
    
    # Check for VM environment
    if dmidecode -s system-product-name 2>/dev/null | grep -qi "virtualbox\|vmware\|qemu"; then
        VM_ENVIRONMENT=true
        info "Virtual machine environment detected"
    elif systemd-detect-virt -q; then
        VM_ENVIRONMENT=true
        info "Virtualized environment detected"
    fi
    
    export LIVE_ISO INSTALLED_SYSTEM VM_ENVIRONMENT
}

# Download and setup configuration
setup_configuration() {
    header "Configuration Setup"
    
    # Check if configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Configuration file not found at: $CONFIG_FILE"
        
        # Try to download default configuration
        if command -v curl >/dev/null 2>&1; then
            info "Downloading default configuration..."
            curl -fsSL "$CONFIG_URL" -o "$CONFIG_FILE" || {
                warn "Failed to download configuration, creating minimal config"
                create_minimal_config
            }
        elif command -v wget >/dev/null 2>&1; then
            info "Downloading default configuration..."
            wget -q "$CONFIG_URL" -O "$CONFIG_FILE" || {
                warn "Failed to download configuration, creating minimal config"
                create_minimal_config
            }
        else
            warn "No download tool available, creating minimal config"
            create_minimal_config
        fi
    fi
    
    # Validate configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        success "Configuration file available: $CONFIG_FILE"
        
        # Show configuration summary
        show_config_summary
        
        # Ask for confirmation unless in unattended mode
        local skip_confirmations=$(grep -E "^\s*skip_confirmations:" "$CONFIG_FILE" 2>/dev/null | cut -d':' -f2 | xargs | tr -d '"' || echo "false")
        
        if [[ "$skip_confirmations" != "true" ]]; then
            echo
            echo -e "${YELLOW}Review the configuration above. Continue with deployment? [y/N]${NC}"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                info "Deployment cancelled by user"
                exit 0
            fi
        fi
    else
        error "Failed to create configuration file"
    fi
}

# Create minimal configuration
create_minimal_config() {
    info "Creating minimal configuration..."
    
    cat > "$CONFIG_FILE" << 'EOF'
# Minimal Deployment Configuration
system:
  hostname: "phoenix"
  timezone: "Europe/Paris"
  locale: "en_US.UTF-8"
  keymap: "fr"

user:
  username: "lyeosmaouli"
  password: ""  # Will be prompted
  shell: "/bin/bash"

network:
  ethernet:
    enabled: true
    dhcp: true
  wifi:
    enabled: false

disk:
  device: "/dev/nvme0n1"
  encryption:
    enabled: true
    passphrase: ""  # Will be prompted

automation:
  skip_confirmations: false
  auto_reboot: false
EOF
    
    success "Minimal configuration created"
}

# Show configuration summary
show_config_summary() {
    info "Configuration Summary:"
    echo
    
    # Parse key configuration values
    local hostname=$(grep -E "^\s*hostname:" "$CONFIG_FILE" | cut -d':' -f2 | xargs | tr -d '"' || echo "not set")
    local username=$(grep -A5 "^user:" "$CONFIG_FILE" | grep -E "^\s*username:" | cut -d':' -f2 | xargs | tr -d '"' || echo "not set")
    local disk_device=$(grep -A5 "^disk:" "$CONFIG_FILE" | grep -E "^\s*device:" | cut -d':' -f2 | xargs | tr -d '"' || echo "not set")
    local encryption=$(grep -A5 "encryption:" "$CONFIG_FILE" | grep -E "^\s*enabled:" | cut -d':' -f2 | xargs | tr -d '"' || echo "not set")
    
    echo -e "  ${CYAN}Hostname:${NC} $hostname"
    echo -e "  ${CYAN}Username:${NC} $username"
    echo -e "  ${CYAN}Target Disk:${NC} $disk_device"
    echo -e "  ${CYAN}Encryption:${NC} $encryption"
    echo
}

# Make scripts executable
prepare_scripts() {
    header "Preparing Scripts"
    
    local scripts=(
        "$SCRIPT_DIR/auto_install.sh"
        "$SCRIPT_DIR/auto_deploy.sh"
        "$SCRIPT_DIR/auto_post_install.sh"
        "$PROJECT_ROOT/scripts/testing/auto_vm_test.sh"
        "$PROJECT_ROOT/scripts/utilities/network_auto_setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            success "Made executable: $(basename "$script")"
        else
            warn "Script not found: $script"
        fi
    done
}

# Run live ISO installation
run_iso_installation() {
    header "Live ISO Installation"
    
    local install_script="$SCRIPT_DIR/auto_install.sh"
    
    if [[ ! -f "$install_script" ]]; then
        error "Installation script not found: $install_script"
    fi
    
    info "Starting automated base system installation..."
    
    # Export configuration file path
    export CONFIG_FILE
    
    # Run the installation script
    "$install_script" || error "Base system installation failed"
    
    success "Base system installation completed"
    info "System will reboot to continue with desktop deployment"
}

# Run desktop deployment
run_desktop_deployment() {
    header "Desktop Environment Deployment"
    
    local deploy_script="$SCRIPT_DIR/auto_deploy.sh"
    
    if [[ ! -f "$deploy_script" ]]; then
        error "Deployment script not found: $deploy_script"
    fi
    
    info "Starting automated desktop deployment..."
    
    # Export configuration file path
    export CONFIG_FILE
    
    # Run the deployment script
    "$deploy_script" || error "Desktop deployment failed"
    
    success "Desktop deployment completed"
}

# Run post-installation tasks
run_post_installation() {
    header "Post-Installation Configuration"
    
    local post_script="$SCRIPT_DIR/auto_post_install.sh"
    
    if [[ -f "$post_script" ]]; then
        info "Running post-installation configuration..."
        
        # Export configuration file path
        export CONFIG_FILE
        
        # Run post-installation script
        "$post_script" || warn "Some post-installation tasks failed"
        
        success "Post-installation configuration completed"
    else
        warn "Post-installation script not found, skipping"
    fi
}

# Run VM-specific testing
run_vm_testing() {
    header "VirtualBox Testing"
    
    local vm_script="$PROJECT_ROOT/scripts/testing/auto_vm_test.sh"
    
    if [[ -f "$vm_script" ]]; then
        info "Running VirtualBox-specific testing..."
        
        # Export configuration file path
        export CONFIG_FILE
        
        # Run VM testing script
        "$vm_script" || warn "Some VM tests failed"
        
        success "VirtualBox testing completed"
    else
        warn "VM testing script not found"
    fi
}

# Network setup
setup_network() {
    header "Network Configuration"
    
    local network_script="$PROJECT_ROOT/scripts/utilities/network_auto_setup.sh"
    
    if [[ -f "$network_script" ]]; then
        info "Setting up network connectivity..."
        
        # Export configuration file path
        export CONFIG_FILE
        
        # Run network setup
        "$network_script" quick || warn "Network setup encountered issues"
        
        success "Network configuration completed"
    else
        warn "Network script not found, manual configuration may be needed"
    fi
}

# Show completion message
show_completion() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              🎉 DEPLOYMENT COMPLETED! 🎉                     ║
║                                                               ║
║     Your Arch Linux Hyprland system is ready!                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Reboot the system: ${YELLOW}sudo reboot${NC}"
    echo "2. Log in and select 'Hyprland' session"
    echo "3. Test key bindings:"
    echo "   - ${YELLOW}Super + T${NC} → Terminal"
    echo "   - ${YELLOW}Super + R${NC} → Application launcher"
    echo "   - ${YELLOW}Super + E${NC} → File manager"
    echo
    echo -e "${CYAN}System Information:${NC}"
    echo "- Configuration: ${YELLOW}$CONFIG_FILE${NC}"
    echo "- Logs: ${YELLOW}$LOG_FILE${NC}"
    echo "- Status check: ${YELLOW}system-status${NC}"
    echo "- Updates: ${YELLOW}system-update${NC}"
    echo
    
    # Check if auto-reboot is enabled
    local auto_reboot=$(grep -E "^\s*auto_reboot:" "$CONFIG_FILE" 2>/dev/null | cut -d':' -f2 | xargs | tr -d '"' || echo "false")
    
    if [[ "$auto_reboot" == "true" ]]; then
        echo -e "${YELLOW}Auto-reboot enabled. System will reboot in 10 seconds...${NC}"
        countdown "Rebooting" 10
        sudo reboot
    fi
}

# Countdown function
countdown() {
    local message="$1"
    local seconds="$2"
    
    while [[ $seconds -gt 0 ]]; do
        echo -ne "\r$message in $seconds seconds (Ctrl+C to cancel)... "
        sleep 1
        ((seconds--))
    done
    echo
}

# Main orchestration function
main() {
    # Handle command line arguments
    local mode="${1:-auto}"
    
    case "$mode" in
        "auto")
            # Automatic mode - detect and run appropriate workflow
            print_banner
            detect_system_state
            setup_configuration
            prepare_scripts
            
            if [[ "$LIVE_ISO" == true ]]; then
                info "Live ISO detected - running full installation workflow"
                setup_network
                run_iso_installation
                # System will reboot here
                
            elif [[ "$INSTALLED_SYSTEM" == true ]]; then
                info "Installed system detected - running desktop deployment"
                setup_network
                run_desktop_deployment
                run_post_installation
                
                if [[ "$VM_ENVIRONMENT" == true ]]; then
                    run_vm_testing
                fi
                
                show_completion
            fi
            ;;
            
        "iso")
            # ISO installation only
            print_banner
            detect_system_state
            setup_configuration
            prepare_scripts
            setup_network
            run_iso_installation
            ;;
            
        "desktop")
            # Desktop deployment only
            print_banner
            setup_configuration
            prepare_scripts
            setup_network
            run_desktop_deployment
            run_post_installation
            show_completion
            ;;
            
        "vm")
            # VM testing mode
            print_banner
            setup_configuration
            prepare_scripts
            
            if [[ "$VM_ENVIRONMENT" == true ]]; then
                run_vm_testing
            else
                warn "Not running in VM environment"
            fi
            ;;
            
        "config")
            # Configuration setup only
            setup_configuration
            ;;
            
        "help"|"--help"|"-h")
            echo "Usage: $0 [mode]"
            echo
            echo "Modes:"
            echo "  auto     - Automatic mode (detect and run appropriate workflow)"
            echo "  iso      - ISO installation only"
            echo "  desktop  - Desktop deployment only"
            echo "  vm       - VirtualBox testing mode"
            echo "  config   - Configuration setup only"
            echo "  help     - Show this help message"
            echo
            echo "Environment Variables:"
            echo "  CONFIG_FILE - Path to deployment configuration file"
            echo
            exit 0
            ;;
            
        *)
            error "Unknown mode: $mode. Use 'help' for usage information."
            ;;
    esac
}

# Trap to handle interruption
trap 'echo -e "\n${YELLOW}Deployment interrupted by user${NC}"; exit 130' INT

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi