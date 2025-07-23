#!/bin/bash
#
# network.sh - Unified Network Configuration Utility
#
# Consolidates network setup functionality from multiple scripts:
# - auto_network_setup.sh
# - Network code scattered across deployment scripts
# - WiFi configuration and management
#
# Usage:
#   ./network.sh [COMMAND] [OPTIONS]
#   source network.sh && setup_network [mode]
#
# Commands:
#   setup [MODE]      Configure network (auto|manual|skip)
#   test             Test network connectivity  
#   wifi             Configure WiFi connection
#   ethernet         Configure ethernet connection
#   status           Show network status
#   help             Show help
#

# Load common functions
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=../internal/common.sh
source "$SCRIPT_DIR/../internal/common.sh"

# Network configuration
readonly NETWORK_TEST_HOSTS=("8.8.8.8" "1.1.1.1" "208.67.222.222")
readonly NETWORK_TEST_TIMEOUT=5
readonly DHCP_TIMEOUT=30
readonly WIFI_SCAN_TIMEOUT=10

# Network state
NETWORK_MODE="auto"
WIFI_SSID=""
WIFI_PASSWORD=""
ETHERNET_INTERFACE=""
WIFI_INTERFACE=""
NETWORK_CONFIGURED=false

#
# Network Detection Functions
#

