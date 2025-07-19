#!/bin/bash
# System Information Tool
# Comprehensive system information display for Arch Linux Hyprland system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}=================================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=================================================================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
}

print_info() {
    printf "%-25s: %s\n" "$1" "$2"
}

print_status() {
    local status="$1"
    local service="$2"
    
    if [[ "$status" == "active" ]]; then
        echo -e "%-25s: ${GREEN}●${NC} $service" "$service"
    elif [[ "$status" == "inactive" ]]; then
        echo -e "%-25s: ${RED}●${NC} $service" "$service"
    else
        echo -e "%-25s: ${YELLOW}●${NC} $service" "$service"
    fi
}

# System Information
print_header "SYSTEM INFORMATION"

print_info "Hostname" "$(hostname)"
print_info "Kernel" "$(uname -r)"
print_info "Architecture" "$(uname -m)"
print_info "Distribution" "$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
print_info "Uptime" "$(uptime -p)"
print_info "Load Average" "$(uptime | awk -F'load average:' '{print $2}')"

# Hardware Information
print_header "HARDWARE INFORMATION"

print_section "CPU"
cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
cpu_cores=$(nproc)
cpu_threads=$(grep "processor" /proc/cpuinfo | wc -l)
cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' | cut -d. -f1)

print_info "CPU Model" "$cpu_model"
print_info "Cores/Threads" "$cpu_cores/$cpu_threads"
print_info "Current Frequency" "${cpu_freq} MHz"

# CPU temperature if available
if command -v sensors >/dev/null 2>&1; then
    temp=$(sensors 2>/dev/null | grep -E "Core|Package" | head -1 | awk '{print $3}' | tr -d '+°C')
    if [[ -n "$temp" ]]; then
        print_info "CPU Temperature" "${temp}°C"
    fi
fi

print_section "Memory"
mem_info=$(free -h | grep "Mem:")
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_used=$(echo "$mem_info" | awk '{print $3}')
mem_available=$(echo "$mem_info" | awk '{print $7}')
mem_percent=$(free | grep "Mem:" | awk '{printf "%.1f", ($3/$2) * 100}')

print_info "Total Memory" "$mem_total"
print_info "Used Memory" "$mem_used ($mem_percent%)"
print_info "Available Memory" "$mem_available"

# Swap information
swap_info=$(free -h | grep "Swap:")
if [[ -n "$swap_info" ]]; then
    swap_total=$(echo "$swap_info" | awk '{print $2}')
    swap_used=$(echo "$swap_info" | awk '{print $3}')
    print_info "Swap Total" "$swap_total"
    print_info "Swap Used" "$swap_used"
fi

print_section "Storage"
print_info "Disk Usage" ""
df -h | grep -E "^/dev/" | while read filesystem size used avail percent mount; do
    printf "  %-15s: %s used of %s (%s) on %s\n" "$filesystem" "$used" "$size" "$percent" "$mount"
done

print_section "Graphics"
if command -v lspci >/dev/null 2>&1; then
    gpu_info=$(lspci | grep -E "VGA|3D|Display" | cut -d: -f3 | sed 's/^ *//')
    if [[ -n "$gpu_info" ]]; then
        print_info "Graphics Card" "$gpu_info"
    fi
fi

# Network Information
print_header "NETWORK INFORMATION"

