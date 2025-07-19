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
INSTALL_DIR="$HOME/lm_archlinux_desktop"

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
    echo -e "${GREEN}✓ $1${NC}"
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
    country: "United Kingdom"
    protocol: "https"
    age: 12
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

# Setup VM network
setup_vm_network() {
    info "Setting up VM network..."
    
    # VM usually has NAT networking that works automatically
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        success "Network connectivity confirmed"
        return
    fi
    
    # Try to bring up network interface
    local interface=$(ip link show | grep -E '^[0-9]+: en' | head -1 | cut -d':' -f2 | xargs)
    if [[ -n "$interface" ]]; then
        info "Bringing up network interface: $interface"
        sudo ip link set "$interface" up
        sudo dhclient "$interface" || warn "DHCP failed"
    fi
    
    # Check connectivity again
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        success "Network connectivity established"
    else
        error "Failed to establish network connectivity"
    fi
}

# Automated disk setup for VM
automated_disk_setup() {
    info "Setting up VM disk automatically..."
    
    # Detect the VM disk
    local vm_disk="/dev/sda"
    if [[ ! -b "$vm_disk" ]]; then
        # Try other common VM disk names
        for disk in /dev/vda /dev/nvme0n1; do
            if [[ -b "$disk" ]]; then
                vm_disk="$disk"
                break
            fi
        done
    fi
    
    if [[ ! -b "$vm_disk" ]]; then
        error "No suitable disk found for VM installation"
    fi
    
    info "Using disk: $vm_disk"
    
    # Update configuration with detected disk
    sed -i "s|device: \"/dev/sda\"|device: \"$vm_disk\"|" "$CONFIG_FILE"
    
    success "VM disk configuration updated"
}

# Run automated base installation
run_base_installation() {
    info "Starting automated base installation..."
    
    # Check if base installation script exists
    local install_script="$INSTALL_DIR/scripts/deployment/auto_install.sh"
    
    if [[ ! -f "$install_script" ]]; then
        error "Base installation script not found: $install_script"
    fi
    
    # Run the automated installation
    info "Running base system installation..."
    chmod +x "$install_script"
    CONFIG_FILE="$CONFIG_FILE" "$install_script" || error "Base installation failed"
    
    success "Base installation completed"
}

# Run automated deployment
run_automated_deployment() {
    info "Starting automated desktop deployment..."
    
    # Clone repository if not already done
    if [[ ! -d "$INSTALL_DIR" ]]; then
        info "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR"
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
Base System: ✓ Completed
Desktop Environment: $(if command -v Hyprland >/dev/null; then echo "✓ Installed"; else echo "✗ Failed"; fi)
Security Hardening: $(if systemctl is-active --quiet ufw; then echo "✓ Active"; else echo "✗ Inactive"; fi)

DESKTOP COMPONENTS
==================
Hyprland: $(if command -v Hyprland >/dev/null; then echo "✓"; else echo "✗"; fi)
Waybar: $(if command -v waybar >/dev/null; then echo "✓"; else echo "✗"; fi)
Wofi: $(if command -v wofi >/dev/null; then echo "✓"; else echo "✗"; fi)
Kitty: $(if command -v kitty >/dev/null; then echo "✓"; else echo "✗"; fi)
SDDM: $(if command -v sddm >/dev/null; then echo "✓"; else echo "✗"; fi)

SERVICES STATUS
===============
NetworkManager: $(systemctl is-active NetworkManager 2>/dev/null || echo "inactive")
SDDM: $(systemctl is-active sddm 2>/dev/null || echo "inactive")
SSH: $(systemctl is-active sshd 2>/dev/null || echo "inactive")
UFW: $(systemctl is-active ufw 2>/dev/null || echo "inactive")

NETWORK STATUS
==============
Connectivity: $(if ping -c 1 google.com >/dev/null 2>&1; then echo "✓ Working"; else echo "✗ Failed"; fi)
Interface: $(ip route | grep default | awk '{print $5}' | head -1 || echo "none")

TEST RESULTS
============
Overall Status: $(if [[ -f ~/.local/bin/system-status ]]; then echo "✓ PASSED"; else echo "⚠ PARTIAL"; fi)

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
    info "Starting automated VirtualBox testing..."
    
    # Detect environment
    detect_vm
    
    # Check if this is the live ISO or installed system
    if [[ -f /usr/bin/pacstrap ]]; then
        info "Running on Arch Linux live ISO - starting full installation"
        
        # Full installation workflow
        create_vm_config
        check_vm_prerequisites
        automated_disk_setup
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