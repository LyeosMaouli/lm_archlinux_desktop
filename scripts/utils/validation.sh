#!/bin/bash
#
# validation.sh - Unified System Validation Utility
#
# Consolidates validation functionality from multiple scripts:
# - Pre-deployment validation checks
# - Post-deployment verification
# - System health monitoring
# - Installation validation
#
# Usage:
#   ./validation.sh [COMMAND] [OPTIONS]
#   source validation.sh && validate_system
#
# Commands:
#   pre-deploy           Pre-deployment validation
#   post-deploy          Post-deployment verification
#   system               System health check
#   network              Network connectivity validation
#   packages             Package installation validation
#   services             Service status validation
#   security             Security configuration validation
#   desktop              Desktop environment validation
#   full                 Complete system validation
#   help                 Show help
#

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../internal/common.sh
source "$SCRIPT_DIR/../internal/common.sh"

# Load other utilities
# shellcheck source=hardware.sh
source "$SCRIPT_DIR/hardware.sh"
# shellcheck source=network.sh
source "$SCRIPT_DIR/network.sh"

# Validation results tracking
declare -A VALIDATION_RESULTS
VALIDATION_PASSED=0
VALIDATION_FAILED=0
VALIDATION_WARNINGS=0

# Validation categories
readonly VALIDATION_CATEGORIES=(
    "system"
    "network" 
    "packages"
    "services"
    "security"
    "desktop"
)

#
# Result Tracking Functions
#

# Initialize validation results
init_validation() {
    VALIDATION_RESULTS=()
    VALIDATION_PASSED=0
    VALIDATION_FAILED=0
    VALIDATION_WARNINGS=0
}

# Record validation result
record_result() {
    local category="$1"
    local test_name="$2"
    local status="$3"  # pass, fail, warn
    local message="$4"
    
    local key="${category}_${test_name}"
    VALIDATION_RESULTS[$key]="$status:$message"
    
    case "$status" in
        pass)
            ((VALIDATION_PASSED++))
            log_info "✓ $category/$test_name: $message"
            ;;
        fail)
            ((VALIDATION_FAILED++))
            log_error "✗ $category/$test_name: $message"
            ;;
        warn)
            ((VALIDATION_WARNINGS++))
            log_warn "⚠ $category/$test_name: $message"
            ;;
    esac
}

# Show validation summary
show_validation_summary() {
    local total=$((VALIDATION_PASSED + VALIDATION_FAILED + VALIDATION_WARNINGS))
    
    echo
    echo "=========================================="
    echo "  Validation Summary"
    echo "=========================================="
    echo "Total Tests: $total"
    echo "Passed: $VALIDATION_PASSED"
    echo "Failed: $VALIDATION_FAILED" 
    echo "Warnings: $VALIDATION_WARNINGS"
    echo
    
    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        if [[ $VALIDATION_WARNINGS -eq 0 ]]; then
            log_info "✓ All validations passed successfully"
            return 0
        else
            log_warn "⚠ Validation passed with warnings"
            return 1
        fi
    else
        log_error "✗ Validation failed - $VALIDATION_FAILED critical issues"
        return 2
    fi
}

#
# System Validation Functions
#

# Validate basic system requirements
validate_system_basic() {
    log_info "Validating basic system requirements..."
    
    # Check if running on Linux
    if [[ "$(uname -s)" == "Linux" ]]; then
        record_result "system" "os_linux" "pass" "Running on Linux"
    else
        record_result "system" "os_linux" "fail" "Not running on Linux: $(uname -s)"
    fi
    
    # Check if running on Arch Linux
    if check_arch_linux; then
        record_result "system" "arch_linux" "pass" "Running on Arch Linux"
    else
        record_result "system" "arch_linux" "fail" "Not running on Arch Linux"
    fi
    
    # Check UEFI boot mode
    if [[ -d /sys/firmware/efi ]]; then
        record_result "system" "uefi_boot" "pass" "UEFI boot mode detected"
    else
        record_result "system" "uefi_boot" "warn" "Legacy BIOS boot mode (UEFI recommended)"
    fi
    
    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        record_result "system" "arch_64bit" "pass" "x86_64 architecture"
    else
        record_result "system" "arch_64bit" "fail" "Unsupported architecture: $arch"
    fi
    
    # Check if running as root when needed
    if [[ "${VALIDATION_MODE:-}" == "install" ]]; then
        if check_root; then
            record_result "system" "root_privileges" "pass" "Running with root privileges"
        else
            record_result "system" "root_privileges" "fail" "Root privileges required for installation"
        fi
    fi
    
    # Check live environment for installation
    if [[ "${VALIDATION_MODE:-}" == "install" ]]; then
        if check_live_environment; then
            record_result "system" "live_environment" "pass" "Running in live environment"
        else
            record_result "system" "live_environment" "warn" "Not in live environment"
        fi
    fi
}

# Validate hardware requirements
validate_system_hardware() {
    log_info "Validating hardware requirements..."
    
    # Ensure hardware is detected
    if [[ "$HARDWARE_DETECTED" != "true" ]]; then
        detect_hardware
    fi
    
    # CPU validation
    if [[ "${HARDWARE_INFO[cpu_64bit]}" == "true" ]]; then
        record_result "system" "cpu_64bit" "pass" "CPU supports 64-bit"
    else
        record_result "system" "cpu_64bit" "fail" "CPU does not support 64-bit"
    fi
    
    # Memory validation
    local mem_gb="${HARDWARE_INFO[memory_total_gb]:-0}"
    if [[ $mem_gb -ge 2 ]]; then
        record_result "system" "memory_minimum" "pass" "${mem_gb}GB RAM available"
        if [[ $mem_gb -ge 4 ]]; then
            record_result "system" "memory_recommended" "pass" "${mem_gb}GB RAM (recommended amount)"
        else
            record_result "system" "memory_recommended" "warn" "${mem_gb}GB RAM (4GB+ recommended)"
        fi
    else
        record_result "system" "memory_minimum" "fail" "Insufficient RAM: ${mem_gb}GB (minimum 2GB required)"
    fi
    
    # Storage validation
    local storage_gb="${HARDWARE_INFO[storage_total_gb]:-0}"
    if [[ $storage_gb -ge 20 ]]; then
        record_result "system" "storage_minimum" "pass" "${storage_gb}GB storage available"
        if [[ $storage_gb -ge 40 ]]; then
            record_result "system" "storage_recommended" "pass" "${storage_gb}GB storage (recommended amount)"
        else
            record_result "system" "storage_recommended" "warn" "${storage_gb}GB storage (40GB+ recommended)"
        fi
    else
        record_result "system" "storage_minimum" "fail" "Insufficient storage: ${storage_gb}GB (minimum 20GB required)"
    fi
    
    # GPU validation
    local gpu_vendor="${HARDWARE_INFO[gpu_vendor]:-unknown}"
    case "$gpu_vendor" in
        intel|amd)
            record_result "system" "gpu_support" "pass" "$gpu_vendor GPU (good Linux support)"
            ;;
        nvidia)
            record_result "system" "gpu_support" "warn" "NVIDIA GPU (may require proprietary drivers)"
            ;;
        unknown)
            record_result "system" "gpu_support" "warn" "Unknown GPU vendor"
            ;;
        *)
            record_result "system" "gpu_support" "warn" "Uncommon GPU vendor: $gpu_vendor"
            ;;
    esac
}

# Validate system dependencies
validate_system_dependencies() {
    log_info "Validating system dependencies..."
    
    # Essential commands
    local essential_commands=("curl" "wget" "git" "tar" "gzip")
    for cmd in "${essential_commands[@]}"; do
        if command_exists "$cmd"; then
            record_result "system" "cmd_$cmd" "pass" "$cmd command available"
        else
            record_result "system" "cmd_$cmd" "fail" "$cmd command not found"
        fi
    done
    
    # Package manager
    if command_exists pacman; then
        record_result "system" "package_manager" "pass" "pacman package manager available"
        
        # Check if pacman database is accessible
        if pacman -Q >/dev/null 2>&1; then
            record_result "system" "pacman_db" "pass" "pacman database accessible"
        else
            record_result "system" "pacman_db" "warn" "pacman database may need refresh"
        fi
    else
        record_result "system" "package_manager" "fail" "pacman not found"
    fi
    
    # systemd
    if command_exists systemctl; then
        record_result "system" "systemd" "pass" "systemd available"
    else
        record_result "system" "systemd" "fail" "systemd not found"
    fi
    
    # Ansible (if needed)
    if [[ "${VALIDATION_MODE:-}" != "minimal" ]]; then
        if command_exists ansible-playbook; then
            record_result "system" "ansible" "pass" "Ansible available"
        else
            record_result "system" "ansible" "warn" "Ansible not found (will be installed)"
        fi
    fi
}

#
# Network Validation Functions
#

# Validate network connectivity
validate_network_connectivity() {
    log_info "Validating network connectivity..."
    
    # Basic connectivity test
    if test_network_connectivity >/dev/null 2>&1; then
        record_result "network" "connectivity" "pass" "Internet connectivity working"
    else
        record_result "network" "connectivity" "fail" "No internet connectivity"
        return 1
    fi
    
    # DNS resolution test
    if test_dns_resolution >/dev/null 2>&1; then
        record_result "network" "dns" "pass" "DNS resolution working"
    else
        record_result "network" "dns" "fail" "DNS resolution not working"
    fi
    
    # Arch repositories access
    local repo_urls=(
        "https://archlinux.org"
        "https://mirror.rackspace.com/archlinux"
    )
    
    local repo_accessible=false
    for url in "${repo_urls[@]}"; do
        if curl -I --connect-timeout 10 "$url" >/dev/null 2>&1; then
            repo_accessible=true
            break
        fi
    done
    
    if [[ "$repo_accessible" == "true" ]]; then
        record_result "network" "arch_repos" "pass" "Arch repositories accessible"
    else
        record_result "network" "arch_repos" "fail" "Cannot access Arch repositories"
    fi
    
    # GitHub access (for AUR and git operations)
    if curl -I --connect-timeout 10 "https://github.com" >/dev/null 2>&1; then
        record_result "network" "github" "pass" "GitHub accessible"
    else
        record_result "network" "github" "warn" "GitHub not accessible (may affect AUR packages)"
    fi
}

# Validate network interfaces
validate_network_interfaces() {
    log_info "Validating network interfaces..."
    
    # Ensure network hardware is detected
    if [[ "$HARDWARE_DETECTED" != "true" ]]; then
        detect_hardware
    fi
    
    local ethernet_devices="${HARDWARE_INFO[ethernet_devices]:-}"
    local wifi_devices="${HARDWARE_INFO[wifi_devices]:-}"
    
    # Ethernet interfaces
    if [[ -n "$ethernet_devices" ]]; then
        record_result "network" "ethernet_available" "pass" "Ethernet interfaces: $ethernet_devices"
    else
        record_result "network" "ethernet_available" "warn" "No ethernet interfaces detected"
    fi
    
    # WiFi interfaces  
    if [[ -n "$wifi_devices" ]]; then
        record_result "network" "wifi_available" "pass" "WiFi interfaces: $wifi_devices"
    else
        record_result "network" "wifi_available" "warn" "No WiFi interfaces detected"
    fi
    
    # At least one network interface
    if [[ -n "$ethernet_devices" || -n "$wifi_devices" ]]; then
        record_result "network" "interface_available" "pass" "Network interfaces available"
    else
        record_result "network" "interface_available" "fail" "No network interfaces detected"
    fi
}

#
# Package Validation Functions
#

# Validate essential packages are installed
validate_essential_packages() {
    log_info "Validating essential packages..."
    
    local essential_packages=(
        "base"
        "linux"
        "linux-firmware"
    )
    
    for package in "${essential_packages[@]}"; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            record_result "packages" "essential_$package" "pass" "$package installed"
        else
            if [[ "${VALIDATION_MODE:-}" == "post-install" ]]; then
                record_result "packages" "essential_$package" "fail" "$package not installed"
            else
                record_result "packages" "essential_$package" "warn" "$package not yet installed"
            fi
        fi
    done
}

# Validate desktop packages (if desktop mode)
validate_desktop_packages() {
    log_info "Validating desktop packages..."
    
    local desktop_packages=(
        "hyprland"
        "waybar"
        "kitty"
        "wofi"
        "mako"
    )
    
    for package in "${desktop_packages[@]}"; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            record_result "packages" "desktop_$package" "pass" "$package installed"
        else
            if [[ "${VALIDATION_MODE:-}" == "post-install" ]]; then
                record_result "packages" "desktop_$package" "fail" "$package not installed"
            else
                record_result "packages" "desktop_$package" "warn" "$package not yet installed"
            fi
        fi
    done
}

# Validate AUR helper
validate_aur_helper() {
    log_info "Validating AUR helper..."
    
    if command_exists yay; then
        record_result "packages" "aur_helper" "pass" "yay AUR helper available"
    elif command_exists paru; then
        record_result "packages" "aur_helper" "pass" "paru AUR helper available"
    elif command_exists makepkg; then
        record_result "packages" "aur_helper" "warn" "No AUR helper, but makepkg available"
    else
        if [[ "${VALIDATION_MODE:-}" == "post-install" ]]; then
            record_result "packages" "aur_helper" "fail" "No AUR helper or makepkg available"
        else
            record_result "packages" "aur_helper" "warn" "AUR helper not yet installed"
        fi
    fi
}

#
# Service Validation Functions
#

# Validate critical system services
validate_critical_services() {
    log_info "Validating critical system services..."
    
    local critical_services=(
        "systemd-networkd"
        "systemd-resolved"
        "dbus"
    )
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            record_result "services" "critical_$service" "pass" "$service is active"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            record_result "services" "critical_$service" "warn" "$service is enabled but not active"
        else
            if [[ "${VALIDATION_MODE:-}" == "post-install" ]]; then
                record_result "services" "critical_$service" "fail" "$service not active or enabled"
            else
                record_result "services" "critical_$service" "warn" "$service not yet configured"
            fi
        fi
    done
}

# Validate desktop services
validate_desktop_services() {
    log_info "Validating desktop services..."
    
    # Only validate if in desktop mode
    if [[ "${VALIDATION_MODE:-}" != "desktop" && "${VALIDATION_MODE:-}" != "post-install" ]]; then
        return 0
    fi
    
    local desktop_services=(
        "sddm"
        "pipewire"
        "pipewire-pulse"
    )
    
    for service in "${desktop_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            record_result "services" "desktop_$service" "pass" "$service is active"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            record_result "services" "desktop_$service" "warn" "$service is enabled but not active"
        else
            record_result "services" "desktop_$service" "fail" "$service not active or enabled"
        fi
    done
}

# Validate security services
validate_security_services() {
    log_info "Validating security services..."
    
    local security_services=(
        "ufw"
        "fail2ban"
        "auditd"
    )
    
    for service in "${security_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            record_result "services" "security_$service" "pass" "$service is active"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            record_result "services" "security_$service" "warn" "$service is enabled but not active"
        else
            if [[ "${VALIDATION_MODE:-}" == "post-install" ]]; then
                record_result "services" "security_$service" "warn" "$service not configured"
            else
                record_result "services" "security_$service" "warn" "$service not yet installed"
            fi
        fi
    done
}

#
# Security Validation Functions
#

# Validate security configuration
validate_security_config() {
    log_info "Validating security configuration..."
    
    # Check firewall status
    if command_exists ufw; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        if [[ "$ufw_status" == *"active"* ]]; then
            record_result "security" "firewall" "pass" "UFW firewall is active"
        else
            record_result "security" "firewall" "warn" "UFW firewall is not active"
        fi
    else
        record_result "security" "firewall" "warn" "UFW not installed"
    fi
    
    # Check SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        # Check if root login is disabled
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
            record_result "security" "ssh_root_disabled" "pass" "SSH root login disabled"
        else
            record_result "security" "ssh_root_disabled" "warn" "SSH root login not disabled"
        fi
        
        # Check if password authentication is configured
        if grep -q "PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null; then
            record_result "security" "ssh_password_config" "pass" "SSH password authentication configured"
        else
            record_result "security" "ssh_password_config" "warn" "SSH password authentication not explicitly configured"
        fi
    else
        record_result "security" "ssh_config" "warn" "SSH not configured"
    fi
    
    # Check sudo configuration
    if [[ -f /etc/sudoers ]]; then
        record_result "security" "sudo_config" "pass" "sudo configuration exists"
    else
        record_result "security" "sudo_config" "warn" "sudo not configured"
    fi
    
    # Check file permissions
    local secure_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/sudoers:440"
    )
    
    for file_perm in "${secure_files[@]}"; do
        local file="${file_perm%:*}"
        local expected_perm="${file_perm#*:}"
        
        if [[ -f "$file" ]]; then
            local actual_perm
            actual_perm=$(stat -c "%a" "$file" 2>/dev/null)
            if [[ "$actual_perm" == "$expected_perm" ]]; then
                record_result "security" "perm_$(basename "$file")" "pass" "$file has correct permissions ($actual_perm)"
            else
                record_result "security" "perm_$(basename "$file")" "warn" "$file permissions: $actual_perm (expected: $expected_perm)"
            fi
        fi
    done
}

#
# Desktop Validation Functions
#

# Validate desktop environment
validate_desktop_environment() {
    log_info "Validating desktop environment..."
    
    # Only run if desktop mode
    if [[ "${VALIDATION_MODE:-}" != "desktop" && "${VALIDATION_MODE:-}" != "post-install" ]]; then
        return 0
    fi
    
    # Check if Hyprland is installed
    if pacman -Q hyprland >/dev/null 2>&1; then
        record_result "desktop" "hyprland_installed" "pass" "Hyprland installed"
    else
        record_result "desktop" "hyprland_installed" "fail" "Hyprland not installed"
    fi
    
    # Check Hyprland configuration
    local hyprland_config="$HOME/.config/hypr/hyprland.conf"
    if [[ -f "$hyprland_config" ]]; then
        record_result "desktop" "hyprland_config" "pass" "Hyprland configuration exists"
    else
        record_result "desktop" "hyprland_config" "warn" "Hyprland configuration not found"
    fi
    
    # Check display server
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        record_result "desktop" "wayland_session" "pass" "Wayland session active"
    elif [[ -n "${DISPLAY:-}" ]]; then
        record_result "desktop" "xorg_session" "warn" "X11 session (Wayland preferred)"
    else
        record_result "desktop" "display_server" "warn" "No display server session detected"
    fi
    
    # Check audio system
    if command_exists pipewire; then
        record_result "desktop" "audio_pipewire" "pass" "PipeWire audio system available"
        
        # Check if PipeWire is running
        if pgrep -x pipewire >/dev/null 2>&1; then
            record_result "desktop" "audio_running" "pass" "PipeWire is running"
        else
            record_result "desktop" "audio_running" "warn" "PipeWire not running"
        fi
    else
        record_result "desktop" "audio_system" "warn" "PipeWire not installed"
    fi
    
    # Check essential desktop applications
    local desktop_apps=("kitty" "waybar" "wofi" "mako")
    for app in "${desktop_apps[@]}"; do
        if command_exists "$app"; then
            record_result "desktop" "app_$app" "pass" "$app available"
        else
            record_result "desktop" "app_$app" "warn" "$app not installed"
        fi
    done
}

#
# Main Validation Functions
#

# Pre-deployment validation
validate_pre_deployment() {
    log_info "Starting pre-deployment validation..."
    init_validation
    
    VALIDATION_MODE="install"
    
    validate_system_basic
    validate_system_hardware
    validate_system_dependencies
    validate_network_connectivity
    validate_network_interfaces
    
    show_validation_summary
}

# Post-deployment validation
validate_post_deployment() {
    log_info "Starting post-deployment validation..."
    init_validation
    
    VALIDATION_MODE="post-install"
    
    validate_system_basic
    validate_system_hardware
    validate_essential_packages
    validate_desktop_packages
    validate_aur_helper
    validate_critical_services
    validate_desktop_services
    validate_security_services
    validate_security_config
    validate_desktop_environment
    validate_network_connectivity
    
    show_validation_summary
}

# System health check
validate_system_health() {
    log_info "Starting system health check..."
    init_validation
    
    validate_system_basic
    validate_critical_services
    validate_network_connectivity
    validate_security_config
    
    # Check system load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_count="${HARDWARE_INFO[cpu_cores]:-1}"
    
    if (( $(echo "$load_avg < $cpu_count" | bc -l 2>/dev/null || echo "1") )); then
        record_result "system" "load_average" "pass" "System load OK ($load_avg)"
    else
        record_result "system" "load_average" "warn" "High system load ($load_avg)"
    fi
    
    # Check disk usage
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    
    if [[ $disk_usage -lt 80 ]]; then
        record_result "system" "disk_usage" "pass" "Disk usage OK (${disk_usage}%)"
    elif [[ $disk_usage -lt 95 ]]; then
        record_result "system" "disk_usage" "warn" "High disk usage (${disk_usage}%)"
    else
        record_result "system" "disk_usage" "fail" "Critical disk usage (${disk_usage}%)"
    fi
    
    # Check memory usage
    local mem_usage
    mem_usage=$(free | grep '^Mem:' | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [[ $mem_usage -lt 80 ]]; then
        record_result "system" "memory_usage" "pass" "Memory usage OK (${mem_usage}%)"
    elif [[ $mem_usage -lt 95 ]]; then
        record_result "system" "memory_usage" "warn" "High memory usage (${mem_usage}%)"
    else
        record_result "system" "memory_usage" "fail" "Critical memory usage (${mem_usage}%)"
    fi
    
    show_validation_summary
}

# Complete system validation
validate_full_system() {
    log_info "Starting complete system validation..."
    init_validation
    
    VALIDATION_MODE="full"
    
    # Run all validation categories
    validate_system_basic
    validate_system_hardware
    validate_system_dependencies
    validate_network_connectivity
    validate_network_interfaces
    validate_essential_packages
    validate_desktop_packages
    validate_aur_helper
    validate_critical_services
    validate_desktop_services
    validate_security_services
    validate_security_config
    validate_desktop_environment
    
    show_validation_summary
}

#
# Command Line Interface
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    
    case "${1:-help}" in
        pre-deploy)
            validate_pre_deployment
            ;;
        post-deploy)
            validate_post_deployment
            ;;
        system)
            validate_system_health
            ;;
        network)
            init_validation
            validate_network_connectivity
            validate_network_interfaces
            show_validation_summary
            ;;
        packages)
            init_validation
            validate_essential_packages
            validate_desktop_packages
            validate_aur_helper
            show_validation_summary
            ;;
        services)
            init_validation
            validate_critical_services
            validate_desktop_services
            validate_security_services
            show_validation_summary
            ;;
        security)
            init_validation
            validate_security_config
            show_validation_summary
            ;;
        desktop)
            init_validation
            VALIDATION_MODE="desktop"
            validate_desktop_environment
            show_validation_summary
            ;;
        full)
            validate_full_system
            ;;
        help|*)
            cat << EOF
System Validation Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  pre-deploy       Pre-deployment validation (hardware, network, deps)
  post-deploy      Post-deployment verification (packages, services, config)
  system           System health check (load, disk, memory)
  network          Network connectivity and interface validation
  packages         Package installation validation
  services         Service status validation
  security         Security configuration validation
  desktop          Desktop environment validation
  full             Complete system validation (all categories)
  help             Show this help

Validation Categories:
  system           Basic system requirements and hardware
  network          Network connectivity and interfaces
  packages         Package installation status
  services         System and application services
  security         Security configuration and hardening
  desktop          Desktop environment and applications

Exit Codes:
  0                All validations passed
  1                Passed with warnings
  2                Critical failures detected

Examples:
  $0 pre-deploy    # Before installation
  $0 post-deploy   # After installation
  $0 system        # Health check
  $0 full          # Complete validation

EOF
            ;;
    esac
fi