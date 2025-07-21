#!/bin/bash
# Automated Post-Installation Configuration Script
# This script handles final system configuration and validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="${CONFIG_FILE:-$HOME/lm_archlinux_desktop/deployment_config.yml}"
LOG_FILE="/var/log/auto_post_install.log"
INSTALL_DIR="$HOME/lm_archlinux_desktop"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
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

fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    log "FAIL: $1"
}

# Parse YAML configuration
parse_nested_config() {
    local section="$1"
    local key="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        awk "/^${section}:/{flag=1; next} /^[a-zA-Z]/{flag=0} flag && /${key}:/{print}" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^ *//; s/ *$//' | tr -d '"'
    else
        echo ""
    fi
}

# Validate desktop environment
validate_desktop() {
    info "Validating desktop environment installation..."
    
    local validation_passed=true
    
    # Check if Hyprland is installed
    if command -v Hyprland >/dev/null 2>&1; then
        success "Hyprland compositor installed"
    else
        fail "Hyprland compositor not found"
        validation_passed=false
    fi
    
    # Check essential desktop components
    local components=("waybar" "wofi" "mako" "kitty" "thunar" "sddm")
    for component in "${components[@]}"; do
        if command -v "$component" >/dev/null 2>&1; then
            success "$component installed"
        else
            fail "$component not found"
            validation_passed=false
        fi
    done
    
    # Check desktop session files
    if [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
        success "Hyprland session file found"
    else
        fail "Hyprland session file missing"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == true ]]; then
        info "Desktop environment validation: PASSED"
    else
        error "Desktop environment validation: FAILED"
    fi
}

# Validate system services
validate_services() {
    info "Validating system services..."
    
    local validation_passed=true
    
    # Essential services to check
    local services=(
        "NetworkManager:Network management"
        "sshd:SSH server"
        "sddm:Display manager"
    )
    
    for service_info in "${services[@]}"; do
        local service=$(echo "$service_info" | cut -d':' -f1)
        local description=$(echo "$service_info" | cut -d':' -f2)
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                success "$description ($service): enabled and running"
            else
                warn "$description ($service): enabled but not running"
            fi
        else
            fail "$description ($service): not enabled"
            validation_passed=false
        fi
    done
    
    # Check user services
    local user_services=(
        "pipewire:Audio system"
        "wireplumber:Audio session manager"
    )
    
    for service_info in "${user_services[@]}"; do
        local service=$(echo "$service_info" | cut -d':' -f1)
        local description=$(echo "$service_info" | cut -d':' -f2)
        
        if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
            success "$description ($service): enabled"
        else
            warn "$description ($service): not enabled"
        fi
    done
    
    if [[ "$validation_passed" == true ]]; then
        info "Services validation: PASSED"
    else
        warn "Services validation: WARNINGS FOUND"
    fi
}

# Validate security configuration
validate_security() {
    info "Validating security configuration..."
    
    local validation_passed=true
    
    # Check UFW firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(sudo ufw status | head -n1)
        if [[ "$ufw_status" == *"active"* ]]; then
            success "UFW firewall is active"
        else
            fail "UFW firewall is not active"
            validation_passed=false
        fi
    else
        fail "UFW firewall not installed"
        validation_passed=false
    fi
    
    # Check fail2ban
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        success "fail2ban intrusion prevention is running"
    else
        fail "fail2ban is not running"
        validation_passed=false
    fi
    
    # Check audit system
    if systemctl is-active --quiet auditd 2>/dev/null; then
        success "Audit system is running"
    else
        warn "Audit system is not running"
    fi
    
    # Check SSH security
    if [[ -f /etc/ssh/sshd_config ]]; then
        local root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "unknown")
        local password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "unknown")
        
        if [[ "$root_login" == "no" ]]; then
            success "SSH root login disabled"
        else
            warn "SSH root login not disabled (current: $root_login)"
        fi
        
        if [[ "$password_auth" == "no" ]]; then
            success "SSH password authentication disabled"
        else
            warn "SSH password authentication not disabled (current: $password_auth)"
        fi
    fi
    
    if [[ "$validation_passed" == true ]]; then
        info "Security validation: PASSED"
    else
        warn "Security validation: ISSUES FOUND"
    fi
}

# Validate audio system
validate_audio() {
    info "Validating audio system..."
    
    local validation_passed=true
    
    # Check PipeWire installation
    if command -v pipewire >/dev/null 2>&1; then
        success "PipeWire installed"
    else
        fail "PipeWire not installed"
        validation_passed=false
    fi
    
    # Check PipeWire services
    if systemctl --user is-active --quiet pipewire 2>/dev/null; then
        success "PipeWire service running"
    else
        warn "PipeWire service not running"
        # Try to start it
        systemctl --user start pipewire || warn "Failed to start PipeWire"
    fi
    
    # Check WirePlumber
    if systemctl --user is-active --quiet wireplumber 2>/dev/null; then
        success "WirePlumber session manager running"
    else
        warn "WirePlumber not running"
        systemctl --user start wireplumber || warn "Failed to start WirePlumber"
    fi
    
    # Check audio device detection
    if command -v pactl >/dev/null 2>&1; then
        local audio_info=$(pactl info 2>/dev/null | grep "Server Name" || echo "")
        if [[ -n "$audio_info" ]]; then
            success "PulseAudio compatibility layer working"
        else
            warn "PulseAudio compatibility layer not working"
        fi
    fi
    
    if [[ "$validation_passed" == true ]]; then
        info "Audio system validation: PASSED"
    else
        warn "Audio system validation: ISSUES FOUND"
    fi
}

# Validate network configuration
validate_network() {
    info "Validating network configuration..."
    
    local validation_passed=true
    
    # Check NetworkManager
    if systemctl is-active --quiet NetworkManager; then
        success "NetworkManager is running"
    else
        fail "NetworkManager is not running"
        validation_passed=false
    fi
    
    # Check internet connectivity
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        success "Internet connectivity working"
    else
        fail "No internet connectivity"
        validation_passed=false
    fi
    
    # Check network interfaces
    local interfaces=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | wc -l)
    if [[ "$interfaces" -gt 0 ]]; then
        success "Network interfaces detected ($interfaces)"
    else
        warn "No network interfaces found"
    fi
    
    # Check WiFi if configured
    local wifi_enabled=$(parse_nested_config "network" "enabled")
    if [[ "$wifi_enabled" == "true" ]]; then
        if command -v nmcli >/dev/null 2>&1; then
            local wifi_status=$(nmcli -t -f WIFI general status)
            if [[ "$wifi_status" == "enabled" ]]; then
                success "WiFi is enabled"
            else
                warn "WiFi is disabled"
            fi
        fi
    fi
    
    if [[ "$validation_passed" == true ]]; then
        info "Network validation: PASSED"
    else
        warn "Network validation: ISSUES FOUND"
    fi
}

# Validate AUR packages
validate_aur() {
    info "Validating AUR packages..."
    
    local validation_passed=true
    
    # Check yay installation
    if command -v yay >/dev/null 2>&1; then
        success "Yay AUR helper installed"
    else
        fail "Yay AUR helper not found"
        validation_passed=false
        return
    fi
    
    # Check configured AUR packages
    local aur_packages=$(parse_nested_config "packages" "packages")
    if [[ -n "$aur_packages" ]]; then
        # Get list of AUR packages
        local installed_aur=$(yay -Qm | awk '{print $1}')
        
        # Parse the package list from config (this is a simple implementation)
        local expected_packages=("visual-studio-code-bin" "discord" "zoom" "hyprpaper")
        
        for package in "${expected_packages[@]}"; do
            if echo "$installed_aur" | grep -q "^$package$"; then
                success "AUR package '$package' installed"
            else
                warn "AUR package '$package' not found"
            fi
        done
    fi
    
    if [[ "$validation_passed" == true ]]; then
        info "AUR packages validation: PASSED"
    else
        warn "AUR packages validation: ISSUES FOUND"
    fi
}

# Create system information report
create_system_report() {
    info "Creating system information report..."
    
    local report_file="$HOME/system_report.txt"
    
    cat > "$report_file" << EOF
Arch Linux Hyprland System Report
Generated on: $(date)
================================

SYSTEM INFORMATION
==================
Hostname: $(hostnamectl --static)
Kernel: $(uname -r)
Architecture: $(uname -m)
Uptime: $(uptime -p)

DESKTOP ENVIRONMENT
==================
Session Type: ${XDG_SESSION_TYPE:-"Not set"}
Current Desktop: ${XDG_CURRENT_DESKTOP:-"Not set"}
Wayland Display: ${WAYLAND_DISPLAY:-"Not set"}

HARDWARE INFORMATION
===================
CPU: $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
Memory: $(free -h | grep "^Mem:" | awk '{print $2}')
Storage: $(df -h / | tail -1 | awk '{print $2 " total, " $4 " available"}')

NETWORK STATUS
==============
$(ip addr show | grep -E '^[0-9]+:|inet ' | head -10)

SERVICES STATUS
===============
NetworkManager: $(systemctl is-active NetworkManager)
SDDM: $(systemctl is-active sddm)
SSH: $(systemctl is-active sshd)
UFW: $(sudo ufw status | head -1)
fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "inactive")

USER SERVICES
=============
PipeWire: $(systemctl --user is-active pipewire 2>/dev/null || echo "inactive")
WirePlumber: $(systemctl --user is-active wireplumber 2>/dev/null || echo "inactive")

INSTALLED PACKAGES
==================
Total packages: $(pacman -Q | wc -l)
AUR packages: $(yay -Qm 2>/dev/null | wc -l || echo "0")

DISK USAGE
==========
$(df -h | grep -E '^/dev/')

MEMORY USAGE
============
$(free -h)

EOF
    
    success "System report created: $report_file"
}

# Setup maintenance scripts
setup_maintenance() {
    info "Setting up maintenance scripts..."
    
    # Create maintenance script directory
    mkdir -p "$HOME/.local/bin"
    
    # Create system update script
    cat > "$HOME/.local/bin/system-update" << 'EOF'
#!/bin/bash
# System Update Script

echo "Updating system packages..."
sudo pacman -Syu

echo "Updating AUR packages..."
yay -Sua

echo "Cleaning package cache..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm

echo "System update complete!"
EOF
    
    # Create system status script
    cat > "$HOME/.local/bin/system-status" << 'EOF'
#!/bin/bash
# System Status Script

echo "=== System Status ==="
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo
echo "=== Memory Usage ==="
free -h
echo
echo "=== Disk Usage ==="
df -h /
echo
echo "=== Network Status ==="
nmcli -t -f STATE general
echo
echo "=== Services ==="
systemctl is-active NetworkManager sddm sshd
echo
echo "=== Security ==="
sudo ufw status | head -1
systemctl is-active fail2ban 2>/dev/null || echo "fail2ban: inactive"
EOF
    
    # Make scripts executable
    chmod +x "$HOME/.local/bin/system-update"
    chmod +x "$HOME/.local/bin/system-status"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    success "Maintenance scripts created in ~/.local/bin/"
}

# Run comprehensive validation
run_validation() {
    info "Running comprehensive system validation..."
    
    validate_desktop
    validate_services
    validate_security
    validate_audio
    validate_network
    validate_aur
    
    info "System validation complete!"
}

# Main function
main() {
    info "Starting post-installation configuration and validation..."
    
    # Check if running on the installed system
    if [[ ! -d "$INSTALL_DIR" ]]; then
        warn "Installation directory not found, some validations may be skipped"
    fi
    
    # Run validation
    run_validation
    
    # Create system report
    create_system_report
    
    # Setup maintenance tools
    setup_maintenance
    
    info "Post-installation configuration complete!"
    info "System report available at: $HOME/system_report.txt"
    info "Maintenance scripts available: system-update, system-status"
    
    # Final recommendations
    echo
    echo -e "${BLUE}=== SETUP COMPLETE ===${NC}"
    echo -e "${GREEN}Your Arch Linux Hyprland system is ready!${NC}"
    echo
    echo "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. Log in and select 'Hyprland' session"
    echo "3. Test key bindings: Super+T (terminal), Super+R (launcher)"
    echo "4. Review system report: cat ~/system_report.txt"
    echo "5. Run system status: system-status"
    echo
    echo "For maintenance:"
    echo "- Update system: system-update"
    echo "- Check status: system-status"
    echo "- View logs: journalctl -f"
    echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi