#!/bin/bash
# Automatic Network Setup Script
# Handles WiFi detection and connection automatically

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we're connected to internet
check_internet() {
    if ping -c 1 8.8.8.8 &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Auto-detect and setup ethernet
setup_ethernet() {
    echo -e "${BLUE}🔌 Checking ethernet connection...${NC}"
    
    # Enable ethernet interfaces
    for iface in $(ip link show | grep -E "en[ospx]" | cut -d: -f2 | tr -d ' '); do
        echo "Bringing up interface: $iface"
        ip link set "$iface" up
        
        # Try DHCP
        dhcpcd "$iface" &
        sleep 3
        
        if check_internet; then
            echo -e "${GREEN}✅ Ethernet connected via $iface${NC}"
            return 0
        fi
    done
    
    return 1
}

# Interactive WiFi setup with auto-detection
setup_wifi() {
    echo -e "${BLUE}📶 Setting up WiFi...${NC}"
    
    # Check if WiFi hardware exists
    if ! iwctl device list 2>/dev/null | grep -q "wlan"; then
        echo -e "${YELLOW}⚠️  No WiFi hardware detected${NC}"
        return 1
    fi
    
    # Get WiFi device
    local wifi_device
    wifi_device=$(iwctl device list | grep wlan | awk '{print $1}' | head -1)
    
    if [[ -z "$wifi_device" ]]; then
        echo -e "${YELLOW}⚠️  No WiFi device found${NC}"
        return 1
    fi
    
    echo "WiFi device: $wifi_device"
    
    # Scan for networks
    echo "Scanning for WiFi networks..."
    iwctl station "$wifi_device" scan
    sleep 3
    
    # Show available networks
    echo -e "${BLUE}Available WiFi networks:${NC}"
    iwctl station "$wifi_device" get-networks | tail -n +5 | head -20
    echo
    
    # Get network selection
    local attempts=0
    while [[ $attempts -lt 3 ]]; do
        read -p "Enter WiFi network name (SSID): " wifi_ssid
        
        if [[ -z "$wifi_ssid" ]]; then
            echo "Please enter a network name"
            continue
        fi
        
        # Check if network exists
        if iwctl station "$wifi_device" get-networks | grep -q "$wifi_ssid"; then
            break
        else
            echo "Network '$wifi_ssid' not found. Please try again."
            ((attempts++))
        fi
    done
    
    if [[ $attempts -eq 3 ]]; then
        echo -e "${YELLOW}⚠️  Too many failed attempts${NC}"
        return 1
    fi
    
    # Get password securely
    echo
    read -s -p "Enter WiFi password (hidden): " wifi_password
    echo
    
    # Connect to WiFi
    echo "Connecting to $wifi_ssid..."
    
    # Use iwctl to connect
    if echo "$wifi_password" | iwctl --passphrase - station "$wifi_device" connect "$wifi_ssid"; then
        echo "Waiting for connection..."
        sleep 5
        
        if check_internet; then
            echo -e "${GREEN}✅ WiFi connected successfully!${NC}"
            
            # Save connection for later use (optional)
            echo "WiFi connection saved for future use"
            return 0
        else
            echo -e "${YELLOW}⚠️  Connected to WiFi but no internet access${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Failed to connect to WiFi${NC}"
        return 1
    fi
}

# Try automatic connection methods
auto_connect() {
    echo -e "${BLUE}🌐 Auto-detecting network connection...${NC}"
    
    # First check if already connected
    if check_internet; then
        echo -e "${GREEN}✅ Already connected to internet!${NC}"
        return 0
    fi
    
    # Try ethernet first (usually automatic)
    if setup_ethernet; then
        return 0
    fi
    
    # If ethernet fails, try WiFi
    echo -e "${YELLOW}Ethernet not available, trying WiFi...${NC}"
    if setup_wifi; then
        return 0
    fi
    
    # If both fail, give manual options
    echo -e "${YELLOW}⚠️  Automatic connection failed${NC}"
    echo
    echo "Manual options:"
    echo "1. wifi-menu  # Use built-in WiFi menu"
    echo "2. dhcpcd eth0  # Manual ethernet"
    echo "3. Skip network setup (not recommended)"
    echo
    
    read -p "Choose option [1-3]: " choice
    case $choice in
        1)
            wifi-menu
            ;;
        2)
            dhcpcd eth0 &
            sleep 5
            ;;
        3)
            echo -e "${YELLOW}⚠️  Skipping network setup${NC}"
            return 1
            ;;
        *)
            echo "Invalid choice"
            return 1
            ;;
    esac
    
    # Check if manual method worked
    if check_internet; then
        echo -e "${GREEN}✅ Manual connection successful!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Still no internet connection${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Automatic Network Setup${NC}"
    echo "Detecting and configuring internet connection..."
    echo
    
    if auto_connect; then
        echo
        echo -e "${GREEN}🎉 Network setup completed successfully!${NC}"
        echo "Internet connection is ready for deployment."
        
        # Test connection
        echo "Testing connection speed..."
        if command -v curl >/dev/null 2>&1; then
            echo "Download test:"
            curl -w "Speed: %{speed_download} bytes/sec\n" -s -o /dev/null http://speedtest.tele2.net/1MB.zip
        fi
        
        return 0
    else
        echo
        echo -e "${YELLOW}⚠️  Network setup failed${NC}"
        echo "Please configure internet manually before continuing:"
        echo
        echo "For WiFi: wifi-menu"
        echo "For Ethernet: dhcpcd eth0"
        echo
        return 1
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Automatic Network Setup Script

Usage: auto_network_setup.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --ethernet-only     Only try ethernet connection
  --wifi-only         Only try WiFi connection
  --interactive       Force interactive mode
  --silent           Minimal output

Examples:
  ./auto_network_setup.sh                    # Auto-detect best method
  ./auto_network_setup.sh --wifi-only        # Only try WiFi
  ./auto_network_setup.sh --ethernet-only    # Only try ethernet

EOF
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --ethernet-only)
        setup_ethernet
        ;;
    --wifi-only)
        setup_wifi
        ;;
    --interactive)
        # Force interactive WiFi setup
        setup_wifi
        ;;
    --silent)
        # Silent mode - minimal output
        exec > /dev/null 2>&1
        auto_connect
        ;;
    *)
        main
        ;;
esac