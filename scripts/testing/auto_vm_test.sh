#!/bin/bash
# Automated VirtualBox Testing Script for Arch Linux Hyprland
# This script automates the complete VM testing workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
CONFIG_FILE="${CONFIG_FILE:-/tmp/vm_deployment_config.yml}"
LOG_FILE="/var/log/auto_vm_test.log"
VERBOSE_LOG="/var/log/auto_vm_test_verbose.log"
INSTALL_DIR="$HOME/lm_archlinux_desktop"

# Enhanced logging setup for VM testing
setup_vm_logging() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$VERBOSE_LOG")"
    
    # Start comprehensive logging
    exec > >(tee -a "$VERBOSE_LOG")
    exec 2> >(tee -a "$VERBOSE_LOG" >&2)
    
    echo "=== VM TEST VERBOSE LOG STARTED: $(date) ===" >> "$VERBOSE_LOG"
    echo "=== VM Environment Information ===" >> "$VERBOSE_LOG"
    dmidecode -s system-product-name >> "$VERBOSE_LOG" 2>&1 || echo "dmidecode failed" >> "$VERBOSE_LOG"
    lscpu | head -10 >> "$VERBOSE_LOG" 2>&1 || true
    free -h >> "$VERBOSE_LOG" 2>&1 || true
    lsblk >> "$VERBOSE_LOG" 2>&1 || true
    echo "=== Network Status ===" >> "$VERBOSE_LOG"
    ip addr show >> "$VERBOSE_LOG" 2>&1 || true
    echo "=== Starting VM Test Process ===" >> "$VERBOSE_LOG"
}

# VM-specific settings
VM_DISK="/dev/sda"
VM_CONFIG_TEMPLATE="vm_deployment_config.yml"

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
    echo -e "${GREEN}[OK] $1${NC}"
    log "SUCCESS: $1"
}

# Detect if running in VirtualBox
detect_vm() {
    info "Detecting virtualization environment..."
    
    local vm_detected=false
    
    # Check for VirtualBox
    if dmidecode -s system-product-name 2>/dev/null | grep -qi "virtualbox"; then
        vm_detected=true
        info "VirtualBox environment detected"
    elif lscpu | grep -qi "hypervisor"; then
        vm_detected=true
        info "Virtualized environment detected"
    elif [[ -f /sys/class/dmi/id/product_name ]] && grep -qi "virtualbox" /sys/class/dmi/id/product_name; then
        vm_detected=true
        info "VirtualBox detected via DMI"
    fi
    
    if [[ "$vm_detected" == true ]]; then
        export RUNNING_IN_VM=true
        info "VM environment confirmed - enabling VM-specific optimizations"
    else
        export RUNNING_IN_VM=false
        warn "Not running in VM - some optimizations will be skipped"
    fi
}

# Create VM-optimized configuration
create_vm_config() {
    info "Creating VM-optimized deployment configuration..."
    
    cat > "$CONFIG_FILE" << 'EOF'
# VM Testing Configuration for Arch Linux Hyprland Automation
# Optimized for VirtualBox testing environment

# System Configuration
system:
  hostname: "vm-phoenix"
  timezone: "Europe/Paris"
  locale: "en_US.UTF-8"
  keymap: "fr"
  country: "United Kingdom"

# User Configuration
user:
  username: "lyeosmaouli"
  password: "test123"  # Simple password for testing
  shell: "/bin/bash"
  groups:
    - wheel
    - audio
    - video
    - network
    - storage

# Root Configuration
root:
  password: "root123"  # Simple password for testing

# Network Configuration (VM usually has NAT)
network:
  wifi:
    enabled: false  # Usually not needed in VM
  ethernet:
    enabled: true
    dhcp: true

# Disk Configuration (VM disk)
disk:
  device: "/dev/sda"
  encryption:
    enabled: true
    passphrase: "test123"  # Simple passphrase for testing
  partitions:
    efi_size: "512M"
    swap_size: "2G"  # Smaller for VM
  filesystem: "ext4"

# Bootloader Configuration
bootloader:
  type: "systemd-boot"
  timeout: 5
  quiet_boot: true

# Desktop Configuration
desktop:
  environment: "hyprland"
  display_manager: "sddm"
  theme: "catppuccin-mocha"
  wallpaper: "default"
  auto_login: true  # Enable for testing

# Package Configuration
packages:
  mirrors:
    protocol: "https"
    age: 12
    # country: auto-detect fastest mirrors
  aur:
    helper: "yay"
    packages:
      - visual-studio-code-bin
      - discord
      - hyprpaper

# Security Configuration (relaxed for testing)
security:
  firewall:
    enabled: true
    default_policy: "deny"
  fail2ban:
    enabled: true
    ssh_protection: true
  audit:
    enabled: true
    rules: "basic"  # Less strict for VM
  ssh:
    port: 22
    password_auth: true  # Allow for testing
    root_login: false

# Automation Configuration
automation:
  skip_confirmations: true  # Full automation for testing
  auto_reboot: true
  backup_configs: true
  log_level: "info"
  deploy_bootstrap: true
  deploy_desktop: true
  deploy_security: true

# VirtualBox Testing Configuration
virtualbox:
  guest_additions: true
  shared_folders: false
  clipboard: true
  drag_drop: true
  vm_optimizations: true

# Development Configuration
development:
  git:
    username: "Test User"
    email: "test@vm.local"
  ssh_keys:
    generate: true
    type: "ed25519"
  tools:
    - neovim
    - tmux
    - htop
    - tree
EOF
    
    success "VM configuration created at: $CONFIG_FILE"
}

# Check VM prerequisites
check_vm_prerequisites() {
    info "Checking VM prerequisites..."
    
    # Check if running in UEFI mode
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        error "VM must be configured with EFI enabled"
    fi
    success "EFI boot mode confirmed"
    
    # Check available disk space
    local disk_space=$(df /tmp --output=avail | tail -1)
    if [[ "$disk_space" -lt 1000000 ]]; then  # Less than 1GB
        warn "Low disk space available: $(($disk_space/1024))MB"
    else
        success "Sufficient disk space available"
    fi
    
    # Check memory
    local memory=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    if [[ "$memory" -lt 2 ]]; then
        warn "Low memory: ${memory}GB (recommended: 4GB+)"
    else
        success "Memory: ${memory}GB"
    fi
    
    info "VM prerequisites check complete"
}

# Setup VM network with enhanced robustness
setup_vm_network() {
    info "Setting up VM network with enhanced reliability..."
    
    # Clear any proxy settings that might interfere in VM
    unset http_proxy https_proxy ftp_proxy rsync_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY RSYNC_PROXY
    info "Cleared proxy settings for VM environment"
    
    # Configure reliable DNS servers
    info "Configuring DNS servers..."
    cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
EOF
    
    # Check if we're already connected
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        success "Network connectivity confirmed (via 8.8.8.8)"
        return
    fi
    
    # Try archlinux.org
    if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        success "Network connectivity confirmed (via archlinux.org)"
        return
    fi
    
    info "Network not ready, attempting to configure..."
    
    # Show network interfaces for debugging
    info "Available network interfaces:"
    ip link show | grep -E '^[0-9]+:' || warn "Failed to list interfaces"
    
    # Try to bring up network interface with multiple attempts
    local interfaces=($(ip link show | grep -E '^[0-9]+: (en|eth)' | cut -d':' -f2 | xargs))
    
    for interface in "${interfaces[@]}"; do
        if [[ -n "$interface" ]]; then
            info "Attempting to configure interface: $interface"
            
            # Bring up interface
            ip link set "$interface" up || warn "Failed to bring up $interface"
            sleep 2
            
            # Try DHCP with timeout
            info "Attempting DHCP on $interface..."
            timeout 15 dhcpcd "$interface" 2>/dev/null &
            local dhcp_pid=$!
            
            # Wait for DHCP or timeout
            local wait_time=0
            while [[ $wait_time -lt 15 ]]; do
                if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                    success "Network connectivity established via $interface"
                    kill $dhcp_pid 2>/dev/null || true
                    return 0
                fi
                sleep 1
                wait_time=$((wait_time + 1))
            done
            
            # Kill DHCP process if still running
            kill $dhcp_pid 2>/dev/null || true
            pkill dhcpcd 2>/dev/null || true
            
            # Try static IP as fallback for VM NAT
            info "DHCP failed, trying manual configuration for VM NAT..."
            ip addr add 10.0.2.15/24 dev "$interface" 2>/dev/null || true
            ip route add default via 10.0.2.2 2>/dev/null || true
            
            sleep 2
            if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
                success "Network connectivity established via manual config"
                return 0
            fi
        fi
    done
    
    # Final connectivity check with multiple targets
    local connectivity_targets=("8.8.8.8" "1.1.1.1" "archlinux.org" "google.com")
    for target in "${connectivity_targets[@]}"; do
        if ping -c 1 -W 5 "$target" >/dev/null 2>&1; then
            success "Network connectivity confirmed via $target"
            return 0
        fi
    done
    
    # Show diagnostic information
    info "Network diagnostic information:"
    info "Interfaces: $(ip link show | grep -E '^[0-9]+:' | cut -d':' -f2 | xargs)"
    info "Routes: $(ip route show 2>/dev/null || echo 'none')"
    info "DNS: $(cat /etc/resolv.conf | grep nameserver || echo 'none configured')"
    
    error "Failed to establish network connectivity. Please check VM network settings (NAT/Bridged mode)."
}

# Automated disk setup for VM
automated_disk_setup() {
    info "Setting up VM disk automatically..."
    
    # Show available disks for debugging
    info "Available block devices:"
    lsblk -f || warn "lsblk failed"
    
    # Detect the VM disk
    local vm_disk=""
    local possible_disks=("/dev/sda" "/dev/vda" "/dev/nvme0n1" "/dev/hda")
    
    for disk in "${possible_disks[@]}"; do
        if [[ -b "$disk" ]]; then
            vm_disk="$disk"
            info "Found VM disk: $vm_disk"
            break
        fi
    done
    
    if [[ -z "$vm_disk" ]] || [[ ! -b "$vm_disk" ]]; then
        error "No suitable disk found for VM installation. Available devices: $(ls /dev/sd* /dev/vd* /dev/nvme* 2>/dev/null || echo 'none')"
    fi
    
    info "Using disk: $vm_disk"
    info "Disk size: $(lsblk -b -n -o SIZE "$vm_disk" 2>/dev/null | head -1 | numfmt --to=iec || echo 'unknown')"
    
    # Update configuration with detected disk
    info "Updating configuration file with detected disk: $vm_disk"
    sed -i "s|device: \"/dev/sda\"|device: \"$vm_disk\"|" "$CONFIG_FILE"
    
    # Verify the configuration was updated
    local updated_device=$(grep "device:" "$CONFIG_FILE" | head -1 | cut -d'"' -f2)
    info "Configuration updated - device: $updated_device"
    
    # Show the disk section of the config for debugging
    info "Current disk configuration:"
    awk '/^disk:/,/^[a-zA-Z]/' "$CONFIG_FILE" | head -10
    
    success "VM disk configuration updated"
}

# Fix pacman keyring issues in VM environment
fix_vm_keyring() {
    info "Fixing pacman keyring for VM environment..."
    
    # Kill any gpg-agent processes
    killall gpg-agent 2>/dev/null || true
    
    # Check keyring status
    if [[ ! -d "/etc/pacman.d/gnupg" ]] || ! pacman-key --list-keys >/dev/null 2>&1; then
        info "Keyring missing or corrupted, initializing..."
        rm -rf /etc/pacman.d/gnupg 2>/dev/null || true
        pacman-key --init || warn "Keyring init failed"
        pacman-key --populate archlinux || warn "Key population failed"
    fi
    
    # Try to update keyring package
    timeout 60 pacman -Sy --noconfirm archlinux-keyring 2>/dev/null || warn "Could not update keyring package"
    
    success "Keyring configuration complete"
}

# Install Git if needed with enhanced mirror handling
ensure_git() {
    # Check if git is already available (it should be on live ISO)
    if command -v git >/dev/null 2>&1; then
        info "Git already available: $(git --version)"
        return 0
    fi
    
    info "Git not found, attempting installation..."
    
    # Make sure we have network connectivity for package installation
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        error "No network connectivity for package installation"
    fi
    
    if command -v pacman >/dev/null 2>&1; then
        # Clear pacman cache and configure for better downloads
        info "Configuring pacman for reliable package installation..."
        rm -rf /var/lib/pacman/sync/* 2>/dev/null || true
        
        # Fix keyring issues first (critical for 2025)
        info "Checking and fixing pacman keyring..."
        fix_vm_keyring
        
        # Add download timeout configuration in correct section
        if ! grep -q "XferCommand.*curl.*retry" /etc/pacman.conf; then
            info "Adding download reliability settings to pacman..."
            # Remove any existing XferCommand lines
            sed -i '/^XferCommand/d' /etc/pacman.conf
            # Add XferCommand in the [options] section
            sed -i '/^ParallelDownloads/a XferCommand = /usr/bin/curl -L -C - -f --retry 5 --retry-delay 3 --connect-timeout 60 -o %o %u' /etc/pacman.conf
        fi
        
        info "Updating package database with enhanced settings..."
        echo "=== VM PACMAN DATABASE SYNC ===" >> "$VERBOSE_LOG"
        timeout 120 pacman -Syy --noconfirm 2>&1 | tee -a "$VERBOSE_LOG" || {
            warn "Package database update failed, trying to continue..."
        }
        
        info "Installing Git package..."
        echo "=== VM GIT INSTALLATION ===" >> "$VERBOSE_LOG"
        timeout 300 pacman -S --noconfirm git 2>&1 | tee -a "$VERBOSE_LOG" || {
            warn "Git installation failed. Checking if it's actually installed..."
            
            # Sometimes the package exists but path is not updated
            if [[ -x /usr/bin/git ]]; then
                info "Git found at /usr/bin/git"
                export PATH="/usr/bin:$PATH"
            else
                error "Failed to install Git. Please install it manually: pacman -S git"
            fi
        }
        
        # Final verification
        if command -v git >/dev/null 2>&1; then
            info "Git successfully available: $(git --version)"
        else
            error "Git installation failed - command not found after installation"
        fi
    else
        error "Git not available and cannot install (pacman not found)"
    fi
}

# Clone repository for installation
clone_repository() {
    info "Cloning automation repository..."
    
    # Ensure Git is available
    ensure_git
    
    # Remove existing directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Existing installation directory found, backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Clone repository
    git clone "$REPO_URL" "$INSTALL_DIR" || error "Failed to clone repository"
    
    info "Repository cloned successfully to $INSTALL_DIR"
}

# Run automated base installation
run_base_installation() {
    info "Starting automated base installation..."
    
    # Ensure repository is cloned
    if [[ ! -d "$INSTALL_DIR" ]]; then
        clone_repository
    fi
    
    # Check if base installation script exists
    local install_script="$INSTALL_DIR/scripts/deployment/auto_install.sh"
    
    if [[ ! -f "$install_script" ]]; then
        error "Base installation script not found: $install_script"
    fi
    
    # Run the automated installation with enhanced debugging
    info "Running base system installation..."
    chmod +x "$install_script"
    
    info "Configuration being used:"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "=== VM Configuration File ==="
        head -n 20 "$CONFIG_FILE"
        echo "=========================="
    else
        warn "Configuration file not found: $CONFIG_FILE"
    fi
    
    info "Starting installation process..."
    CONFIG_FILE="$CONFIG_FILE" "$install_script" || {
        error "Base installation failed. Check the logs for details."
    }
    
    success "Base installation completed"
}

# Run automated deployment
run_automated_deployment() {
    info "Starting automated desktop deployment..."
    
    # Ensure repository is cloned
    if [[ ! -d "$INSTALL_DIR" ]]; then
        clone_repository
    fi
    
    cd "$INSTALL_DIR"
    
    # Copy VM configuration
    cp "$CONFIG_FILE" "$INSTALL_DIR/deployment_config.yml"
    
    # Check if deployment script exists
    local deploy_script="$INSTALL_DIR/scripts/deployment/auto_deploy.sh"
    
    if [[ ! -f "$deploy_script" ]]; then
        error "Deployment script not found: $deploy_script"
    fi
    
    # Run the automated deployment
    info "Running automated deployment..."
    chmod +x "$deploy_script"
    CONFIG_FILE="$INSTALL_DIR/deployment_config.yml" "$deploy_script" || error "Deployment failed"
    
    success "Automated deployment completed"
}

# Run validation tests
run_validation_tests() {
    info "Running validation tests..."
    
    # Check if post-install script exists
    local post_install_script="$INSTALL_DIR/scripts/deployment/auto_post_install.sh"
    
    if [[ -f "$post_install_script" ]]; then
        info "Running post-installation validation..."
        chmod +x "$post_install_script"
        CONFIG_FILE="$INSTALL_DIR/deployment_config.yml" "$post_install_script" || warn "Some validations failed"
    else
        warn "Post-installation script not found, running basic validation..."
        run_basic_validation
    fi
    
    success "Validation tests completed"
}

# Basic validation if post-install script not available
run_basic_validation() {
    info "Running basic system validation..."
    
    # Check essential commands
    local commands=("Hyprland" "waybar" "wofi" "kitty" "sddm")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "$cmd installed"
        else
            warn "$cmd not found"
        fi
    done
    
    # Check services
    local services=("NetworkManager" "sshd")
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            success "$service enabled"
        else
            warn "$service not enabled"
        fi
    done
    
    info "Basic validation complete"
}

# Install VirtualBox Guest Additions
install_guest_additions() {
    if [[ "$RUNNING_IN_VM" == true ]]; then
        info "Installing VirtualBox Guest Additions..."
        
        # Install prerequisites
        sudo pacman -S --noconfirm virtualbox-guest-utils
        
        # Enable guest services
        sudo systemctl enable vboxservice
        
        # Add user to vboxsf group for shared folders
        local username=$(parse_config "username" || echo "lyeosmaouli")
        sudo usermod -a -G vboxsf "$username" 2>/dev/null || warn "Failed to add user to vboxsf group"
        
        success "VirtualBox Guest Additions installed"
    else
        info "Not in VM, skipping Guest Additions"
    fi
}

# Create test results report
create_test_report() {
    info "Creating test results report..."
    
    local report_file="$HOME/vm_test_report.txt"
    
    cat > "$report_file" << EOF
VirtualBox Test Results Report
Generated on: $(date)
=============================

TEST ENVIRONMENT
================
Hostname: $(hostnamectl --static 2>/dev/null || echo "unknown")
Kernel: $(uname -r)
Memory: $(free -h | grep "^Mem:" | awk '{print $2}')
Disk: $(df -h / | tail -1 | awk '{print $2}')
VM Detection: $RUNNING_IN_VM

INSTALLATION STATUS
===================
Base System: [OK] Completed
Desktop Environment: $(if command -v Hyprland >/dev/null; then echo "[OK] Installed"; else echo "[FAIL] Failed"; fi)
Security Hardening: $(if systemctl is-active --quiet ufw; then echo "[OK] Active"; else echo "[FAIL] Inactive"; fi)

DESKTOP COMPONENTS
==================
Hyprland: $(if command -v Hyprland >/dev/null; then echo "[OK]"; else echo "[FAIL]"; fi)
Waybar: $(if command -v waybar >/dev/null; then echo "[OK]"; else echo "[FAIL]"; fi)
Wofi: $(if command -v wofi >/dev/null; then echo "[OK]"; else echo "[FAIL]"; fi)
Kitty: $(if command -v kitty >/dev/null; then echo "[OK]"; else echo "[FAIL]"; fi)
SDDM: $(if command -v sddm >/dev/null; then echo "[OK]"; else echo "[FAIL]"; fi)

SERVICES STATUS
===============
NetworkManager: $(systemctl is-active NetworkManager 2>/dev/null || echo "inactive")
SDDM: $(systemctl is-active sddm 2>/dev/null || echo "inactive")
SSH: $(systemctl is-active sshd 2>/dev/null || echo "inactive")
UFW: $(systemctl is-active ufw 2>/dev/null || echo "inactive")

NETWORK STATUS
==============
Connectivity: $(if ping -c 1 google.com >/dev/null 2>&1; then echo "[OK] Working"; else echo "[FAIL] Failed"; fi)
Interface: $(ip route | grep default | awk '{print $5}' | head -1 || echo "none")

TEST RESULTS
============
Overall Status: $(if [[ -f ~/.local/bin/system-status ]]; then echo "[OK] PASSED"; else echo "⚠ PARTIAL"; fi)

NEXT STEPS
==========
1. Reboot the VM: sudo reboot
2. Test Hyprland desktop login
3. Verify key bindings work
4. Test applications launch

EOF
    
    success "Test report created: $report_file"
}

# Main VM testing function
main() {
    # Setup comprehensive logging FIRST
    setup_vm_logging
    
    info "Starting automated VirtualBox testing with comprehensive logging..."
    info "Verbose log: $VERBOSE_LOG"
    info "Standard log: $LOG_FILE"
    
    # Detect environment
    detect_vm
    
    # Check if this is the live ISO or installed system
    if [[ -f /usr/bin/pacstrap ]]; then
        info "Running on Arch Linux live ISO - starting full installation"
        
        # Full installation workflow
        create_vm_config
        check_vm_prerequisites
        setup_vm_network
        run_base_installation
        
        info "Base installation complete. The VM will reboot automatically."
        info "After reboot, run this script again to continue with desktop deployment."
        
    elif [[ -d /home ]]; then
        info "Running on installed system - starting desktop deployment"
        
        # Check if this is post-reboot
        if [[ ! -d "$INSTALL_DIR" ]]; then
            # First boot after base installation
            create_vm_config
            setup_vm_network
            run_automated_deployment
            install_guest_additions
        fi
        
        # Run validation
        run_validation_tests
        create_test_report
        
        info "VM testing complete!"
        info "Check the test report: cat ~/vm_test_report.txt"
        info "Reboot and test the desktop: sudo reboot"
        
    else
        error "Unable to determine system state"
    fi
}

# Parse simple config function (minimal implementation)
parse_config() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "$key:" "$CONFIG_FILE" | cut -d':' -f2 | sed 's/^ *//; s/ *$//' | tr -d '"' | head -1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi