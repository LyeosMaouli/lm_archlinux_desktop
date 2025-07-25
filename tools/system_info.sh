#!/bin/bash
# System Information Tool
# Comprehensive system information display for Arch Linux Hyprland system

set -euo pipefail
# Load common functions
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
source "$SCRIPT_DIR/../scripts/internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}
source "$SCRIPT_DIR/../scripts/internal/formatting.sh" || {
    echo "Error: Cannot load formatting.sh"
    exit 1
}

# System Information
log_info "Starting system information collection"
echo -e "\n${BLUE}=== SYSTEM INFORMATION ===${NC}"

printf "%-20s: %s\n" "Hostname" "$(hostname)"
printf "%-20s: %s\n" "Kernel" "$(uname -r)"
printf "%-20s: %s\n" "Architecture" "$(uname -m)"
printf "%-20s: %s\n" "Distribution" "$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
printf "%-20s: %s\n" "Uptime" "$(uptime -p)"
printf "%-20s: %s\n" "Load Average" "$(uptime | awk -F'load average:' '{print $2}')"

# Hardware Information
echo -e "\n${BLUE}=== HARDWARE INFORMATION ===${NC}"
echo -e "\n${YELLOW}CPU:${NC}"
cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
cpu_cores=$(nproc)
cpu_threads=$(grep "processor" /proc/cpuinfo | wc -l)
cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' | cut -d. -f1)

printf "%-20s: %s\n" "CPU Model" "$cpu_model"
printf "%-20s: %s\n" "Cores/Threads" "$cpu_cores/$cpu_threads"
printf "%-20s: %s\n" "Current Frequency" "${cpu_freq} MHz"

# CPU temperature if available
if command -v sensors >/dev/null 2>&1; then
    temp=$(sensors 2>/dev/null | grep -E "Core|Package" | head -1 | awk '{print $3}' | tr -d '+°C')
    if [[ -n "${temp:-}" ]]; then
        printf "%-20s: %s\n" "CPU Temperature" "${temp}°C"
    fi
fi

echo -e "\n${YELLOW}Memory:${NC}"
mem_info=$(free -h | grep "Mem:")
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_used=$(echo "$mem_info" | awk '{print $3}')
mem_available=$(echo "$mem_info" | awk '{print $7}')
mem_percent=$(free | grep "Mem:" | awk '{printf "%.1f", ($3/$2) * 100}')

printf "%-20s: %s\n" "Total Memory" "$mem_total"
printf "%-20s: %s\n" "Used Memory" "$mem_used ($mem_percent%)"
printf "%-20s: %s\n" "Available Memory" "$mem_available"

# Swap information
swap_info=$(free -h | grep "Swap:")
if [[ -n "${swap_info:-}" ]]; then
    swap_total=$(echo "$swap_info" | awk '{print $2}')
    swap_used=$(echo "$swap_info" | awk '{print $3}')
    printf "%-20s: %s\n" "Swap Total" "$swap_total"
    printf "%-20s: %s\n" "Swap Used" "$swap_used"
fi

echo -e "\n${YELLOW}Storage:${NC}"
printf "%-20s:\n" "Disk Usage"
df -h | grep -E "^/dev/" | while read filesystem size used avail percent mount; do
    printf "  %-15s: %s used of %s (%s) on %s\n" "$filesystem" "$used" "$size" "$percent" "$mount"
done

echo -e "\n${YELLOW}Graphics:${NC}"
if command -v lspci >/dev/null 2>&1; then
    gpu_info=$(lspci | grep -E "VGA|3D|Display" | cut -d: -f3 | sed 's/^ *//')
    if [[ -n "${gpu_info:-}" ]]; then
        printf "%-20s: %s\n" "Graphics Card" "$gpu_info"
    fi
fi

# Network Information
echo -e "\n${BLUE}=== NETWORK INFORMATION ===${NC}"
echo -e "\n${YELLOW}Network Interfaces:${NC}"
ip addr show | grep -E "^[0-9]+:" | while read line; do
    interface=$(echo "$line" | awk -F': ' '{print $2}')
    state=$(echo "$line" | grep -o "state [A-Z]*" | awk '{print $2}')
    
    if [[ "$interface" != "lo" ]]; then
        # Get IP address
        ip_addr=$(ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        if [[ -n "${ip_addr:-}" ]]; then
            printf "  %-15s: %s (%s)\n" "$interface" "$ip_addr" "$state"
        else
            printf "  %-15s: No IP (%s)\n" "$interface" "$state"
        fi
    fi
done

# DNS information
echo -e "\n${YELLOW}DNS Configuration:${NC}"
if [[ -f /etc/resolv.conf ]]; then
    dns_servers=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    printf "%-20s: %s\n" "DNS Servers" "$dns_servers"
fi

# Hyprland Environment
echo -e "\n${BLUE}=== HYPRLAND ENVIRONMENT ===${NC}"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    printf "%-20s: %s\n" "Hyprland Session" "Active (${HYPRLAND_INSTANCE_SIGNATURE})"
    
    if command -v hyprctl >/dev/null 2>&1; then
        # Workspace information
        current_workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo "Unknown")
        total_workspaces=$(hyprctl workspaces -j 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
        printf "%-20s: %s\n" "Current Workspace" "$current_workspace"
        printf "%-20s: %s\n" "Total Workspaces" "$total_workspaces"
        
        # Window count
        window_count=$(hyprctl clients -j 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
        printf "%-20s: %s\n" "Open Windows" "$window_count"
        
        # Monitor information
        monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name): \(.width)x\(.height)@\(.refreshRate)Hz"' 2>/dev/null || echo "Unknown")
        if [[ "$monitors" != "Unknown" ]]; then
            printf "%-20s:\n" "Monitors"
            echo "$monitors" | while read monitor; do
                echo "  $monitor"
            done
        fi
    fi
else
    printf "%-20s: %s\n" "Hyprland Session" "Not Active"
fi

# Environment variables
echo -e "\n${YELLOW}Environment:${NC}"
printf "%-20s: %s\n" "XDG_SESSION_TYPE" "${XDG_SESSION_TYPE:-Not set}"
printf "%-20s: %s\n" "XDG_CURRENT_DESKTOP" "${XDG_CURRENT_DESKTOP:-Not set}"
printf "%-20s: %s\n" "WAYLAND_DISPLAY" "${WAYLAND_DISPLAY:-Not set}"

# Service Status
echo -e "\n${BLUE}=== SYSTEM SERVICES ===${NC}"

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
        if [[ "$status" == "active" ]]; then
            printf "%-20s: " "$service"
            printf "${GREEN}%s${NC}\n" "$status"
        else
            printf "%-20s: " "$service"
            printf "${RED}%s${NC}\n" "$status"
        fi
    fi
done

# Package Information
echo -e "\n${BLUE}=== PACKAGE INFORMATION ===${NC}"

if command -v pacman >/dev/null 2>&1; then
    total_packages=$(pacman -Q | wc -l)
    explicit_packages=$(pacman -Qe | wc -l)
    aur_packages=$(pacman -Qm | wc -l)
    
    printf "%-20s: %s\n" "Total Packages" "$total_packages"
    printf "%-20s: %s\n" "Explicit Packages" "$explicit_packages"
    printf "%-20s: %s\n" "AUR Packages" "$aur_packages"
    
    # Check for updates
    if command -v checkupdates >/dev/null 2>&1; then
        updates=$(checkupdates 2>/dev/null | wc -l || echo "0")
        printf "%-20s: %s\n" "Available Updates" "$updates"
    fi
fi

# Security Status
echo -e "\n${BLUE}=== SECURITY STATUS ===${NC}"
echo -e "\n${YELLOW}Firewall:${NC}"
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [[ "$ufw_status" == "active" ]]; then
        printf "%-20s: ${GREEN}%s${NC}\n" "UFW Status" "Active"
    else
        printf "%-20s: ${RED}%s${NC}\n" "UFW Status" "Inactive"
    fi
else
    printf "%-20s: ${RED}%s${NC}\n" "UFW Status" "Not installed"
fi

echo -e "\n${YELLOW}Fail2ban:${NC}"
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    banned_ips=$(fail2ban-client status 2>/dev/null | grep "Currently banned:" | awk '{print $3}' || echo "0")
    printf "%-20s: ${GREEN}%s${NC}\n" "Fail2ban Status" "Active"
    printf "%-20s: %s\n" "Currently Banned IPs" "$banned_ips"
else
    printf "%-20s: ${RED}%s${NC}\n" "Fail2ban Status" "Inactive"
fi

echo -e "\n${YELLOW}System Integrity:${NC}"
# Check for SUID files (basic count)
suid_count=$(find /usr/bin /usr/sbin -type f -perm -4000 2>/dev/null | wc -l)
printf "%-20s: %s\n" "SUID Binaries" "$suid_count"

# Last login information
echo -e "\n${BLUE}=== USER ACTIVITY ===${NC}"
printf "%-20s: %s\n" "Current User" "$(whoami)"
printf "%-20s: %s\n" "Login Time" "$(who am i 2>/dev/null | awk '{print $3, $4}' || echo 'Unknown')"

# Recent logins
echo -e "\n${YELLOW}Recent Logins:${NC}"
last -5 2>/dev/null | head -5 | while read line; do
    if [[ "$line" =~ ^[a-zA-Z] ]]; then
        echo "  $line"
    fi
done

log_success "System information collection completed"

# Performance metrics
echo -e "\n${BLUE}=== PERFORMANCE METRICS ===${NC}"
echo -e "\n${YELLOW}CPU Usage:${NC}"
if command -v top >/dev/null 2>&1; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    printf "%-20s: %s\n" "CPU Usage" "${cpu_usage}%"
fi

echo -e "\n${YELLOW}Top Processes by CPU:${NC}"
ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
    printf "  %s\n" "$(echo "$line" | awk '{printf "%-10s %5s%% %s", $1, $3, $11}')"
done

echo -e "\n${YELLOW}Top Processes by Memory:${NC}"
ps aux --sort=-%mem | head -6 | tail -5 | while read line; do
    printf "  %s\n" "$(echo "$line" | awk '{printf "%-10s %5s%% %s", $1, $4, $11}')"
done