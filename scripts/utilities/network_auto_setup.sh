#!/bin/bash
# Network Automation Setup Script
# Handles automatic WiFi connection and network configuration

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Configuration
CONFIG_FILE="${CONFIG_FILE:-$HOME/deployment_config.yml}"

error() {
    log_error "$1"
    exit 1
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

# Check if NetworkManager is available
check_network_manager() {
    log_info "Checking NetworkManager availability..."
    
    if command -v nmcli >/dev/null 2>&1; then
        if systemctl is-active --quiet NetworkManager; then
            log_success "NetworkManager is running"
            return 0
        else
            log_info "Starting NetworkManager..."
            sudo systemctl start NetworkManager || error "Failed to start NetworkManager"
            sleep 2
            return 0
        fi
    else
        log_warn "NetworkManager not available, using alternative methods"
        return 1
    fi
}

# Setup WiFi using NetworkManager
setup_wifi_networkmanager() {
    local ssid="$1"
    local password="$2"
    local security="${3:-wpa2}"
    
    log_info "Connecting to WiFi '$ssid' using NetworkManager..."
    
    # Delete existing connections with same SSID
    nmcli connection delete "$ssid" 2>/dev/null || true
    
    # Connect to WiFi
    case "$security" in
        "open")
            nmcli device wifi connect "$ssid" || error "Failed to connect to open WiFi network"
            ;;
        "wpa2"|"wpa3"|*)
            nmcli device wifi connect "$ssid" password "$password" || error "Failed to connect to WiFi network"
            ;;
    esac
    
    # Wait for connection
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if nmcli -t -f STATE general status | grep -q "connected"; then
            log_success "WiFi connected successfully"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    error "WiFi connection timeout"
}

# Setup WiFi using iwctl (fallback)
setup_wifi_iwctl() {
    local ssid="$1"
    local password="$2"
    
    log_info "Connecting to WiFi '$ssid' using iwctl..."
    
    # Get wireless interface
    local interface=$(iwctl device list | grep -E 'wlan[0-9]' | awk '{print $1}' | head -n1)
    if [[ -z "${interface:-}" ]]; then
        error "No wireless interface found"
    fi
    
    log_info "Using wireless interface: $interface"
    
    # Scan for networks
    iwctl station "$interface" scan
    sleep 3
    
    # Check if network is available
    if ! iwctl station "$interface" get-networks | grep -q "$ssid"; then
        error "WiFi network '$ssid' not found"
    fi
    
    # Connect to network
    iwctl --passphrase="$password" station "$interface" connect "$ssid" || error "Failed to connect to WiFi"
    
    # Wait for connection
    sleep 5
    
    # Verify connection
    if iwctl station "$interface" show | grep -q "connected"; then
        log_success "WiFi connected using iwctl"
    else
        error "WiFi connection failed"
    fi
}

# Setup WiFi using wpa_supplicant (manual method)
setup_wifi_manual() {
    local ssid="$1"
    local password="$2"
    
    log_info "Connecting to WiFi '$ssid' using wpa_supplicant..."
    
    # Get wireless interface
    local interface=$(ip link show | grep -E '^[0-9]+: wl' | cut -d':' -f2 | xargs | head -n1)
    if [[ -z "${interface:-}" ]]; then
        interface=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)
    fi
    
    if [[ -z "${interface:-}" ]]; then
        error "No wireless interface found"
    fi
    
    log_info "Using wireless interface: $interface"
    
    # Create temporary wpa_supplicant configuration
    local wpa_config="/tmp/wpa_supplicant_temp.conf"
    cat > "$wpa_config" << EOF
network={
    ssid="$ssid"
    psk="$password"
}
EOF
    
    # Kill existing wpa_supplicant processes
    sudo pkill wpa_supplicant 2>/dev/null || true
    sleep 1
    
    # Start wpa_supplicant
    sudo wpa_supplicant -B -i "$interface" -c "$wpa_config" || error "Failed to start wpa_supplicant"
    
    # Wait for association
    sleep 5
    
    # Get IP address via DHCP
    sudo dhclient "$interface" || error "Failed to get IP address"
    
    # Clean up
    rm -f "$wpa_config"
    
    log_success "WiFi connected using wpa_supplicant"
}

