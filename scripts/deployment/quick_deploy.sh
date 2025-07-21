#!/bin/bash
# Quick Deployment Script - Minimal User Interaction Required
# This script downloads everything needed and deploys automatically

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     🚀 Arch Linux Hyprland - Quick Deploy                  ║
║                                                              ║
║     Minimal configuration required!                          ║
║     Just answer a few questions and we'll handle the rest   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running on Arch Linux
if [[ ! -f /etc/arch-release ]] && [[ ! -d /run/archiso ]]; then
    echo -e "${YELLOW}⚠️  This script is designed for Arch Linux.${NC}"
    echo "Please boot from an Arch Linux ISO and run this script."
    exit 1
fi

# Quick configuration
echo -e "${GREEN}📝 Quick Configuration Setup${NC}"
echo "We'll ask you a few questions to customize your installation:"
echo

# Hostname
read -p "Computer name (hostname) [phoenix]: " hostname
hostname=${hostname:-phoenix}

# Username  
read -p "Your username [user]: " username
username=${username:-user}

# Timezone
echo
echo "Common timezones:"
echo "  US/Eastern, US/Pacific, US/Central"
echo "  Europe/London, Europe/Paris, Europe/Berlin"
echo "  Asia/Tokyo, Asia/Shanghai"
read -p "Your timezone [Europe/Paris]: " timezone
timezone=${timezone:-Europe/Paris}

# Keyboard layout
echo
echo "Common keyboard layouts:"
echo "  us (US English), fr (French), de (German), uk (UK English)"
read -p "Keyboard layout [us]: " keymap
keymap=${keymap:-us}

# Disk selection
echo
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|nvme|vd"
echo
read -p "Primary disk (e.g., /dev/sda or /dev/nvme0n1) [/dev/sda]: " disk_device
disk_device=${disk_device:-/dev/sda}

# Encryption
echo
read -p "Enable full disk encryption? [Y/n]: " encryption
encryption=${encryption:-Y}
if [[ "$encryption" =~ ^[Yy]$ ]]; then
    enable_encryption="true"
else
    enable_encryption="false"
fi

# Check network connectivity
echo
echo -e "${GREEN}🌐 Network Setup${NC}"
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo "✅ Internet connection detected - ready to proceed!"
    wifi_ssid=""
    wifi_password=""
else
    echo "❌ No internet connection detected"
    echo "Don't worry - we'll set this up automatically during installation!"
    wifi_ssid="AUTO_DETECT"
    wifi_password="PROMPT_DURING_INSTALL"
fi

# Create configuration
config_dir="/tmp/arch_deploy"
mkdir -p "$config_dir"
config_file="$config_dir/deployment_config.yml"

echo -e "${GREEN}📄 Creating configuration file...${NC}"

cat > "$config_file" << EOF
# Auto-generated Deployment Configuration
# Generated on $(date)

system:
  hostname: "$hostname"
  timezone: "$timezone" 
  locale: "en_US.UTF-8"
  keymap: "$keymap"

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

network:
  ethernet:
    enabled: true
    dhcp: true
  wifi:
    enabled: $([ -n "$wifi_ssid" ] && echo "true" || echo "false")
    ssid: "$wifi_ssid"
    password: "$wifi_password"
    security: "wpa2"

disk:
  device: "$disk_device"
  encryption:
    enabled: $enable_encryption
    passphrase: ""  # Will be prompted securely
  partitions:
    efi_size: "512M"
    swap_size: "4G"
  filesystem: "ext4"

desktop:
  environment: "hyprland"
  display_manager: "sddm"
  theme: "catppuccin-mocha"
  auto_login: false

packages:
  aur:
    packages:
      - visual-studio-code-bin
      - discord
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
  skip_confirmations: true   # Fully automated after this point
  auto_reboot: true
  backup_configs: true
  log_level: "info"

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
EOF

echo -e "${GREEN}✅ Configuration created!${NC}"
echo "File: $config_file"
echo

# Download and run deployment script
echo -e "${GREEN}📥 Downloading deployment scripts...${NC}"

# Clone or download the repository
if [[ -d /tmp/lm_archlinux_desktop ]]; then
    rm -rf /tmp/lm_archlinux_desktop
fi

if command -v git >/dev/null 2>&1; then
    git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git /tmp/lm_archlinux_desktop
else
    echo "Installing git..."
    pacman -Sy --noconfirm git
    git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git /tmp/lm_archlinux_desktop
fi

# Copy configuration to the right place
cp "$config_file" /tmp/lm_archlinux_desktop/deployment_config.yml

echo -e "${GREEN}🚀 Starting automated deployment...${NC}"
echo "The system will now install and configure everything automatically."
echo "This process takes 30-60 minutes depending on your internet speed."
echo

# Run the deployment
cd /tmp/lm_archlinux_desktop
chmod +x scripts/deployment/master_auto_deploy.sh
CONFIG_FILE="/tmp/lm_archlinux_desktop/deployment_config.yml" ./scripts/deployment/master_auto_deploy.sh auto

echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo "Your Arch Linux Hyprland system is ready."
echo "The system will reboot automatically if configured to do so."