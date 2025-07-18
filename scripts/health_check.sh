#!/bin/bash
# scripts/health_check.sh - System health monitoring

# System metrics
check_system_health() {
    echo "=== System Health Check ==="
    
    # CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "CPU Usage: $cpu_usage%"
    
    # Memory usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "Memory Usage: $memory_usage%"
    
    # Disk usage
    disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    echo "Disk Usage: $disk_usage"
    
    # Load average
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo "Load Average: $load_avg"
    
    # Temperature
    if command -v sensors &> /dev/null; then
        temp=$(sensors | grep -i "core 0" | awk '{print $3}')
        echo "Temperature: $temp"
    fi
}

# Service status
check_services() {
    echo "=== Service Status ==="
    
    local services=(
        "NetworkManager"
        "sddm"
        "systemd-timesyncd"
        "auditd"
        "nftables"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "✓ $service: active"
        else
            echo "✗ $service: inactive"
        fi
    done
}

# Desktop environment check
check_desktop() {
    echo "=== Desktop Environment ==="
    
    if pgrep -x "Hyprland" > /dev/null; then
        echo "✓ Hyprland: running"
    else
        echo "✗ Hyprland: not running"
    fi
    
    if pgrep -x "waybar" > /dev/null; then
        echo "✓ Waybar: running"
    else
        echo "✗ Waybar: not running"
    fi
    
    if pgrep -x "pipewire" > /dev/null; then
        echo "✓ Pipewire: running"
    else
        echo "✗ Pipewire: not running"
    fi
}

# Security status
check_security() {
    echo "=== Security Status ==="
    
    # Firewall status
    if systemctl is-active --quiet nftables; then
        echo "✓ Firewall: active"
    else
        echo "✗ Firewall: inactive"
    fi
    
    # Encryption status
    if cryptsetup status root > /dev/null 2>&1; then
        echo "✓ Disk encryption: active"
    else
        echo "✗ Disk encryption: inactive"
    fi
    
    # TPM status
    if [ -c /dev/tpm0 ]; then
        echo "✓ TPM: available"
    else
        echo "✗ TPM: not available"
    fi
}

# Main execution
main() {
    echo "Health check started: $(date)"
    echo "Host: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    check_system_health
    echo ""
    check_services
    echo ""
    check_desktop
    echo ""
    check_security
    echo ""
    
    echo "Health check completed: $(date)"
}

main "$@"