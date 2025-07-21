#!/bin/bash
# Zero-Touch Deployment Script
# Completely automated deployment with minimal user interaction
# Now with advanced password management support

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_MODE="auto"
PASSWORD_FILE=""
FILE_PASSPHRASE=""

# Load password management system
load_password_manager() {
    local password_manager_paths=(
        "$SCRIPT_DIR/../security/password_manager.sh"
        "./scripts/security/password_manager.sh"
        "/tmp/password_manager.sh"
    )
    
    for password_manager in "${password_manager_paths[@]}"; do
        if [[ -f "$password_manager" ]]; then
            source "$password_manager"
            echo -e "${GREEN}[SUCCESS] Password management system loaded from: $password_manager${NC}"
            return 0
        fi
    done
    
    # If not found locally, try to download from GitHub
    echo -e "${YELLOW}[WARNING] Password management system not found locally, downloading...${NC}"
    local github_url="https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/security/password_manager.sh"
    
    if curl -fsSL "$github_url" -o "/tmp/password_manager.sh"; then
        chmod +x "/tmp/password_manager.sh"
        source "/tmp/password_manager.sh"
        echo -e "${GREEN}[SUCCESS] Password management system downloaded and loaded${NC}"
        return 0
    else
        echo -e "${RED}[ERROR] Failed to load password management system${NC}"
        echo -e "${RED}   Tried paths: ${password_manager_paths[*]}${NC}"
        echo -e "${RED}   GitHub download failed: $github_url${NC}"
        return 1
    fi
}

print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     [DEPLOY] Arch Linux Hyprland - Zero Touch Deploy            ║
║                                                              ║
║     The easiest way to get a complete desktop system        ║
║     Advanced password management with multiple modes!       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Smart defaults detection
detect_defaults() {
    echo -e "${BLUE}[DETECT] Auto-detecting system configuration...${NC}"
    
    # Detect timezone
    if command -v timedatectl >/dev/null 2>&1; then
        DEFAULT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    else
        DEFAULT_TIMEZONE="UTC"
    fi
    
    # Detect keyboard layout from current session
    if [[ -n "${LANG:-}" ]]; then
        case "$LANG" in
            fr_*) DEFAULT_KEYMAP="fr" ;;
            de_*) DEFAULT_KEYMAP="de" ;;
            es_*) DEFAULT_KEYMAP="es" ;;
            *) DEFAULT_KEYMAP="us" ;;
        esac
    else
        DEFAULT_KEYMAP="us"
    fi
    
    # Auto-detect best disk
    echo "Available storage devices:"
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E "disk" | head -5
    
    # Find the largest disk
    DEFAULT_DISK=$(lsblk -d -o NAME,SIZE -b | grep -E "sd|nvme|vd" | sort -k2 -nr | head -1 | awk '{print "/dev/" $1}')
    
    echo -e "${GREEN}[SUCCESS] Auto-detection completed${NC}"
}

# Minimal prompts - only the essentials
minimal_prompts() {
    echo -e "${BLUE}[CONFIG] Quick Setup (3 questions only!)${NC}"
    echo
    
    # 1. Username
    read -p "[USER] Your username [default: user]: " username
    username=${username:-user}
    
    # 2. Computer name
    read -p "[SYSTEM] Computer name [default: archlinux]: " hostname
    hostname=${hostname:-archlinux}
    
    # 3. Enable encryption
    echo
    echo "[SECURE] Disk encryption protects your data if laptop is stolen"
    read -p "Enable full disk encryption? [Y/n]: " encrypt
    if [[ "$encrypt" =~ ^[Nn]$ ]]; then
        enable_encryption="false"
        echo "[WARNING]  Encryption disabled - data will not be protected"
    else
        enable_encryption="true"
        echo "[SUCCESS] Encryption enabled - maximum security"
    fi
    
    echo
    echo -e "${GREEN}[SUCCESS] Configuration complete!${NC}"
    echo "Using smart defaults for everything else..."
}

