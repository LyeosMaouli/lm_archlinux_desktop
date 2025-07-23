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
# This script downloads the complete project structure and runs deployment
# with full logging support. All logs are saved to USB for debugging.

set -euo pipefail

# =====================================
# CONFIGURATION - EDIT THIS SECTION
# =====================================

# Your GitHub repository details (required)
GITHUB_USERNAME="LyeosMaouli"
GITHUB_REPO="lm_archlinux_desktop"
GITHUB_BRANCH="main"

# No USB-specific password configuration needed - deploy.sh auto-detects .enc files

# Network configuration for initial setup
WIFI_SSID=""              # WiFi network name (empty = skip/prompt if needed)
WIFI_PASSWORD=""          # WiFi password (empty = prompt if SSID set)

# NOTE: System configuration (hostname, username, encryption, etc.) is now
# centralized in config/deploy.conf. Edit that file instead of this script.

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
║         [DEPLOY] USB Arch Linux Deployment Script            ║
║                                                              ║
║     Automated deployment from USB stick configuration        ║
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
    log_info "Downloading deployment script via git clone (ensures latest version)..."
    
    local temp_repo_dir="$USB_DIR/temp_repo"
    local repo_url="https://github.com/$GITHUB_USERNAME/$GITHUB_REPO.git"
    
    # Remove any existing temp directory
    rm -rf "$temp_repo_dir"
    
    # Install git if not available
    if ! command -v git >/dev/null 2>&1; then
        log_info "Installing git..."
        pacman -Sy --noconfirm git || {
            log_error "Failed to install git"
            return 1
        }
    fi
    
    # Clone the repository to get the absolute latest version
    if git clone "$repo_url" "$temp_repo_dir"; then
        log_success "Repository cloned successfully"
        
        # Copy the entire project structure to ensure all dependencies are available
        if [[ -d "$temp_repo_dir/scripts" ]]; then
            # Create project directory structure
            local project_dir="$USB_DIR/lm_archlinux_desktop"
            mkdir -p "$project_dir"
            
            # Copy essential directories
            cp -r "$temp_repo_dir/scripts" "$project_dir/"
            cp -r "$temp_repo_dir/configs" "$project_dir/" 2>/dev/null || true
            cp -r "$temp_repo_dir/templates" "$project_dir/" 2>/dev/null || true
            cp -r "$temp_repo_dir/files" "$project_dir/" 2>/dev/null || true
            cp -r "$temp_repo_dir/profiles" "$project_dir/" 2>/dev/null || true
            
            # Copy root files
            cp "$temp_repo_dir/local.yml" "$project_dir/" 2>/dev/null || true
            cp "$temp_repo_dir/Makefile" "$project_dir/" 2>/dev/null || true
            cp "$temp_repo_dir/README.md" "$project_dir/" 2>/dev/null || true
            cp "$temp_repo_dir/CLAUDE.md" "$project_dir/" 2>/dev/null || true
            
            # Make scripts executable
            chmod +x "$project_dir/scripts/deploy.sh"
            chmod +x "$project_dir/scripts"/**/*.sh 2>/dev/null || true
            
            # Show commit info for verification
            cd "$temp_repo_dir"
            local commit_sha=$(git rev-parse HEAD)
            local commit_date=$(git log -1 --format="%ci")
            cd - >/dev/null
            
            log_success "Complete project copied from latest commit: ${commit_sha:0:8}"
            log_info "Commit date: $commit_date"
            log_info "Project available at: $project_dir"
            
            # Copy any .enc files from USB to project root for auto-detection
            copy_enc_files_to_project "$project_dir"
            
            # Cleanup temp directory
            rm -rf "$temp_repo_dir"
            return 0
        else
            log_error "Scripts directory not found in repository"
            rm -rf "$temp_repo_dir"
            return 1
        fi
    else
        log_error "Failed to clone repository from: $repo_url"
        return 1
    fi
}

# Copy any .enc files from USB to project root for auto-detection
copy_enc_files_to_project() {
    local project_dir="$1"
    
    log_info "Checking for .enc password files on USB..."
    
    # Find all .enc files on USB (excluding the project directory itself)
    local enc_files=()
    while IFS= read -r -d '' enc_file; do
        # Skip if the .enc file is already inside the project directory
        if [[ "$enc_file" != "$project_dir"* ]]; then
            enc_files+=("$enc_file")
        fi
    done < <(find "$USB_DIR" -maxdepth 2 -name "*.enc" -type f -print0 2>/dev/null)
    
    if [[ ${#enc_files[@]} -eq 0 ]]; then
        log_info "No .enc password files found on USB"
        return 0
    fi
    
    log_success "Found ${#enc_files[@]} .enc file(s) on USB"
    
    # Copy each .enc file to project root
    for enc_file in "${enc_files[@]}"; do
        local filename=$(basename "$enc_file")
        local dest_file="$project_dir/$filename"
        
        log_info "Copying $filename to project root for auto-detection..."
        
        if cp "$enc_file" "$dest_file"; then
            log_success "Copied: $filename -> $dest_file"
            # Set secure permissions
            chmod 600 "$dest_file" 2>/dev/null || true
        else
            log_warn "Failed to copy $filename"
        fi
    done
    
    log_success "Encrypted password files ready for auto-detection by deploy.sh"
}

# Password file setup is no longer needed - deploy.sh auto-detects .enc files

# Setup environment variables for deployment
setup_environment() {
    log_info "Setting up deployment environment..."
    
    # Set GitHub repository info
    export DEPLOY_GITHUB_USERNAME="$GITHUB_USERNAME"
    export DEPLOY_GITHUB_REPO="$GITHUB_REPO"
    export DEPLOY_GITHUB_BRANCH="$GITHUB_BRANCH"
    
    # Note: System configuration (hostname, username, encryption, etc.) is now
    # managed through the centralized config/deploy.conf file that gets loaded automatically
    
    # Set WiFi configuration if provided
    [[ -n "$WIFI_SSID" ]] && export DEPLOY_WIFI_SSID="$WIFI_SSID"
    [[ -n "$WIFI_PASSWORD" ]] && export DEPLOY_WIFI_PASSWORD="$WIFI_PASSWORD"
    
    log_success "Environment configured"
}

# Configuration loading no longer needed - deploy.sh handles everything automatically

# Run deployment
run_deployment() {
    log_info "Starting Arch Linux deployment..."
    
    echo -e "${YELLOW}Deployment Configuration:${NC}"
    echo "  GitHub Repo: $GITHUB_USERNAME/$GITHUB_REPO"
    echo "  USB Directory: $USB_DIR"
    echo "  Configuration: deploy.sh will auto-detect and configure everything"
    echo "  Password Files: Auto-detected .enc files (if present)"
    
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
    
    # Change to project directory
    local project_dir="$USB_DIR/lm_archlinux_desktop"
    cd "$project_dir"
    
    # Run deployment - deploy.sh will auto-detect .enc files and configure itself
    log_info "Executing: ./scripts/deploy.sh full"
    log_info "Note: deploy.sh will auto-detect .enc files and update configuration automatically"
    
    ./scripts/deploy.sh full
}

# Show help
show_help() {
    cat << 'EOF'
USB Deployment Script for Arch Linux Hyprland

This script automates the deployment of Arch Linux with Hyprland desktop
from a USB stick with intelligent auto-detection and configuration.

Configuration:
1. Edit the CONFIGURATION section in this script:
   - GitHub repository details (required)
   - WiFi credentials for initial setup (optional)
2. Optionally copy .enc password files to USB - they will be auto-detected

The deploy.sh script will automatically detect and configure everything else.

Usage:
1. Edit the CONFIGURATION section in this script
2. Copy this script to USB stick
3. Optional: copy .enc password files to USB stick
4. Boot from Arch Linux ISO
5. Mount USB stick: mount /dev/sdX1 /mnt/usb
6. Run: cd /mnt/usb && ./usb-deploy.sh

The script will:
- Download the complete project from GitHub
- Auto-detect and copy .enc files to project root
- Run deploy.sh which auto-configures based on detected files
- Save all logs to USB for debugging

Password Handling:
- If .enc files found: Uses encrypted password files automatically
- If no .enc files: Generates secure passwords automatically
- All handled transparently by deploy.sh

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