print_section "Network Interfaces"
ip addr show | grep -E "^[0-9]+:" | while read line; do
    interface=$(echo "$line" | awk -F': ' '{print $2}')
    state=$(echo "$line" | grep -o "state [A-Z]*" | awk '{print $2}')
    
    if [[ "$interface" != "lo" ]]; then
        # Get IP address
        ip_addr=$(ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        if [[ -n "$ip_addr" ]]; then
            printf "  %-15s: %s (%s)\n" "$interface" "$ip_addr" "$state"
        else
            printf "  %-15s: No IP (%s)\n" "$interface" "$state"
        fi
    fi
done

# DNS information
print_section "DNS Configuration"
if [[ -f /etc/resolv.conf ]]; then
    dns_servers=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    print_info "DNS Servers" "$dns_servers"
fi

# Hyprland Environment
print_header "HYPRLAND ENVIRONMENT"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    print_info "Hyprland Session" "Active (${HYPRLAND_INSTANCE_SIGNATURE})"
    
    if command -v hyprctl >/dev/null 2>&1; then
        # Workspace information
        current_workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo "Unknown")
        total_workspaces=$(hyprctl workspaces -j 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
        print_info "Current Workspace" "$current_workspace"
        print_info "Total Workspaces" "$total_workspaces"
        
        # Window count
        window_count=$(hyprctl clients -j 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
        print_info "Open Windows" "$window_count"
        
        # Monitor information
        monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name): \(.width)x\(.height)@\(.refreshRate)Hz"' 2>/dev/null || echo "Unknown")
        if [[ "$monitors" != "Unknown" ]]; then
            print_info "Monitors" ""
            echo "$monitors" | while read monitor; do
                echo "  $monitor"
            done
        fi
    fi
else
    print_info "Hyprland Session" "Not Active"
fi

# Environment variables
print_section "Environment"
print_info "XDG_SESSION_TYPE" "${XDG_SESSION_TYPE:-Not set}"
print_info "XDG_CURRENT_DESKTOP" "${XDG_CURRENT_DESKTOP:-Not set}"
print_info "WAYLAND_DISPLAY" "${WAYLAND_DISPLAY:-Not set}"

# Service Status
print_header "SYSTEM SERVICES"

services=(
    "NetworkManager"
    "bluetooth"
    "pipewire"
    "wireplumber"
    "ufw"
    "fail2ban"
    "sshd"
    "auditd"
)

for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^$service.service"; then
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        print_status "$status" "$service"
    fi
done

# Package Information
print_header "PACKAGE INFORMATION"

if command -v pacman >/dev/null 2>&1; then
    total_packages=$(pacman -Q | wc -l)
    explicit_packages=$(pacman -Qe | wc -l)
    aur_packages=$(pacman -Qm | wc -l)
    
    print_info "Total Packages" "$total_packages"
    print_info "Explicit Packages" "$explicit_packages"
    print_info "AUR Packages" "$aur_packages"
    
    # Check for updates
    if command -v checkupdates >/dev/null 2>&1; then
        updates=$(checkupdates 2>/dev/null | wc -l || echo "0")
        print_info "Available Updates" "$updates"
    fi
fi

# Security Status
print_header "SECURITY STATUS"

print_section "Firewall"
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [[ "$ufw_status" == "active" ]]; then
        echo -e "UFW Status              : ${GREEN}Active${NC}"
    else
        echo -e "UFW Status              : ${RED}Inactive${NC}"
    fi
else
    echo -e "UFW Status              : ${RED}Not installed${NC}"
fi

print_section "Fail2ban"
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    banned_ips=$(fail2ban-client status 2>/dev/null | grep "Currently banned:" | awk '{print $3}' || echo "0")
    echo -e "Fail2ban Status         : ${GREEN}Active${NC}"
    print_info "Currently Banned IPs" "$banned_ips"
else
    echo -e "Fail2ban Status         : ${RED}Inactive${NC}"
fi

print_section "System Integrity"
# Check for SUID files (basic count)
suid_count=$(find /usr/bin /usr/sbin -type f -perm -4000 2>/dev/null | wc -l)
print_info "SUID Binaries" "$suid_count"

# Last login information
print_header "USER ACTIVITY"
print_info "Current User" "$(whoami)"
print_info "Login Time" "$(who am i 2>/dev/null | awk '{print $3, $4}' || echo 'Unknown')"

# Recent logins
print_section "Recent Logins"
last -5 2>/dev/null | head -5 | while read line; do
    if [[ "$line" =~ ^[a-zA-Z] ]]; then
        echo "  $line"
    fi
done

echo -e "\n${GREEN}System information collection completed.${NC}"

# Performance metrics
print_header "PERFORMANCE METRICS"

print_section "CPU Usage"
if command -v top >/dev/null 2>&1; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    print_info "CPU Usage" "${cpu_usage}%"
fi

print_section "Top Processes by CPU"
ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
    printf "  %s\n" "$(echo "$line" | awk '{printf "%-10s %5s%% %s", $1, $3, $11}')"
done

print_section "Top Processes by Memory"
ps aux --sort=-%mem | head -6 | tail -5 | while read line; do
    printf "  %s\n" "$(echo "$line" | awk '{printf "%-10s %5s%% %s", $1, $4, $11}')"
done