# Create complete configuration automatically
create_auto_config() {
    local config_file="/tmp/zero_touch_config.yml"
    
    echo -e "${BLUE}⚙️  Generating configuration...${NC}"
    
    cat > "$config_file" << EOF
# Zero-Touch Deployment Configuration
# Auto-generated on $(date)

system:
  hostname: "$hostname"
  timezone: "$DEFAULT_TIMEZONE"
  locale: "en_US.UTF-8"
  keymap: "$DEFAULT_KEYMAP"

user:
  username: "$username"
  password: ""  # Will be prompted securely
  shell: "/bin/bash"
  groups:
    - wheel
    - audio
    - video
    - network
    - storage
    - input
    - optical

network:
  ethernet:
    enabled: true
    dhcp: true
  wifi:
    enabled: true
    ssid: "AUTO_DETECT"
    password: "PROMPT_WHEN_NEEDED"
    security: "wpa2"

disk:
  device: "$DEFAULT_DISK"
  encryption:
    enabled: $enable_encryption
    passphrase: ""  # Will be prompted securely
  partitions:
    efi_size: "512M"
    swap_size: "4G"
  filesystem: "ext4"

bootloader:
  type: "systemd-boot"
  timeout: 3
  quiet_boot: true

desktop:
  environment: "hyprland"
  display_manager: "sddm"
  theme: "catppuccin-mocha"
  auto_login: false
  wallpaper: "nature"

packages:
  aur:
    packages:
      - visual-studio-code-bin
      - firefox
      - discord
      - spotify
      - hyprpaper
      - bibata-cursor-theme

security:
  firewall:
    enabled: true
    default_policy: "deny"
  fail2ban:
    enabled: true
    ssh_protection: true
  audit:
    enabled: true
  ssh:
    port: 22
    password_auth: false
    root_login: false

automation:
  skip_confirmations: true
  auto_reboot: true
  backup_configs: true
  log_level: "info"

power_management:
  enabled: true
  tlp_enabled: true
  cpu_governor_ac: "performance"
  cpu_governor_battery: "powersave"

development:
  git:
    username: ""
    email: ""
  ssh_keys:
    generate: true
    type: "ed25519"
  tools:
    - neovim
    - tmux
    - htop
    - tree
    - docker
EOF

    echo "$config_file"
}

# Automatic WiFi connection function
connect_wifi_auto() {
    local ssid="$1"
    local password="$2"
    
    echo "Connecting to WiFi network: $ssid"
    
    # Get WiFi device
    local wifi_device
    wifi_device=$(iwctl device list | grep wlan | awk '{print $1}' | head -1)
    
    if [[ -z "$wifi_device" ]]; then
        echo "No WiFi device found"
        return 1
    fi
    
    # Scan for networks
    iwctl station "$wifi_device" scan >/dev/null 2>&1
    sleep 3
    
    # Check if network is available
    if ! iwctl station "$wifi_device" get-networks | grep -q "$ssid"; then
        echo "Network '$ssid' not found in scan results"
        return 1
    fi
    
    # Connect to network
    if echo "$password" | iwctl --passphrase - station "$wifi_device" connect "$ssid" >/dev/null 2>&1; then
        echo "WiFi connection initiated..."
        sleep 10
        
        # Verify connection
        if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
            echo "WiFi connection successful"
            return 0
        else
            echo "WiFi connected but no internet access"
            return 1
        fi
    else
        echo "Failed to connect to WiFi network"
        return 1
    fi
}

# Network auto-setup
setup_network_auto() {
    echo -e "${BLUE}[NETWORK] Setting up internet connection...${NC}"
    
    # Check if already connected
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}[SUCCESS] Internet already connected!${NC}"
        return 0
    fi
    
    # Try ethernet first
    echo "Trying ethernet connection..."
    for iface in $(ip link show | grep -E "en[ospx]" | cut -d: -f2 | tr -d ' '); do
        ip link set "$iface" up
        dhcpcd "$iface" &
        sleep 3
        
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}[SUCCESS] Ethernet connected!${NC}"
            return 0
        fi
    done
    
    # Try WiFi if ethernet failed
    if iwctl device list 2>/dev/null | grep -q "wlan"; then
        echo "Ethernet not available, trying WiFi..."
        
        # Check for automatic WiFi credentials
        if [[ -n "${DEPLOY_WIFI_SSID:-}" ]] && [[ -n "${DEPLOY_WIFI_PASSWORD:-}" ]]; then
            echo "Found WiFi credentials, connecting automatically..."
            if connect_wifi_auto "$DEPLOY_WIFI_SSID" "$DEPLOY_WIFI_PASSWORD"; then
                echo -e "${GREEN}[SUCCESS] WiFi connected automatically!${NC}"
                return 0
            else
                echo -e "${YELLOW}[WARNING]  Automatic WiFi connection failed, falling back to manual${NC}"
            fi
        fi
        
        # Fallback to manual WiFi setup
        echo "Opening WiFi setup..."
        echo "Please connect to your WiFi network and then press Enter to continue"
        wifi-menu || true
        
        # Give time for connection
        sleep 5
        
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}[SUCCESS] WiFi connected!${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}[WARNING]  No internet connection available${NC}"
    echo "Please ensure you have an internet connection before continuing."
    echo "You can:"
    echo "1. Connect ethernet cable"
    echo "2. Run 'wifi-menu' to connect to WiFi"
    echo "3. Press Enter when connected"
    
    read -p "Press Enter when internet is ready..."
    
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}[SUCCESS] Internet connected!${NC}"
        return 0
    else
        echo -e "${RED}[ERROR] Still no internet connection${NC}"
        return 1
    fi
}

# Advanced password collection using password management system
collect_deployment_passwords() {
    echo -e "${BLUE}[PASSWORD] Advanced Password Management${NC}"
    echo "Multiple password input methods available for maximum flexibility."
    echo
    
    # Load password management system
    if ! load_password_manager; then
        echo -e "${RED}[ERROR] Failed to load password management system${NC}"
        return 1
    fi
    
    # Set configuration for password manager
    export CONFIG_FILE="$config_file"
    export PASSWORD_FILE="$PASSWORD_FILE"
    export FILE_PASSPHRASE="$FILE_PASSPHRASE"
    
    # Show password mode information
    case "$PASSWORD_MODE" in
        "auto")
            echo -e "${BLUE}Using automatic password detection:${NC}"
            echo "  1️⃣ Environment variables (CI/CD)"
            echo "  2️⃣ Encrypted password file" 
            echo "  3️⃣ Auto-generated passwords"
            echo "  4️⃣ Interactive prompts (fallback)"
            ;;
        "env")
            echo -e "${BLUE}Using environment variable passwords${NC}"
            echo "Checking for DEPLOY_USER_PASSWORD, DEPLOY_ROOT_PASSWORD, etc."
            ;;
        "file")
            echo -e "${BLUE}Using encrypted password file: $PASSWORD_FILE${NC}"
            ;;
        "generate")
            echo -e "${BLUE}Using auto-generated secure passwords${NC}"
            echo "Passwords will be displayed after generation"
            ;;
        "interactive")
            echo -e "${BLUE}Using interactive password prompts${NC}"
            ;;
    esac
    echo
    
    # Collect passwords using the specified method
    if collect_passwords "$PASSWORD_MODE"; then
        echo -e "${GREEN}[SUCCESS] Password collection successful${NC}"
        
        # Show password status
        show_password_status
        
        # Export passwords for deployment scripts
        export_passwords
        
        return 0
    else
        echo -e "${RED}[ERROR] Password collection failed${NC}"
        return 1
    fi
}

# Download and run deployment
run_deployment() {
    echo -e "${BLUE}[DOWNLOAD] Downloading deployment system...${NC}"
    
    # Install git if needed
    if ! command -v git >/dev/null 2>&1; then
        echo "Installing git..."
        pacman -Sy --noconfirm git
    fi
    
    # Clone repository
    if [[ -d /tmp/lm_archlinux_desktop ]]; then
        rm -rf /tmp/lm_archlinux_desktop
    fi
    
    git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git /tmp/lm_archlinux_desktop
    
    # Copy configuration
    cp "$config_file" /tmp/lm_archlinux_desktop/deployment_config.yml
    
    # Environment variables are already set by password manager
    # Verify they are available
    if [[ -z "${USER_PASSWORD:-}" ]] || [[ -z "${ROOT_PASSWORD:-}" ]]; then
        echo -e "${RED}[ERROR] Required passwords not available${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[DEPLOY] Starting automated deployment...${NC}"
    echo "This will take 30-60 minutes. Sit back and relax!"
    echo
    
    # Run deployment
    cd /tmp/lm_archlinux_desktop
    chmod +x scripts/deployment/master_auto_deploy.sh
    ./scripts/deployment/master_auto_deploy.sh auto
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --password-mode)
                PASSWORD_MODE="$2"
                shift 2
                ;;
            --password-file)
                PASSWORD_FILE="$2"
                shift 2
                ;;
            --file-passphrase)
                FILE_PASSPHRASE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help information
show_help() {
    cat << 'EOF'
Zero-Touch Deployment Script - Advanced Password Management

Usage: zero_touch_deploy.sh [OPTIONS]

Password Management Options:
  --password-mode MODE        Password input method (auto|env|file|generate|interactive)
  --password-file FILE        Path to encrypted password file (for file mode)
  --file-passphrase PHRASE    Passphrase for encrypted file (for file mode)

Password Modes:
  auto        - Automatic detection (env → file → generate → interactive)
  env         - Use environment variables (DEPLOY_USER_PASSWORD, etc.)
  file        - Use encrypted password file
  generate    - Auto-generate secure passwords
  interactive - Interactive password prompts (original behavior)

Environment Variables (for env mode):
  DEPLOY_USER_PASSWORD     - User account password
  DEPLOY_ROOT_PASSWORD     - Root account password
  DEPLOY_LUKS_PASSPHRASE   - LUKS encryption passphrase
  DEPLOY_WIFI_SSID         - WiFi network name (SSID)
  DEPLOY_WIFI_PASSWORD     - WiFi network password

Examples:

1. Automatic mode (tries all methods):
   ./zero_touch_deploy.sh

2. CI/CD with environment variables:
   export DEPLOY_USER_PASSWORD="secure_password"
   export DEPLOY_ROOT_PASSWORD="secure_password"
   ./zero_touch_deploy.sh --password-mode env

3. Encrypted password file:
   ./zero_touch_deploy.sh --password-mode file --password-file passwords.enc

4. Auto-generated passwords:
   ./zero_touch_deploy.sh --password-mode generate

5. Traditional interactive mode:
   ./zero_touch_deploy.sh --password-mode interactive

EOF
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    print_banner
    
    # Check we're on Arch Linux
    if [[ ! -f /etc/arch-release ]] && [[ ! -d /run/archiso ]]; then
        echo -e "${RED}[ERROR] This script requires Arch Linux${NC}"
        echo "Please boot from an Arch Linux ISO"
        exit 1
    fi
    
    echo -e "${GREEN}Welcome to the easiest Arch Linux Hyprland installation!${NC}"
    echo "This script will set up a complete modern desktop with advanced password management:"
    echo "1. [CONFIG] Answer 3 quick questions"
    echo "2. [PASSWORD] Handle passwords securely (mode: $PASSWORD_MODE)"  
    echo "3. [DEPLOY] Automated installation (30-60 minutes)"
    echo
    read -p "Ready to get started? [Y/n]: " ready
    
    if [[ "$ready" =~ ^[Nn]$ ]]; then
        echo "Setup cancelled. Run this script again when ready!"
        exit 0
    fi
    
    # Step 1: Auto-detection and minimal prompts
    detect_defaults
    echo
    minimal_prompts
    echo
    
    # Step 2: Create configuration
    config_file=$(create_auto_config)
    echo -e "${GREEN}[SUCCESS] Configuration created: $config_file${NC}"
    echo
    
    # Step 3: Network setup
    if ! setup_network_auto; then
        echo -e "${RED}[ERROR] Network setup failed${NC}"
        exit 1
    fi
    echo
    
    # Step 4: Password collection
    collect_deployment_passwords
    echo
    
    # Step 5: Final confirmation
    echo -e "${YELLOW}[LIST] Ready to install with these settings:${NC}"
    echo "  Computer name: $hostname"
    echo "  Username: $username"
    echo "  Timezone: $DEFAULT_TIMEZONE"
    echo "  Keyboard: $DEFAULT_KEYMAP"
    echo "  Disk: $DEFAULT_DISK"
    echo "  Encryption: $enable_encryption"
    echo
    echo "The installation will:"
    echo "[SUCCESS] Install Arch Linux with Hyprland desktop"
    echo "[SUCCESS] Set up security (firewall, fail2ban, encryption)"
    echo "[SUCCESS] Install development tools and applications"
    echo "[SUCCESS] Optimize for laptop power management"
    echo "[SUCCESS] Configure everything automatically"
    echo
    read -p "Continue with installation? [Y/n]: " final_confirm
    
    if [[ "$final_confirm" =~ ^[Nn]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Step 6: Run deployment
    run_deployment
    
    echo -e "${GREEN}[COMPLETE] Installation completed successfully!${NC}"
    echo "Your Arch Linux Hyprland system is ready to use."
    echo "The system will reboot automatically."
}

main "$@"