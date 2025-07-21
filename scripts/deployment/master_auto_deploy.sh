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

# Password management configuration
PASSWORD_MODE="auto"
PASSWORD_FILE=""
FILE_PASSPHRASE=""
PASSWORDS_COLLECTED=false

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

debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${CYAN}DEBUG: $1${NC}" >&2
}

# Parse command line arguments
parse_arguments() {
    local mode="auto"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            auto|iso|desktop|vm|config|help|--help|-h)
                mode="$1"
                shift
                ;;
            --password-mode)
                PASSWORD_MODE="$2"
                info "Password mode set to: $PASSWORD_MODE"
                shift 2
                ;;
            --password-file)
                PASSWORD_FILE="$2"
                info "Password file set to: $PASSWORD_FILE"
                shift 2
                ;;
            --file-passphrase)
                FILE_PASSPHRASE="$2"
                info "File passphrase provided"
                shift 2
                ;;
            --config-file)
                CONFIG_FILE="$2"
                info "Config file set to: $CONFIG_FILE"
                shift 2
                ;;
            --debug)
                export DEBUG=true
                info "Debug mode enabled"
                shift
                ;;
            *)
                warn "Unknown argument: $1"
                shift
                ;;
        esac
    done
    
    echo "$mode"
}

# Validate password mode
validate_password_mode() {
    case "$PASSWORD_MODE" in
        "auto"|"env"|"file"|"generate"|"interactive")
            debug "Password mode validation passed: $PASSWORD_MODE"
            return 0
            ;;
        *)
            error "Invalid password mode: $PASSWORD_MODE. Valid modes: auto, env, file, generate, interactive"
            return 1
            ;;
    esac
}

# Validate password file requirements
validate_password_file_requirements() {
    if [[ "$PASSWORD_MODE" == "file" ]]; then
        if [[ -z "$PASSWORD_FILE" ]]; then
            error "Password file mode requires --password-file parameter"
            return 1
        fi
        
        if [[ ! -f "$PASSWORD_FILE" ]]; then
            error "Password file not found: $PASSWORD_FILE"
            return 1
        fi
        
        debug "Password file validation passed: $PASSWORD_FILE"
    fi
    
    return 0
}

# Load and integrate password management system
load_password_manager() {
    local password_manager="$SCRIPT_DIR/../security/password_manager.sh"
    
    debug "Looking for password manager at: $password_manager"
    
    if [[ -f "$password_manager" ]]; then
        info "Loading password management system..."
        source "$password_manager"
        debug "Password management system loaded successfully"
        return 0
    else
        warn "Password manager not found at: $password_manager"
        return 1
    fi
}

# Collect and export passwords
collect_and_export_passwords() {
    if [[ "$PASSWORDS_COLLECTED" == "true" ]]; then
        debug "Passwords already collected, skipping"
        return 0
    fi
    
    info "Collecting passwords using mode: $PASSWORD_MODE"
    
    # Validate password mode
    if ! validate_password_mode; then
        return 1
    fi
    
    # Validate password file requirements
    if ! validate_password_file_requirements; then
        return 1
    fi
    
    # Load password management system
    if ! load_password_manager; then
        case "$PASSWORD_MODE" in
            "file"|"env"|"generate")
                error "Password manager required for mode '$PASSWORD_MODE' but not available"
                return 1
                ;;
            *)
                warn "Password manager not available, falling back to interactive mode"
                return 1
                ;;
        esac
    fi
    
    # Set configuration for password manager
    export CONFIG_FILE="$CONFIG_FILE"
    export PASSWORD_FILE="$PASSWORD_FILE"
    export FILE_PASSPHRASE="$FILE_PASSPHRASE"
    
    debug "Password collection configuration:"
    debug "  CONFIG_FILE: $CONFIG_FILE"
    debug "  PASSWORD_FILE: ${PASSWORD_FILE:-not set}"
    debug "  FILE_PASSPHRASE: ${FILE_PASSPHRASE:+[SET]}${FILE_PASSPHRASE:-not set}"
    debug "  PASSWORD_MODE: $PASSWORD_MODE"
    
    # Collect passwords using the specified method
    if collect_passwords "$PASSWORD_MODE"; then
        info "Password collection successful"
        
        # Export passwords for child processes
        export_passwords
        
        # Mark as collected
        PASSWORDS_COLLECTED=true
        
        debug "Passwords exported to environment for child processes"
        return 0
    else
        case "$PASSWORD_MODE" in
            "file")
                error "Failed to decrypt password file: $PASSWORD_FILE"
                error "Please check file path and passphrase"
                ;;
            "env")
                error "Required environment variables not found"
                error "Please set DEPLOY_USER_PASSWORD, DEPLOY_ROOT_PASSWORD, etc."
                ;;
            "generate")
                error "Password generation failed"
                error "Check system entropy and random number generation"
                ;;
            "interactive")
                error "Interactive password collection failed"
                error "Check terminal input and password requirements"
                ;;
            *)
                error "Password collection failed for mode: $PASSWORD_MODE"
                ;;
        esac
        return 1
    fi
}

success() {
    echo -e "${GREEN}[OK] $1${NC}"
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
║     [DEPLOY] Automated Installation & Configuration               ║
║     🖥️  Modern Wayland Desktop Environment                   ║
║     [SECURE] Enterprise-Grade Security                              ║
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
  hostname: "desktop"
  timezone: "UTC"
  locale: "en_US.UTF-8"
  keymap: "en"

user:
  username: "user"
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

# Ensure repository is available
ensure_repository() {
    header "Repository Setup"
    
    # If running from a downloaded script, clone the repository
    if [[ ! -d "$PROJECT_ROOT" ]] || [[ ! -f "$PROJECT_ROOT/local.yml" ]]; then
        info "Repository not found locally, cloning..."
        
        # Install git if needed
        if ! command -v git >/dev/null 2>&1; then
            info "Installing Git..."
            if command -v pacman >/dev/null 2>&1; then
                pacman -S --noconfirm git || error "Failed to install Git"
            else
                error "Git not available and cannot install"
            fi
        fi
        
        # Determine clone location
        local clone_dir
        if [[ -w "/tmp" ]]; then
            clone_dir="/tmp/lm_archlinux_desktop"
        else
            clone_dir="$HOME/lm_archlinux_desktop"
        fi
        
        # Remove existing if present
        [[ -d "$clone_dir" ]] && rm -rf "$clone_dir"
        
        # Clone repository
        git clone "https://github.com/LyeosMaouli/lm_archlinux_desktop.git" "$clone_dir" || error "Failed to clone repository"
        
        # Update paths to point to cloned repository
        PROJECT_ROOT="$clone_dir"
        SCRIPT_DIR="$clone_dir/scripts/deployment"
        
        success "Repository cloned to: $PROJECT_ROOT"
    else
        info "Repository found at: $PROJECT_ROOT"
    fi
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
    
    # Export password environment variables for child process
    if [[ "$PASSWORDS_COLLECTED" == "true" ]]; then
        debug "Exporting password variables to child process..."
        [[ -n "${USER_PASSWORD:-}" ]] && export USER_PASSWORD
        [[ -n "${ROOT_PASSWORD:-}" ]] && export ROOT_PASSWORD
        [[ -n "${LUKS_PASSPHRASE:-}" ]] && export LUKS_PASSPHRASE
        [[ -n "${WIFI_PASSWORD:-}" ]] && export WIFI_PASSWORD
        debug "Password variables exported to installation script"
    else
        debug "No passwords collected, skipping password variable export"
    fi
    
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
    
    # Export password environment variables for child process
    if [[ "$PASSWORDS_COLLECTED" == "true" ]]; then
        debug "Exporting password variables to child process..."
        [[ -n "${USER_PASSWORD:-}" ]] && export USER_PASSWORD
        [[ -n "${ROOT_PASSWORD:-}" ]] && export ROOT_PASSWORD
        [[ -n "${LUKS_PASSPHRASE:-}" ]] && export LUKS_PASSPHRASE
        [[ -n "${WIFI_PASSWORD:-}" ]] && export WIFI_PASSWORD
        debug "Password variables exported to deployment script"
    else
        debug "No passwords collected, skipping password variable export"
    fi
    
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
║              [COMPLETE] DEPLOYMENT COMPLETED! [COMPLETE]                     ║
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
    # Parse command line arguments
    local mode
    mode=$(parse_arguments "$@")
    
    case "$mode" in
        "auto")
            # Automatic mode - detect and run appropriate workflow
            print_banner
            detect_system_state
            setup_configuration
            
            # Collect passwords early in the process
            if ! collect_and_export_passwords; then
                if [[ "$PASSWORD_MODE" != "auto" ]] && [[ "$PASSWORD_MODE" != "interactive" ]]; then
                    error "Password collection failed and no fallback available for mode: $PASSWORD_MODE"
                else
                    warn "Password collection failed, continuing with fallback methods"
                fi
            fi
            
            ensure_repository
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
            
            # Collect passwords for installation
            if ! collect_and_export_passwords; then
                if [[ "$PASSWORD_MODE" != "auto" ]] && [[ "$PASSWORD_MODE" != "interactive" ]]; then
                    error "Password collection failed and no fallback available for mode: $PASSWORD_MODE"
                else
                    warn "Password collection failed, continuing with fallback methods"
                fi
            fi
            
            ensure_repository
            prepare_scripts
            setup_network
            run_iso_installation
            ;;
            
        "desktop")
            # Desktop deployment only
            print_banner
            setup_configuration
            
            # Collect passwords for desktop deployment
            if ! collect_and_export_passwords; then
                if [[ "$PASSWORD_MODE" != "auto" ]] && [[ "$PASSWORD_MODE" != "interactive" ]]; then
                    error "Password collection failed and no fallback available for mode: $PASSWORD_MODE"
                else
                    warn "Password collection failed, continuing with fallback methods"
                fi
            fi
            
            ensure_repository
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
            ensure_repository
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
            echo "Usage: $0 [mode] [OPTIONS]"
            echo
            echo "Modes:"
            echo "  auto     - Automatic mode (detect and run appropriate workflow)"
            echo "  iso      - ISO installation only"
            echo "  desktop  - Desktop deployment only"
            echo "  vm       - VirtualBox testing mode"
            echo "  config   - Configuration setup only"
            echo "  help     - Show this help message"
            echo
            echo "Password Management Options:"
            echo "  --password-mode MODE    Password collection method (auto|env|file|generate|interactive)"
            echo "  --password-file FILE    Path to encrypted password file (for file mode)"
            echo "  --file-passphrase PASS  Passphrase for encrypted file (for file mode)"
            echo
            echo "Other Options:"
            echo "  --config-file FILE      Path to deployment configuration file"
            echo "  --debug                 Enable debug output"
            echo
            echo "Environment Variables:"
            echo "  CONFIG_FILE             Path to deployment configuration file"
            echo "  DEBUG                   Enable debug output (true/false)"
            echo
            echo "Password Modes:"
            echo "  auto        - Try methods in order: env → file → generate → interactive"
            echo "  env         - Use environment variables (DEPLOY_USER_PASSWORD, etc.)"
            echo "  file        - Use encrypted password file"
            echo "  generate    - Auto-generate secure passwords"
            echo "  interactive - Interactive password prompts"
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