# Detect available network interfaces
detect_network_interfaces() {
    log_debug "Detecting network interfaces..."
    
    # Find ethernet interfaces
    local ethernet_interfaces=()
    while IFS= read -r interface; do
        if [[ -n "${interface:-}" ]]; then
            ethernet_interfaces+=("$interface")
        fi
    done < <(ip link show | grep -E '^[0-9]+:.*:' | grep -v 'lo:' | grep -E '(en|eth)' | cut -d: -f2 | tr -d ' ')
    
    # Find WiFi interfaces
    local wifi_interfaces=()
    while IFS= read -r interface; do
        if [[ -n "${interface:-}" ]]; then
            wifi_interfaces+=("$interface")
        fi
    done < <(ip link show | grep -E '^[0-9]+:.*:' | grep -v 'lo:' | grep -E '(wl|wifi|wlan)' | cut -d: -f2 | tr -d ' ')
    
    # Set primary interfaces
    if [[ ${#ethernet_interfaces[@]} -gt 0 ]]; then
        ETHERNET_INTERFACE="${ethernet_interfaces[0]}"
        log_debug "Ethernet interface: $ETHERNET_INTERFACE"
    fi
    
    if [[ ${#wifi_interfaces[@]} -gt 0 ]]; then
        WIFI_INTERFACE="${wifi_interfaces[0]}"
        log_debug "WiFi interface: $WIFI_INTERFACE"
    fi
    
    # Alternative detection using /sys/class/net
    if [[ -z "${ETHERNET_INTERFACE:-}" ]]; then
        for interface in /sys/class/net/*/; do
            local iface_name
            iface_name=$(basename "$interface")
            [[ "$iface_name" == "lo" ]] && continue
            
            if [[ -f "$interface/type" ]]; then
                local type
                type=$(cat "$interface/type")
                if [[ "$type" == "1" ]] && [[ "$iface_name" =~ ^(en|eth) ]]; then
                    ETHERNET_INTERFACE="$iface_name"
                    break
                fi
            fi
        done
    fi
    
    if [[ -z "${WIFI_INTERFACE:-}" ]]; then
        for interface in /sys/class/net/*/; do
            local iface_name
            iface_name=$(basename "$interface")
            [[ "$iface_name" == "lo" ]] && continue
            
            if [[ -d "$interface/wireless" ]] || [[ "$iface_name" =~ ^(wl|wlan) ]]; then
                WIFI_INTERFACE="$iface_name"
                break
            fi
        done
    fi
    
    log_info "Network interfaces detected:"
    [[ -n "${ETHERNET_INTERFACE:-}" ]] && log_info "  Ethernet: $ETHERNET_INTERFACE"
    [[ -n "${WIFI_INTERFACE:-}" ]] && log_info "  WiFi: $WIFI_INTERFACE"
    
    if [[ -z "${ETHERNET_INTERFACE:-}" && -z "$WIFI_INTERFACE" ]]; then
        log_error "No network interfaces detected"
        return 1
    fi
    
    return 0
}

# Check if interface is up and has carrier
check_interface_status() {
    local interface="$1"
    
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        return 1
    fi
    
    # Check if interface is up
    local operstate
    if [[ -f "/sys/class/net/$interface/operstate" ]]; then
        operstate=$(cat "/sys/class/net/$interface/operstate")
        if [[ "$operstate" == "up" ]]; then
            return 0
        fi
    fi
    
    # Alternative check using ip command
    if ip link show "$interface" 2>/dev/null | grep -q "state UP"; then
        return 0
    fi
    
    return 1
}

# Check if interface has IP address
check_interface_ip() {
    local interface="$1"
    
    local ip_addr
    ip_addr=$(ip addr show "$interface" 2>/dev/null | grep -E 'inet [0-9]' | awk '{print $2}' | cut -d'/' -f1)
    
    if [[ -n "${ip_addr:-}" && "$ip_addr" != "127.0.0.1" ]]; then
        log_debug "Interface $interface has IP: $ip_addr"
        return 0
    fi
    
    return 1
}

#
# Network Testing Functions
#

# Test network connectivity to multiple hosts
test_network_connectivity() {
    local timeout="${1:-$NETWORK_TEST_TIMEOUT}"
    local test_hosts=("${2:-${NETWORK_TEST_HOSTS[@]}}")
    
    log_info "Testing network connectivity..."
    
    local successful_tests=0
    local total_tests=${#test_hosts[@]}
    
    for host in "${test_hosts[@]}"; do
        log_debug "Testing connectivity to $host..."
        
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            log_debug "✓ $host reachable"
            ((successful_tests++))
        else
            log_debug "✗ $host unreachable"
        fi
    done
    
    local success_rate=$((successful_tests * 100 / total_tests))
    log_info "Network test: $successful_tests/$total_tests hosts reachable ($success_rate%)"
    
    # Require at least 50% success rate
    if [[ $success_rate -ge 50 ]]; then
        return 0
    else
        return 1
    fi
}

# Test DNS resolution
test_dns_resolution() {
    local test_domains=("google.com" "cloudflare.com" "archlinux.org")
    local timeout=5
    
    log_debug "Testing DNS resolution..."
    
    for domain in "${test_domains[@]}"; do
        if timeout "$timeout" nslookup "$domain" >/dev/null 2>&1; then
            log_debug "✓ DNS resolution working ($domain)"
            return 0
        fi
    done
    
    log_warn "DNS resolution test failed"
    return 1
}

# Comprehensive network test
test_network_complete() {
    local connectivity_ok=false
    local dns_ok=false
    
    if test_network_connectivity; then
        connectivity_ok=true
    fi
    
    if test_dns_resolution; then
        dns_ok=true
    fi
    
    if [[ "$connectivity_ok" == "true" && "$dns_ok" == "true" ]]; then
        log_info "✓ Network is fully operational"
        return 0
    elif [[ "$connectivity_ok" == "true" ]]; then
        log_warn "⚠ Network connectivity OK, but DNS issues detected"
        return 1
    else
        log_error "✗ Network connectivity failed"
        return 2
    fi
}

#
# Ethernet Configuration
#

# Configure ethernet interface
setup_ethernet() {
    local interface="${1:-$ETHERNET_INTERFACE}"
    
    if [[ -z "${interface:-}" ]]; then
        log_error "No ethernet interface available"
        return 1
    fi
    
    log_info "Configuring ethernet interface: $interface"
    
    # Bring interface up
    if ! ip link set "$interface" up; then
        log_error "Failed to bring up ethernet interface: $interface"
        return 1
    fi
    
    # Wait a moment for interface to come up
    sleep 2
    
    # Check if already configured
    if check_interface_ip "$interface"; then
        log_info "Ethernet interface already has IP address"
        return 0
    fi
    
    # Try DHCP
    log_info "Requesting DHCP lease for $interface..."
    
    # Kill any existing DHCP clients for this interface
    pkill -f "dhcp.*$interface" 2>/dev/null || true
    
    # Try different DHCP clients
    if command_exists dhclient; then
        if timeout "$DHCP_TIMEOUT" dhclient "$interface" 2>/dev/null; then
            log_info "DHCP configuration successful with dhclient"
        else
            log_warn "DHCP with dhclient failed"
        fi
    elif command_exists dhcpcd; then
        if timeout "$DHCP_TIMEOUT" dhcpcd "$interface" 2>/dev/null; then
            log_info "DHCP configuration successful with dhcpcd"
        else
            log_warn "DHCP with dhcpcd failed"
        fi
    elif command_exists networkctl; then
        # systemd-networkd approach
        if networkctl up "$interface" 2>/dev/null; then
            log_info "Interface brought up with networkctl"
        else
            log_warn "networkctl failed"
        fi
    else
        log_warn "No DHCP client available"
    fi
    
    # Wait for IP assignment
    local wait_count=0
    while [[ $wait_count -lt 10 ]]; do
        if check_interface_ip "$interface"; then
            log_info "Ethernet configuration successful"
            return 0
        fi
        sleep 1
        ((wait_count++))
    done
    
    log_error "Failed to get IP address for ethernet interface"
    return 1
}

#
# WiFi Configuration
#

# Scan for WiFi networks
scan_wifi() {
    local interface="${1:-$WIFI_INTERFACE}"
    
    if [[ -z "${interface:-}" ]]; then
        log_error "No WiFi interface available"
        return 1
    fi
    
    log_info "Scanning for WiFi networks on $interface..."
    
    # Bring interface up
    ip link set "$interface" up 2>/dev/null || true
    
    # Different scanning methods
    local networks=()
    
    if command_exists iwlist; then
        # Use iwlist for scanning
        local scan_output
        if scan_output=$(timeout "$WIFI_SCAN_TIMEOUT" iwlist "$interface" scan 2>/dev/null); then
            while IFS= read -r line; do
                if [[ "$line" =~ ESSID:\"(.+)\" ]]; then
                    local ssid="${BASH_REMATCH[1]}"
                    if [[ -n "${ssid:-}" ]]; then
                        networks+=("$ssid")
                    fi
                fi
            done <<< "$scan_output"
        fi
    elif command_exists iw; then
        # Use iw for scanning  
        local scan_output
        if scan_output=$(timeout "$WIFI_SCAN_TIMEOUT" iw dev "$interface" scan 2>/dev/null); then
            while IFS= read -r line; do
                if [[ "$line" =~ SSID:\ (.+)$ ]]; then
                    local ssid="${BASH_REMATCH[1]}"
                    if [[ -n "${ssid:-}" ]]; then
                        networks+=("$ssid")
                    fi
                fi
            done <<< "$scan_output"
        fi
    fi
    
    if [[ ${#networks[@]} -gt 0 ]]; then
        log_info "Found ${#networks[@]} WiFi networks:"
        for network in "${networks[@]}"; do
            log_info "  - $network"
        done
        return 0
    else
        log_warn "No WiFi networks found"
        return 1
    fi
}

# Connect to WiFi network
connect_wifi() {
    local ssid="$1"
    local password="$2" 
    local interface="${3:-$WIFI_INTERFACE}"
    
    if [[ -z "${interface:-}" ]]; then
        log_error "No WiFi interface available"
        return 1
    fi
    
    if [[ -z "${ssid:-}" ]]; then
        log_error "WiFi SSID is required"
        return 1
    fi
    
    log_info "Connecting to WiFi network: $ssid"
    
    # Bring interface up
    ip link set "$interface" up 2>/dev/null || true
    
    # Use different connection methods
    if command_exists wpa_supplicant && command_exists wpa_passphrase; then
        # Method 1: wpa_supplicant
        connect_wifi_wpa_supplicant "$ssid" "$password" "$interface"
    elif command_exists nmcli; then
        # Method 2: NetworkManager
        connect_wifi_networkmanager "$ssid" "$password" "$interface"
    elif command_exists iwconfig && [[ -z "${password:-}" ]]; then
        # Method 3: Open network with iwconfig
        connect_wifi_iwconfig_open "$ssid" "$interface"
    else
        log_error "No suitable WiFi connection method available"
        return 1
    fi
}

# Connect using wpa_supplicant
connect_wifi_wpa_supplicant() {
    local ssid="$1"
    local password="$2"
    local interface="$3"
    
    local config_file="/tmp/wpa_supplicant_$$.conf"
    
    # Create wpa_supplicant config
    if [[ -n "${password:-}" ]]; then
        wpa_passphrase "$ssid" "$password" > "$config_file"
    else
        # Open network
        cat > "$config_file" << EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi
    
    # Kill existing wpa_supplicant
    pkill -f "wpa_supplicant.*$interface" 2>/dev/null || true
    
    # Start wpa_supplicant
    if wpa_supplicant -B -i "$interface" -c "$config_file" -D wext,nl80211 2>/dev/null; then
        log_info "wpa_supplicant started successfully"
        
        # Wait for connection
        local wait_count=0
        while [[ $wait_count -lt 15 ]]; do
            if iwconfig "$interface" 2>/dev/null | grep -q "Access Point"; then
                log_info "WiFi association successful"
                break
            fi
            sleep 1
            ((wait_count++))
        done
        
        # Get DHCP lease
        if setup_ethernet "$interface"; then
            log_info "WiFi connection successful"
            rm -f "$config_file"
            return 0
        fi
    fi
    
    rm -f "$config_file"
    return 1
}

# Connect using NetworkManager
connect_wifi_networkmanager() {
    local ssid="$1"
    local password="$2" 
    local interface="$3"
    
    if [[ -n "${password:-}" ]]; then
        if nmcli dev wifi connect "$ssid" password "$password" ifname "$interface" 2>/dev/null; then
            log_info "WiFi connection successful with NetworkManager"
            return 0
        fi
    else
        if nmcli dev wifi connect "$ssid" ifname "$interface" 2>/dev/null; then
            log_info "WiFi connection successful with NetworkManager (open network)"
            return 0
        fi
    fi
    
    return 1
}

# Connect to open network using iwconfig
connect_wifi_iwconfig_open() {
    local ssid="$1"
    local interface="$2"
    
    if iwconfig "$interface" essid "$ssid" 2>/dev/null; then
        sleep 3
        if setup_ethernet "$interface"; then
            log_info "WiFi connection successful (open network)"
            return 0
        fi
    fi
    
    return 1
}

# Interactive WiFi setup
setup_wifi_interactive() {
    local interface="${1:-$WIFI_INTERFACE}"
    
    if [[ -z "${interface:-}" ]]; then
        log_error "No WiFi interface available"
        return 1
    fi
    
    log_info "Interactive WiFi setup"
    
    # Scan for networks
    if ! scan_wifi "$interface"; then
        log_error "WiFi scan failed"
        return 1
    fi
    
    # Get SSID from user
    local ssid
    ssid=$(prompt_user "Enter WiFi network name (SSID)")
    
    if [[ -z "${ssid:-}" ]]; then
        log_error "No SSID provided"
        return 1
    fi
    
    # Get password
    local password
    if confirm "Does this network require a password?"; then
        password=$(prompt_user "Enter WiFi password" true)
    fi
    
    # Attempt connection
    if connect_wifi "$ssid" "$password" "$interface"; then
        WIFI_SSID="$ssid"
        WIFI_PASSWORD="$password"
        log_info "WiFi setup completed successfully"
        return 0
    else
        log_error "WiFi connection failed"
        return 1
    fi
}

#
# Main Network Setup Functions
#

# Auto network setup (try ethernet first, then WiFi)
setup_network_auto() {
    log_info "Auto network setup - trying ethernet first..."
    
    # Detect interfaces
    if ! detect_network_interfaces; then
        log_error "No network interfaces detected"
        return 1
    fi
    
    # Try ethernet first
    if [[ -n "${ETHERNET_INTERFACE:-}" ]]; then
        log_info "Attempting ethernet configuration..."
        
        if setup_ethernet "$ETHERNET_INTERFACE"; then
            if test_network_connectivity; then
                log_info "Ethernet setup successful"
                NETWORK_CONFIGURED=true
                return 0
            else
                log_warn "Ethernet configured but network test failed"
            fi
        else
            log_warn "Ethernet setup failed"
        fi
    fi
    
    # Try WiFi if ethernet failed
    if [[ -n "${WIFI_INTERFACE:-}" ]]; then
        log_info "Attempting WiFi configuration..."
        
        # Check for WiFi credentials in environment
        local wifi_ssid="${WIFI_SSID:-${DEPLOY_WIFI_SSID:-}}"
        local wifi_password="${WIFI_PASSWORD:-${DEPLOY_WIFI_PASSWORD:-}}"
        
        if [[ -n "${wifi_ssid:-}" ]]; then
            log_info "Using WiFi credentials from configuration"
            if connect_wifi "$wifi_ssid" "$wifi_password" "$WIFI_INTERFACE"; then
                if test_network_connectivity; then
                    log_info "WiFi setup successful"
                    NETWORK_CONFIGURED=true
                    return 0
                fi
            fi
        else
            log_info "No WiFi credentials found - skipping WiFi setup"
            log_info "Use manual mode or set WIFI_SSID/WIFI_PASSWORD environment variables"
        fi
    fi
    
    log_error "Auto network setup failed"
    return 1
}

# Manual network setup
setup_network_manual() {
    log_info "Manual network setup"
    
    # Detect interfaces
    if ! detect_network_interfaces; then
        log_error "No network interfaces detected"
        return 1
    fi
    
    # Let user choose method
    echo "Available network interfaces:"
    [[ -n "${ETHERNET_INTERFACE:-}" ]] && echo "  1) Ethernet ($ETHERNET_INTERFACE)"
    [[ -n "${WIFI_INTERFACE:-}" ]] && echo "  2) WiFi ($WIFI_INTERFACE)"
    echo "  3) Skip network setup"
    
    local choice
    choice=$(prompt_user "Choose network setup method (1-3)")
    
    case "$choice" in
        1)
            if [[ -n "${ETHERNET_INTERFACE:-}" ]]; then
                setup_ethernet "$ETHERNET_INTERFACE"
            else
                log_error "No ethernet interface available"
                return 1
            fi
            ;;
        2)
            if [[ -n "${WIFI_INTERFACE:-}" ]]; then
                setup_wifi_interactive "$WIFI_INTERFACE"
            else
                log_error "No WiFi interface available"
                return 1
            fi
            ;;
        3)
            log_info "Skipping network setup"
            return 0
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Test network if configured
    if test_network_connectivity; then
        NETWORK_CONFIGURED=true
        log_info "Manual network setup successful"
        return 0
    else
        log_error "Network test failed after manual setup"
        return 1
    fi
}

# Main network setup function
setup_network() {
    local mode="${1:-$NETWORK_MODE}"
    
    log_info "Setting up network (mode: $mode)"
    
    case "$mode" in
        auto)
            setup_network_auto
            ;;
        manual)
            setup_network_manual
            ;;
        skip)
            log_info "Skipping network setup as requested"
            return 0
            ;;
        *)
            log_error "Unknown network mode: $mode"
            return 1
            ;;
    esac
}

# Show network status
show_network_status() {
    log_info "Network Status:"
    
    # Show interfaces
    if [[ -n "${ETHERNET_INTERFACE:-}" ]]; then
        local eth_status="DOWN"
        local eth_ip=""
        
        if check_interface_status "$ETHERNET_INTERFACE"; then
            eth_status="UP"
        fi
        
        if check_interface_ip "$ETHERNET_INTERFACE"; then
            eth_ip=$(ip addr show "$ETHERNET_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
        fi
        
        log_info "  Ethernet ($ETHERNET_INTERFACE): $eth_status ${eth_ip:+- $eth_ip}"
    fi
    
    if [[ -n "${WIFI_INTERFACE:-}" ]]; then
        local wifi_status="DOWN"
        local wifi_ssid=""
        local wifi_ip=""
        
        if check_interface_status "$WIFI_INTERFACE"; then
            wifi_status="UP"
        fi
        
        if command_exists iwconfig; then
            wifi_ssid=$(iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep 'ESSID:' | sed 's/.*ESSID:"\(.*\)".*/\1/')
        fi
        
        if check_interface_ip "$WIFI_INTERFACE"; then
            wifi_ip=$(ip addr show "$WIFI_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
        fi
        
        log_info "  WiFi ($WIFI_INTERFACE): $wifi_status ${wifi_ssid:+- $wifi_ssid} ${wifi_ip:+- $wifi_ip}"
    fi
    
    # Show connectivity
    if test_network_connectivity >/dev/null 2>&1; then
        log_info "  Internet: Connected"
    else
        log_warn "  Internet: Not connected"
    fi
    
    # Show DNS
    if test_dns_resolution >/dev/null 2>&1; then
        log_info "  DNS: Working"
    else
        log_warn "  DNS: Not working"
    fi
}

#
# Command Line Interface
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    
    case "${1:-help}" in
        setup)
            setup_network "${2:-auto}"
            ;;
        test)
            test_network_complete
            ;;
        wifi)
            if [[ -n "$2" ]]; then
                connect_wifi "$2" "$3"
            else
                setup_wifi_interactive
            fi
            ;;
        ethernet)
            setup_ethernet "$2"
            ;;
        scan)
            scan_wifi
            ;;
        status)
            show_network_status
            ;;
        help|*)
            cat << EOF
Network Configuration Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  setup [MODE]         Configure network (auto|manual|skip)
  test                 Test network connectivity
  wifi [SSID] [PASS]   Configure WiFi (interactive if no args)
  ethernet [IFACE]     Configure ethernet
  scan                 Scan for WiFi networks
  status               Show network status
  help                 Show this help

Modes:
  auto                 Try ethernet first, then WiFi (default)
  manual               Interactive interface selection
  skip                 Skip network configuration

Environment Variables:
  WIFI_SSID           WiFi network name
  WIFI_PASSWORD       WiFi password
  DEPLOY_WIFI_SSID    Alternative WiFi SSID variable
  DEPLOY_WIFI_PASSWORD Alternative WiFi password variable

Examples:
  $0 setup auto        # Automatic network setup
  $0 wifi MyWiFi pass123  # Connect to specific WiFi
  $0 test             # Test network connectivity
  $0 status           # Show current network status

EOF
            ;;
    esac
fi