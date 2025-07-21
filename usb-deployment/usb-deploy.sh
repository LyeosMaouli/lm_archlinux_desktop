#!/bin/bash
# USB Deployment Script for Arch Linux Hyprland
# 
# Instructions:
# 1. Copy this file to your USB stick
# 2. Edit the configuration section below with your details
# 3. Copy passwords.enc to the same USB directory (if using encrypted file method)
# 4. Boot from Arch Linux ISO
# 5. Mount USB stick and run: ./usb-deploy.sh
#
# This script handles everything automatically!

set -euo pipefail

# =====================================
# CONFIGURATION - EDIT THIS SECTION
# =====================================

# Your GitHub repository details
GITHUB_USERNAME="YOUR_USERNAME"
GITHUB_REPO="YOUR_REPO_NAME"
GITHUB_BRANCH="main"

# Deployment method (choose one):
# "file" - Use encrypted password file (passwords.enc must be on USB)
# "env" - Set environment variables (will prompt for passwords)
# "generate" - Auto-generate secure passwords
# "interactive" - Traditional prompts (original behavior)
PASSWORD_MODE="file"

# Password file settings (only for file mode)
PASSWORD_FILE_NAME="passwords.enc"  # Name of encrypted file on USB
# If using GitHub releases instead of USB file:
USE_GITHUB_RELEASE=false
GITHUB_RELEASE_TAG="latest"  # or specific tag like "v1.0"

# System configuration (optional - leave empty for auto-detection)
TARGET_HOSTNAME=""        # e.g., "my-archlinux" (empty = prompt)
TARGET_USERNAME=""        # e.g., "myuser" (empty = prompt)
TARGET_TIMEZONE=""        # e.g., "America/New_York" (empty = auto-detect)
TARGET_KEYMAP=""          # e.g., "us" (empty = auto-detect)
ENABLE_ENCRYPTION=""      # "true", "false", or empty = prompt

# Network configuration
WIFI_SSID=""              # WiFi network name (empty = skip/prompt)
WIFI_PASSWORD=""          # WiFi password (empty = prompt if SSID set)

# =====================================
# SCRIPT STARTS HERE - DO NOT EDIT
# =====================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Get script directory (USB mount point)
USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup logging
LOG_DIR="$USB_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/usb-deploy-$(date +%Y%m%d_%H%M%S).log"

# Function to log to both console and file
log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           [DEPLOY] USB Arch Linux Deployment Script              ║
║                                                              ║
║     Automated deployment from USB stick configuration       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_to_file "[INFO] $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_to_file "[SUCCESS] $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_to_file "[WARN] $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "[ERROR] $1"
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    if [[ "$GITHUB_USERNAME" == "YOUR_USERNAME" ]] || [[ -z "$GITHUB_USERNAME" ]]; then
        log_error "Please edit GITHUB_USERNAME in the script configuration"
        return 1
    fi
    
    if [[ "$GITHUB_REPO" == "YOUR_REPO_NAME" ]] || [[ -z "$GITHUB_REPO" ]]; then
        log_error "Please edit GITHUB_REPO in the script configuration"
        return 1
    fi
    
    if [[ "$PASSWORD_MODE" == "file" ]]; then
        if [[ "$USE_GITHUB_RELEASE" == "true" ]]; then
            log_info "Will download password file from GitHub release"
        else
            local password_file="$USB_DIR/$PASSWORD_FILE_NAME"
            if [[ ! -f "$password_file" ]]; then
                log_error "Password file not found: $password_file"
                log_error "Either copy $PASSWORD_FILE_NAME to USB or set USE_GITHUB_RELEASE=true"
                return 1
            fi
            log_success "Password file found on USB: $PASSWORD_FILE_NAME"
        fi
    fi
    
    log_success "Configuration validated"
    return 0
}

# Setup network if needed
setup_network() {
    log_info "Setting up network connection..."
    
    # Check if already connected
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log_success "Internet connection already available"
        return 0
    fi
    
    # Try ethernet first
    log_info "Attempting ethernet connection..."
    for iface in $(ip link show | grep -E "en[ospx]" | cut -d: -f2 | tr -d ' '); do
        ip link set "$iface" up 2>/dev/null || true
        dhcpcd "$iface" &
        sleep 3
        
        if ping -c 1 8.8.8.8 &>/dev/null; then
            log_success "Ethernet connected on $iface"
            return 0
        fi
    done
    
    # Setup WiFi if configured
    if [[ -n "$WIFI_SSID" ]]; then
        log_info "Connecting to WiFi network: $WIFI_SSID"
        
        if [[ -z "$WIFI_PASSWORD" ]]; then
            echo -n "Enter WiFi password for $WIFI_SSID: "
            read -s WIFI_PASSWORD
            echo
        fi
        
        # Use iwctl for WiFi connection
        local wifi_device
        wifi_device=$(iwctl device list | grep wlan | awk '{print $1}' | head -1)
        
        if [[ -n "$wifi_device" ]]; then
            iwctl station "$wifi_device" scan
            sleep 2
            echo "$WIFI_PASSWORD" | iwctl --passphrase - station "$wifi_device" connect "$WIFI_SSID"
            sleep 5
            
            if ping -c 1 8.8.8.8 &>/dev/null; then
                log_success "WiFi connected successfully"
                return 0
            fi
        fi
    fi
    
    # Manual WiFi setup if automatic failed
    log_warn "Automatic network setup failed"
    echo "Please set up network connection manually:"
    echo "- For WiFi: run 'wifi-menu'"
    echo "- For ethernet: check cable connection"
    echo
    read -p "Press Enter when internet connection is ready..."
    
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log_success "Internet connection confirmed"
        return 0
    else
        log_error "No internet connection available"
        return 1
    fi
}

# Download deployment script
download_deployment_script() {
    log_info "Downloading deployment script..."
    
    local script_url="https://raw.githubusercontent.com/$GITHUB_USERNAME/$GITHUB_REPO/$GITHUB_BRANCH/scripts/deployment/zero_touch_deploy.sh"
    
    if curl -fsSL "$script_url" -o "$USB_DIR/deploy.sh"; then
        chmod +x "$USB_DIR/deploy.sh"
        log_success "Deployment script downloaded"
        return 0
    else
        log_error "Failed to download deployment script from: $script_url"
        return 1
    fi
}

# Setup password file
setup_password_file() {
    if [[ "$PASSWORD_MODE" != "file" ]]; then
        return 0
    fi
    
    log_info "Setting up password file..."
    
    if [[ "$USE_GITHUB_RELEASE" == "true" ]]; then
        log_info "Downloading password file from GitHub release..."
        
        local release_url
        if [[ "$GITHUB_RELEASE_TAG" == "latest" ]]; then
            release_url="https://github.com/$GITHUB_USERNAME/$GITHUB_REPO/releases/latest/download/$PASSWORD_FILE_NAME"
        else
            release_url="https://github.com/$GITHUB_USERNAME/$GITHUB_REPO/releases/download/$GITHUB_RELEASE_TAG/$PASSWORD_FILE_NAME"
        fi
        
        if curl -L -o "$USB_DIR/$PASSWORD_FILE_NAME" "$release_url"; then
            log_success "Password file downloaded from GitHub release"
        else
            log_error "Failed to download password file from: $release_url"
            return 1
        fi
    else
        log_success "Using password file from USB stick"
    fi
    
    return 0
}

# Setup environment variables for deployment
setup_environment() {
    log_info "Setting up deployment environment..."
    
    # Set GitHub repository info
    export DEPLOY_GITHUB_USERNAME="$GITHUB_USERNAME"
    export DEPLOY_GITHUB_REPO="$GITHUB_REPO"
    export DEPLOY_GITHUB_BRANCH="$GITHUB_BRANCH"
    
    # Set system configuration if provided
    [[ -n "$TARGET_HOSTNAME" ]] && export DEPLOY_HOSTNAME="$TARGET_HOSTNAME"
    [[ -n "$TARGET_USERNAME" ]] && export DEPLOY_USERNAME="$TARGET_USERNAME"
    [[ -n "$TARGET_TIMEZONE" ]] && export DEPLOY_TIMEZONE="$TARGET_TIMEZONE"
    [[ -n "$TARGET_KEYMAP" ]] && export DEPLOY_KEYMAP="$TARGET_KEYMAP"
    [[ -n "$ENABLE_ENCRYPTION" ]] && export DEPLOY_ENABLE_ENCRYPTION="$ENABLE_ENCRYPTION"
    
    # Set WiFi configuration if provided
    [[ -n "$WIFI_SSID" ]] && export DEPLOY_WIFI_SSID="$WIFI_SSID"
    [[ -n "$WIFI_PASSWORD" ]] && export DEPLOY_WIFI_PASSWORD="$WIFI_PASSWORD"
    
    log_success "Environment configured"
}

# Run deployment
run_deployment() {
    log_info "Starting Arch Linux deployment..."
    
    echo -e "${YELLOW}Deployment Configuration:${NC}"
    echo "  Password Mode: $PASSWORD_MODE"
    echo "  GitHub Repo: $GITHUB_USERNAME/$GITHUB_REPO"
    echo "  USB Directory: $USB_DIR"
    
    if [[ "$PASSWORD_MODE" == "file" ]]; then
        echo "  Password File: $PASSWORD_FILE_NAME"
    fi
    
    echo
    echo -e "${BLUE}The deployment will now start...${NC}"
    echo "This process typically takes 30-60 minutes."
    echo "The system will reboot automatically when complete."
    echo
    
    read -p "Continue with deployment? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warn "Deployment cancelled by user"
        return 1
    fi
    
    # Change to USB directory
    cd "$USB_DIR"
    
    # Run deployment with appropriate parameters
    case "$PASSWORD_MODE" in
        "file")
            ./deploy.sh --password-mode file --password-file "$USB_DIR/$PASSWORD_FILE_NAME"
            ;;
        "env")
            ./deploy.sh --password-mode env
            ;;
        "generate")
            ./deploy.sh --password-mode generate
            ;;
        "interactive")
            ./deploy.sh --password-mode interactive
            ;;
        *)
            log_error "Unknown password mode: $PASSWORD_MODE"
            return 1
            ;;
    esac
}

# Show help
show_help() {
    cat << 'EOF'
USB Deployment Script for Arch Linux Hyprland

This script automates the deployment of Arch Linux with Hyprland desktop
from a USB stick with pre-configured settings.

Configuration:
Edit the CONFIGURATION section at the top of this script with:
- Your GitHub username and repository name
- Desired password mode (file/env/generate/interactive)
- System settings (hostname, username, timezone, etc.)
- Network settings (WiFi SSID and password)

Usage:
1. Edit the configuration section in this script
2. Copy this script to USB stick
3. For file mode: copy passwords.enc to USB stick
4. Boot from Arch Linux ISO
5. Mount USB stick: mount /dev/sdX1 /mnt/usb
6. Run: cd /mnt/usb && ./usb-deploy.sh

Password Modes:
- file: Use encrypted password file (passwords.enc)
- env: Prompt for passwords and set environment variables
- generate: Auto-generate secure passwords
- interactive: Traditional interactive prompts

For more information, visit:
https://github.com/LyeosMaouli/lm_archlinux_desktop

EOF
}

# Main execution
main() {
    case "${1:-deploy}" in
        "help"|"--help"|"-h")
            show_help
            exit 0
            ;;
        "deploy")
            print_banner
            
            log_info "Starting USB deployment process..."
            log_info "USB Directory: $USB_DIR"
            log_info "Log file: $LOG_FILE"
            echo "USB Directory: $USB_DIR"
            echo "Log file: $LOG_FILE"
            echo
            
            # Validate configuration
            if ! validate_config; then
                echo
                log_error "Please fix configuration issues and try again"
                exit 1
            fi
            
            # Setup network
            if ! setup_network; then
                log_error "Network setup failed"
                exit 1
            fi
            
            # Download deployment script
            if ! download_deployment_script; then
                log_error "Failed to download deployment script"
                exit 1
            fi
            
            # Setup password file if needed
            if ! setup_password_file; then
                log_error "Password file setup failed"
                exit 1
            fi
            
            # Setup environment
            setup_environment
            
            # Run deployment
            if run_deployment; then
                log_success "Deployment completed successfully!"
            else
                log_error "Deployment failed"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [deploy|help]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"