# Setup ethernet connection
setup_ethernet() {
    log_info "Setting up ethernet connection..."
    
    # Get ethernet interface
    local interface=$(ip link show | grep -E '^[0-9]+: e' | cut -d':' -f2 | xargs | head -n1)
    if [[ -z "${interface:-}" ]]; then
        log_warn "No ethernet interface found"
        return 1
    fi
    
    log_info "Using ethernet interface: $interface"
    
    # Bring interface up
    sudo ip link set "$interface" up
    
    # Try NetworkManager first
    if command -v nmcli >/dev/null 2>&1; then
        nmcli device connect "$interface" 2>/dev/null || {
            log_info "NetworkManager failed, trying DHCP directly"
            sudo dhclient "$interface" || log_warn "DHCP failed for ethernet"
        }
    else
        # Manual DHCP
        sudo dhclient "$interface" || log_warn "DHCP failed for ethernet"
    fi
    
    # Check if we got an IP
    if ip addr show "$interface" | grep -q "inet "; then
        log_success "Ethernet connected successfully"
        return 0
    else
        log_warn "Ethernet connection failed"
        return 1
    fi
}

# Test internet connectivity
test_connectivity() {
    log_info "Testing internet connectivity..."
    
    local test_hosts=("archlinux.org" "google.com" "1.1.1.1")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 3 -W 5 "$host" >/dev/null 2>&1; then
            log_success "Internet connectivity confirmed (via $host)"
            return 0
        fi
    done
    
    error "No internet connectivity detected"
}

# Setup DNS
setup_dns() {
    log_info "Setting up DNS configuration..."
    
    # Use systemd-resolved if available
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log_info "Using systemd-resolved for DNS"
        return 0
    fi
    
    # Fallback to manual DNS setup
    local dns_servers=("1.1.1.1" "8.8.8.8" "1.0.0.1" "8.8.4.4")
    
    # Backup existing resolv.conf
    if [[ -f /etc/resolv.conf ]] && [[ ! -L /etc/resolv.conf ]]; then
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    fi
    
    # Create new resolv.conf
    {
        echo "# Generated by network automation"
        for dns in "${dns_servers[@]}"; do
            echo "nameserver $dns"
        done
    } | sudo tee /etc/resolv.conf.new > /dev/null
    
    sudo mv /etc/resolv.conf.new /etc/resolv.conf
    
    log_success "DNS configuration updated"
}

# Configure network profiles
configure_network_profiles() {
    log_info "Configuring network profiles..."
    
    local wifi_enabled=$(parse_nested_config "network" "enabled")
    local wifi_ssid=$(parse_nested_config "network" "ssid")
    local auto_connect_wifi=$(parse_nested_config "network" "auto_connect")
    
    if [[ "$wifi_enabled" == "true" ]] && [[ -n "${wifi_ssid:-}" ]] && [[ "$auto_connect_wifi" == "true" ]]; then
        if command -v nmcli >/dev/null 2>&1; then
            log_info "Configuring WiFi profile for auto-connect..."
            
            # Set connection to auto-connect
            nmcli connection modify "$wifi_ssid" connection.autoconnect yes 2>/dev/null || log_warn "Failed to set auto-connect"
            nmcli connection modify "$wifi_ssid" connection.autoconnect-priority 100 2>/dev/null || log_warn "Failed to set priority"
            
            log_success "WiFi profile configured for auto-connect"
        fi
    fi
}

# Setup network monitoring
setup_network_monitoring() {
    log_info "Setting up network monitoring..."
    
    # Create network status script
    local script_path="$HOME/.local/bin/network-status"
    mkdir -p "$(dirname "$script_path")"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Network Status Monitor

echo "=== Network Status ==="
echo "Date: $(date)"
echo

# Check NetworkManager status
if command -v nmcli >/dev/null 2>&1; then
    echo "NetworkManager Status:"
    nmcli general status
    echo
    
    echo "Active Connections:"
    nmcli connection show --active
    echo
    
    echo "WiFi Networks:"
    nmcli device wifi list | head -10
    echo
fi

# Check interfaces
echo "Network Interfaces:"
ip addr show | grep -E '^[0-9]+:|inet ' | grep -v '127.0.0.1'
echo

# Check routing
echo "Default Route:"
ip route | grep default
echo

# Check connectivity
echo "Connectivity Test:"
for host in google.com archlinux.org; do
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        echo "[OK] $host: reachable"
    else
        echo "[FAIL] $host: unreachable"
    fi
done
echo

# Check DNS
echo "DNS Configuration:"
if [[ -f /etc/resolv.conf ]]; then
    grep nameserver /etc/resolv.conf | head -3
else
    echo "No resolv.conf found"
fi
EOF
    
    chmod +x "$script_path"
    log_success "Network monitoring script created: $script_path"
}

# Main network setup function
setup_network() {
    log_info "Starting automated network setup..."
    
    # Load configuration
    local wifi_enabled=$(parse_nested_config "network" "enabled")
    local wifi_ssid=$(parse_nested_config "network" "ssid")
    local wifi_password=$(parse_nested_config "network" "password")
    local wifi_security=$(parse_nested_config "network" "security")
    local ethernet_enabled=$(parse_nested_config "network" "enabled")
    
    # Check NetworkManager
    local nm_available=false
    if check_network_manager; then
        nm_available=true
    fi
    
    # Setup ethernet first (usually more reliable)
    if [[ "$ethernet_enabled" == "true" ]] || [[ -z "${ethernet_enabled:-}" ]]; then
        if setup_ethernet; then
            log_info "Ethernet connection established"
        else
            log_info "Ethernet setup failed or not available"
        fi
    fi
    
    # Setup WiFi if configured
    if [[ "$wifi_enabled" == "true" ]] && [[ -n "${wifi_ssid:-}" ]] && [[ -n "${wifi_password:-}" ]]; then
        log_info "Setting up WiFi connection..."
        
        if [[ "$nm_available" == true ]]; then
            setup_wifi_networkmanager "$wifi_ssid" "$wifi_password" "$wifi_security"
        elif command -v iwctl >/dev/null 2>&1; then
            setup_wifi_iwctl "$wifi_ssid" "$wifi_password"
        else
            setup_wifi_manual "$wifi_ssid" "$wifi_password"
        fi
    elif [[ "$wifi_enabled" == "true" ]]; then
        log_warn "WiFi enabled but SSID or password not configured"
    fi
    
    # Test connectivity
    test_connectivity
    
    # Setup DNS
    setup_dns
    
    # Configure profiles for persistence
    configure_network_profiles
    
    # Setup monitoring
    setup_network_monitoring
    
    log_success "Network setup completed successfully"
}

# Quick connectivity check function
quick_connect() {
    log_info "Running quick connectivity check and setup..."
    
    # Test current connectivity
    if ping -c 1 -W 3 google.com >/dev/null 2>&1; then
        log_success "Already connected to internet"
        return 0
    fi
    
    # Try to connect using configuration
    setup_network
}

# Emergency network recovery
network_recovery() {
    log_warn "Running network recovery procedures..."
    
    # Restart NetworkManager
    if systemctl is-active --quiet NetworkManager; then
        log_info "Restarting NetworkManager..."
        sudo systemctl restart NetworkManager
        sleep 5
    fi
    
    # Reset network interfaces
    for interface in $(ip link show | grep -E '^[0-9]+: (wl|en)' | cut -d':' -f2 | xargs); do
        log_info "Resetting interface: $interface"
        sudo ip link set "$interface" down
        sleep 1
        sudo ip link set "$interface" up
    done
    
    # Retry connection
    sleep 5
    quick_connect
}

# Main function
main() {
    local action="${1:-setup}"
    
    case "$action" in
        "setup")
            setup_network
            ;;
        "quick")
            quick_connect
            ;;
        "recovery")
            network_recovery
            ;;
        "status")
            if [[ -x "$HOME/.local/bin/network-status" ]]; then
                "$HOME/.local/bin/network-status"
            else
                log_info "Network status script not found, showing basic info..."
                ip addr show | grep -E '^[0-9]+:|inet '
            fi
            ;;
        "test")
            test_connectivity
            ;;
        *)
            echo "Usage: $0 {setup|quick|recovery|status|test}"
            echo "  setup    - Full network setup using configuration"
            echo "  quick    - Quick connectivity check and setup"
            echo "  recovery - Emergency network recovery"
            echo "  status   - Show network status"
            echo "  test     - Test internet connectivity"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi