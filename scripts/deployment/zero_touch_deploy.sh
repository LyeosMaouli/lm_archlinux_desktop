#!/bin/bash
# Zero-Touch Deployment Script
# Completely automated deployment with minimal user interaction

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     🚀 Arch Linux Hyprland - Zero Touch Deploy            ║
║                                                              ║
║     The easiest way to get a complete desktop system        ║
║     Just answer 3 questions and we handle everything!       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Smart defaults detection
detect_defaults() {
    echo -e "${BLUE}🔍 Auto-detecting system configuration...${NC}"
    
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
    
    echo -e "${GREEN}✅ Auto-detection completed${NC}"
}

# Minimal prompts - only the essentials
minimal_prompts() {
    echo -e "${BLUE}📝 Quick Setup (3 questions only!)${NC}"
    echo
    
    # 1. Username
    read -p "👤 Your username [default: user]: " username
    username=${username:-user}
    
    # 2. Computer name
    read -p "💻 Computer name [default: archlinux]: " hostname
    hostname=${hostname:-archlinux}
    
    # 3. Enable encryption
    echo
    echo "🔒 Disk encryption protects your data if laptop is stolen"
    read -p "Enable full disk encryption? [Y/n]: " encrypt
    if [[ "$encrypt" =~ ^[Nn]$ ]]; then
        enable_encryption="false"
        echo "⚠️  Encryption disabled - data will not be protected"
    else
        enable_encryption="true"
        echo "✅ Encryption enabled - maximum security"
    fi
    
    echo
    echo -e "${GREEN}✅ Configuration complete!${NC}"
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

# Network auto-setup
setup_network_auto() {
    echo -e "${BLUE}🌐 Setting up internet connection...${NC}"
    
    # Check if already connected
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ Internet already connected!${NC}"
        return 0
    fi
    
    # Try ethernet first
    echo "Trying ethernet connection..."
    for iface in $(ip link show | grep -E "en[ospx]" | cut -d: -f2 | tr -d ' '); do
        ip link set "$iface" up
        dhcpcd "$iface" &
        sleep 3
        
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}✅ Ethernet connected!${NC}"
            return 0
        fi
    done
    
    # Try WiFi if ethernet failed
    if iwctl device list 2>/dev/null | grep -q "wlan"; then
        echo "Ethernet not available, trying WiFi..."
        
        # Use the built-in WiFi menu for simplicity
        echo "Opening WiFi setup..."
        echo "Please connect to your WiFi network and then press Enter to continue"
        wifi-menu || true
        
        # Give time for connection
        sleep 5
        
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}✅ WiFi connected!${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠️  No internet connection available${NC}"
    echo "Please ensure you have an internet connection before continuing."
    echo "You can:"
    echo "1. Connect ethernet cable"
    echo "2. Run 'wifi-menu' to connect to WiFi"
    echo "3. Press Enter when connected"
    
    read -p "Press Enter when internet is ready..."
    
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✅ Internet connected!${NC}"
        return 0
    else
        echo -e "${RED}❌ Still no internet connection${NC}"
        return 1
    fi
}

# Password collection with better UX
collect_passwords() {
    echo -e "${BLUE}🔐 Secure Password Setup${NC}"
    echo "We need a few passwords to secure your system."
    echo "All passwords are encrypted and never stored in plain text."
    echo
    
    # User password
    while true; do
        echo -e "${BLUE}Enter password for user '$username':${NC}"
        read -s user_password
        echo
        echo -e "${BLUE}Confirm password:${NC}"
        read -s user_password_confirm
        echo
        
        if [[ "$user_password" == "$user_password_confirm" ]]; then
            if [[ ${#user_password} -ge 8 ]]; then
                break
            else
                echo -e "${RED}❌ Password must be at least 8 characters${NC}"
            fi
        else
            echo -e "${RED}❌ Passwords don't match${NC}"
        fi
    done
    
    # Root password
    while true; do
        echo -e "${BLUE}Enter root password:${NC}"
        read -s root_password
        echo
        echo -e "${BLUE}Confirm root password:${NC}"
        read -s root_password_confirm
        echo
        
        if [[ "$root_password" == "$root_password_confirm" ]]; then
            if [[ ${#root_password} -ge 8 ]]; then
                break
            else
                echo -e "${RED}❌ Password must be at least 8 characters${NC}"
            fi
        else
            echo -e "${RED}❌ Passwords don't match${NC}"
        fi
    done
    
    # Encryption passphrase (if enabled)
    if [[ "$enable_encryption" == "true" ]]; then
        while true; do
            echo -e "${BLUE}Enter disk encryption passphrase:${NC}"
            echo "(You'll need this every time you boot)"
            read -s luks_passphrase
            echo
            echo -e "${BLUE}Confirm encryption passphrase:${NC}"
            read -s luks_passphrase_confirm
            echo
            
            if [[ "$luks_passphrase" == "$luks_passphrase_confirm" ]]; then
                if [[ ${#luks_passphrase} -ge 8 ]]; then
                    break
                else
                    echo -e "${RED}❌ Passphrase must be at least 8 characters${NC}"
                fi
            else
                echo -e "${RED}❌ Passphrases don't match${NC}"
            fi
        done
    fi
    
    echo -e "${GREEN}✅ All passwords collected securely${NC}"
}

# Download and run deployment
run_deployment() {
    echo -e "${BLUE}📥 Downloading deployment system...${NC}"
    
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
    
    # Set up environment variables for passwords
    export USER_PASSWORD="$user_password"
    export ROOT_PASSWORD="$root_password"
    export LUKS_PASSPHRASE="${luks_passphrase:-}"
    
    echo -e "${GREEN}🚀 Starting automated deployment...${NC}"
    echo "This will take 30-60 minutes. Sit back and relax!"
    echo
    
    # Run deployment
    cd /tmp/lm_archlinux_desktop
    chmod +x scripts/deployment/master_auto_deploy.sh
    ./scripts/deployment/master_auto_deploy.sh auto
}

# Main execution
main() {
    print_banner
    
    # Check we're on Arch Linux
    if [[ ! -f /etc/arch-release ]] && [[ ! -d /run/archiso ]]; then
        echo -e "${RED}❌ This script requires Arch Linux${NC}"
        echo "Please boot from an Arch Linux ISO"
        exit 1
    fi
    
    echo -e "${GREEN}Welcome to the easiest Arch Linux Hyprland installation!${NC}"
    echo "This script will set up a complete modern desktop in 3 steps:"
    echo "1. 📝 Answer 3 quick questions"
    echo "2. 🔐 Set up passwords securely"  
    echo "3. 🚀 Automated installation (30-60 minutes)"
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
    echo -e "${GREEN}✅ Configuration created: $config_file${NC}"
    echo
    
    # Step 3: Network setup
    if ! setup_network_auto; then
        echo -e "${RED}❌ Network setup failed${NC}"
        exit 1
    fi
    echo
    
    # Step 4: Password collection
    collect_passwords
    echo
    
    # Step 5: Final confirmation
    echo -e "${YELLOW}📋 Ready to install with these settings:${NC}"
    echo "  Computer name: $hostname"
    echo "  Username: $username"
    echo "  Timezone: $DEFAULT_TIMEZONE"
    echo "  Keyboard: $DEFAULT_KEYMAP"
    echo "  Disk: $DEFAULT_DISK"
    echo "  Encryption: $enable_encryption"
    echo
    echo "The installation will:"
    echo "✅ Install Arch Linux with Hyprland desktop"
    echo "✅ Set up security (firewall, fail2ban, encryption)"
    echo "✅ Install development tools and applications"
    echo "✅ Optimize for laptop power management"
    echo "✅ Configure everything automatically"
    echo
    read -p "Continue with installation? [Y/n]: " final_confirm
    
    if [[ "$final_confirm" =~ ^[Nn]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Step 6: Run deployment
    run_deployment
    
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo "Your Arch Linux Hyprland system is ready to use."
    echo "The system will reboot automatically."
}

main "$@"