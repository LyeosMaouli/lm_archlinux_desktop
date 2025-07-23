#!/bin/bash
# System Health Check Script for Arch Linux Hyprland
# Comprehensive system health monitoring and reporting

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Configuration
REPORT_FILE="/tmp/health_check_report.txt"
WARNING_THRESHOLD_DISK=85
WARNING_THRESHOLD_MEMORY=80
WARNING_THRESHOLD_CPU=90

# Health check results and structured logging
WARNINGS=0
ERRORS=0
INFO_ITEMS=0
SUCCESS_ITEMS=0

# Structured logging for health checks
HEALTH_LOG_FORMAT="json"  # json, plain, structured
HEALTH_METRICS=()

# Create structured log entry
log_structured() {
    local level="$1"
    local component="$2"
    local message="$3"
    local value="${4:-}"
    local threshold="${5:-}"
    local timestamp=$(date -Iseconds)
    
    if [[ "$HEALTH_LOG_FORMAT" == "json" ]]; then
        local json_entry
        json_entry=$(cat << EOF
{
  "timestamp": "$timestamp",
  "level": "$level", 
  "component": "$component",
  "message": "$message",
  "value": "$value",
  "threshold": "$threshold",
  "hostname": "$(hostname)",
  "check_id": "$(echo -n "${component}_${message}" | sha256sum | cut -c1-8)"
}
EOF
        )
        echo "$json_entry" >> "$LOG_FILE.structured"
    fi
    
    # Also log to regular file
    log_to_file "[$level] $component: $message${value:+ (value: $value)}${threshold:+ (threshold: $threshold)}"
}

# Add metric for monitoring
add_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local metric_unit="${3:-}"
    local metric_labels="${4:-}"
    
    HEALTH_METRICS+=("$metric_name:$metric_value:$metric_unit:$metric_labels")
    
    # Log metric in Prometheus format
    local prometheus_line="health_check_${metric_name}"
    if [[ -n "$metric_labels" ]]; then
        prometheus_line+="{$metric_labels}"
    fi
    prometheus_line+=" $metric_value"
    echo "$prometheus_line" >> "$LOG_FILE.metrics"
}

info_health() {
    local component="${2:-general}"
    log_info "ℹ $1"
    log_structured "INFO" "$component" "$1"
    INFO_ITEMS=$((INFO_ITEMS + 1))
}

warn_health() {
    local component="${2:-general}"
    log_warn "⚠ $1"
    log_structured "WARNING" "$component" "$1"
    WARNINGS=$((WARNINGS + 1))
}

error_health() {
    local component="${2:-general}"
    log_error "❌ $1"
    log_structured "ERROR" "$component" "$1"
    ERRORS=$((ERRORS + 1))
}

success_health() {
    local component="${2:-general}"
    log_success "✅ $1"
    log_structured "SUCCESS" "$component" "$1"
    SUCCESS_ITEMS=$((SUCCESS_ITEMS + 1))
}

# Performance monitoring functions
measure_performance() {
    local operation="$1"
    local start_time=$(date +%s.%N)
    
    shift
    "$@"
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    add_metric "operation_duration_seconds" "$duration" "seconds" "operation=\"$operation\""
    log_structured "PERFORMANCE" "timing" "Operation $operation completed" "$duration" ""
    
    return $exit_code
}

# Advanced monitoring checks
check_monitoring_health() {
    info_health "Checking monitoring infrastructure..." "monitoring"
    
    # Check if monitoring agents are running
    local monitoring_services=("node_exporter" "prometheus" "grafana-server")
    
    for service in "${monitoring_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            success_health "Monitoring service $service is running" "monitoring"
            add_metric "service_status" "1" "" "service=\"$service\""
        else
            info_health "Monitoring service $service not running (optional)" "monitoring"
            add_metric "service_status" "0" "" "service=\"$service\""
        fi
    done
    
    # Check log rotation
    local log_files_count=$(find /var/log -name "*.log" -type f | wc -l)
    add_metric "log_files_count" "$log_files_count" "files" ""
    
    if [[ $log_files_count -gt 1000 ]]; then
        warn_health "Large number of log files: $log_files_count" "monitoring"
    else
        success_health "Log file count normal: $log_files_count" "monitoring"
    fi
    
    # Check for large log files
    local large_logs
    large_logs=$(find /var/log -name "*.log" -size +100M 2>/dev/null | wc -l)
    add_metric "large_log_files_count" "$large_logs" "files" ""
    
    if [[ $large_logs -gt 0 ]]; then
        warn_health "$large_logs log files larger than 100MB" "monitoring"
    else
        success_health "No oversized log files detected" "monitoring"
    fi
}

# Container and virtualization checks
check_container_health() {
    info_health "Checking container and virtualization..." "containers"
    
    # Check if running in container
    if [[ -f /.dockerenv ]]; then
        info_health "Running in Docker container" "containers"
        add_metric "container_type" "1" "" "type=\"docker\""
    elif [[ -n "${container:-}" ]]; then
        info_health "Running in container: $container" "containers"
        add_metric "container_type" "1" "" "type=\"$container\""
    else
        add_metric "container_type" "0" "" "type=\"none\""
    fi
    
    # Check Docker if available
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            local running_containers
            running_containers=$(docker ps -q | wc -l)
            success_health "Docker daemon accessible" "containers"
            add_metric "docker_containers_running" "$running_containers" "containers" ""
            
            if [[ $running_containers -gt 0 ]]; then
                info_health "$running_containers Docker containers running" "containers"
            fi
        else
            warn_health "Docker daemon not accessible" "containers"
            add_metric "docker_accessible" "0" "" ""
        fi
    fi
    
    # Check systemd-nspawn containers
    if command -v machinectl >/dev/null 2>&1; then
        local machines
        machines=$(machinectl list --no-legend 2>/dev/null | wc -l)
        add_metric "systemd_machines_count" "$machines" "machines" ""
        
        if [[ $machines -gt 0 ]]; then
            info_health "$machines systemd machines detected" "containers"
        fi
    fi
}

# Check system uptime and load
check_system_load() {
    info_health "Checking system load and uptime..." "system"
    
    local uptime_info
    uptime_info=$(uptime)
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_cores
    cpu_cores=$(nproc)
    
    # Add metrics
    add_metric "load_average_1min" "$load_avg" "" ""
    add_metric "cpu_cores_total" "$cpu_cores" "cores" ""
    
    # Get uptime in seconds
    local uptime_seconds
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    add_metric "uptime_seconds" "$uptime_seconds" "seconds" ""
    
    info_health "System uptime: $(uptime -p)" "system"
    info_health "Load average (1min): $load_avg (cores: $cpu_cores)" "system"
    
    # Check if load is high
    local load_ratio
    load_ratio=$(echo "scale=2; $load_avg / $cpu_cores" | bc -l)
    add_metric "load_ratio" "$load_ratio" "" ""
    
    if (( $(echo "$load_avg > $cpu_cores" | bc -l) )); then
        warn_health "High system load: $load_avg (cores: $cpu_cores)" "system"
    else
        success_health "System load normal: $load_avg" "system"
    fi
}

# Check memory usage
check_memory() {
    info_health "Checking memory usage..."
    
    local mem_info
    mem_info=$(free -m)
    local total_mem
    total_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')
    local used_mem
    used_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
    local available_mem
    available_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $7}')
    
    local mem_usage_percent
    mem_usage_percent=$(( (used_mem * 100) / total_mem ))
    
    info_health "Memory usage: ${used_mem}MB / ${total_mem}MB (${mem_usage_percent}%)"
    info_health "Available memory: ${available_mem}MB"
    
    if [[ $mem_usage_percent -gt $WARNING_THRESHOLD_MEMORY ]]; then
        warn_health "High memory usage: ${mem_usage_percent}%"
    else
        success_health "Memory usage normal: ${mem_usage_percent}%"
    fi
    
    # Check swap usage
    local swap_used
    swap_used=$(echo "$mem_info" | awk '/^Swap:/ {print $3}')
    local swap_total
    swap_total=$(echo "$mem_info" | awk '/^Swap:/ {print $2}')
    
    if [[ $swap_total -gt 0 ]]; then
        local swap_percent
        swap_percent=$(( (swap_used * 100) / swap_total ))
        info_health "Swap usage: ${swap_used}MB / ${swap_total}MB (${swap_percent}%)"
        
        if [[ $swap_percent -gt 50 ]]; then
            warn_health "High swap usage: ${swap_percent}%"
        fi
    else
        info_health "No swap configured"
    fi
}

# Check disk usage
check_disk_usage() {
    info_health "Checking disk usage..."
    
    # Check all mounted filesystems
    while read -r filesystem size used avail percent mount; do
        # Skip special filesystems
        if [[ "$filesystem" =~ ^(tmpfs|devtmpfs|proc|sys|run) ]]; then
            continue
        fi
        
        local usage_num
        usage_num=$(echo "$percent" | tr -d '%')
        
        info_health "Filesystem $mount: $used / $size ($percent)"
        
        if [[ $usage_num -gt $WARNING_THRESHOLD_DISK ]]; then
            warn_health "High disk usage on $mount: $percent"
        elif [[ $usage_num -gt 95 ]]; then
            error_health "Critical disk usage on $mount: $percent"
        else
            success_health "Disk usage normal on $mount: $percent"
        fi
    done < <(df -h | tail -n +2)
    
    # Check inode usage
    info_health "Checking inode usage..."
    while read -r filesystem inodes used avail percent mount; do
        if [[ "$filesystem" =~ ^(tmpfs|devtmpfs|proc|sys|run) ]]; then
            continue
        fi
        
        if [[ "$percent" != "-" ]]; then
            local inode_usage
            inode_usage=$(echo "$percent" | tr -d '%')
            if [[ $inode_usage -gt 80 ]]; then
                warn_health "High inode usage on $mount: $percent"
            fi
        fi
    done < <(df -i | tail -n +2)
}

# Check system services
check_services() {
    info_health "Checking critical system services..."
    
    local critical_services=("NetworkManager" "sshd" "systemd-resolved" "systemd-timesyncd")
    
    # Add desktop services if they exist
    if systemctl list-unit-files | grep -q sddm; then
        critical_services+=("sddm")
    fi
    
    if systemctl list-unit-files | grep -q tlp; then
        critical_services+=("tlp")
    fi
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success_health "Service $service is running"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            warn_health "Service $service is enabled but not running"
        else
            if systemctl list-unit-files | grep -q "^$service"; then
                warn_health "Service $service is not enabled"
            else
                info_health "Service $service not installed (optional)"
            fi
        fi
    done
    
    # Check for failed services
    local failed_services
    failed_services=$(systemctl --failed --no-legend --no-pager | wc -l)
    
    if [[ $failed_services -gt 0 ]]; then
        error_health "$failed_services failed service(s) detected"
        systemctl --failed --no-pager | while read -r service; do
            warn_health "Failed service: $service"
        done
    else
        success_health "No failed services detected"
    fi
}

# Check network connectivity
check_network() {
    info_health "Checking network connectivity..."
    
    # Check network interfaces
    local interfaces
    interfaces=$(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo)
    
    info_health "Network interfaces:"
    echo "$interfaces" | while read -r interface; do
        if ip link show "$interface" | grep -q "state UP"; then
            success_health "Interface $interface is UP"
        else
            warn_health "Interface $interface is DOWN"
        fi
    done
    
    # Check internet connectivity
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        success_health "Internet connectivity (8.8.8.8)"
    else
        error_health "No internet connectivity"
    fi
    
    if ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        success_health "DNS resolution working (archlinux.org)"
    else
        warn_health "DNS resolution issues"
    fi
    
    # Check listening ports
    local listening_ports
    listening_ports=$(ss -tuln | grep LISTEN | wc -l)
    info_health "Listening network ports: $listening_ports"
}

# Check security status
check_security() {
    info_health "Checking security status..."
    
    # Check firewall status
    if command -v ufw >/dev/null; then
        if ufw status | grep -q "Status: active"; then
            success_health "UFW firewall is active"
        else
            warn_health "UFW firewall is inactive"
        fi
    else
        info_health "UFW not installed"
    fi
    
    # Check fail2ban status
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        success_health "Fail2ban is running"
    else
        info_health "Fail2ban not running or not installed"
    fi
    
    # Check SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            success_health "SSH root login disabled"
        else
            warn_health "SSH root login may be enabled"
        fi
        
        if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
            success_health "SSH password authentication disabled"
        else
            info_health "SSH password authentication enabled"
        fi
    fi
    
    # Check for world-writable files
    info_health "Checking for security issues..."
    local world_writable
    world_writable=$(find /etc /usr/local -type f -perm -002 2>/dev/null | wc -l)
    if [[ $world_writable -gt 0 ]]; then
        warn_health "$world_writable world-writable files found in system directories"
    else
        success_health "No world-writable files in system directories"
    fi
}

# Check system logs for errors
check_logs() {
    info_health "Checking system logs for recent errors..."
    
    # Check journalctl for errors in the last 24 hours
    local error_count
    error_count=$(journalctl --since "24 hours ago" --priority=err --no-pager | wc -l)
    
    if [[ $error_count -gt 0 ]]; then
        warn_health "$error_count error_health entries in logs (last 24h)"
        
        # Show recent critical errors
        info_health "Recent critical errors:"
        journalctl --since "24 hours ago" --priority=crit --no-pager | tail -5 | while read -r line; do
            warn_health "Log: $line"
        done
    else
        success_health "No critical errors in recent logs"
    fi
    
    # Check dmesg for hardware issues
    local dmesg_errors
    dmesg_errors=$(dmesg | grep -i "error\|fail\|panic" | wc -l)
    
    if [[ $dmesg_errors -gt 0 ]]; then
        warn_health "$dmesg_errors potential hardware issues in dmesg"
    else
        success_health "No hardware errors in dmesg"
    fi
}

# Check package system
check_packages() {
    info_health "Checking package system..."
    
    # Check for partial upgrades
    if command -v pacman >/dev/null; then
        local available_updates
        available_updates=$(pacman -Qu 2>/dev/null | wc -l)
        
        if [[ $available_updates -gt 0 ]]; then
            info_health "$available_updates package updates available"
        else
            success_health "System packages are up to date"
        fi
        
        # Check for orphaned packages
        local orphans
        orphans=$(pacman -Qtdq 2>/dev/null | wc -l)
        
        if [[ $orphans -gt 0 ]]; then
            info_health "$orphans orphaned packages found"
        else
            success_health "No orphaned packages"
        fi
        
        # Check pacman database
        if pacman -Q linux >/dev/null 2>&1; then
            success_health "Package database functional"
        else
            error_health "Package database issues detected"
        fi
    fi
}

# Check hardware health
check_hardware() {
    info_health "Checking hardware health..."
    
    # Check CPU temperature if sensors available
    if command -v sensors >/dev/null; then
        local cpu_temp
        cpu_temp=$(sensors | grep -E "(Core|Package)" | head -1 | awk '{print $3}' | tr -d '+°C' || echo "0")
        
        if [[ -n "${cpu_temp:-}" ]] && [[ "$cpu_temp" != "0" ]]; then
            info_health "CPU temperature: ${cpu_temp}°C"
            
            if (( $(echo "$cpu_temp > 80" | bc -l) )); then
                warn_health "High CPU temperature: ${cpu_temp}°C"
            elif (( $(echo "$cpu_temp > 90" | bc -l) )); then
                error_health "Critical CPU temperature: ${cpu_temp}°C"
            else
                success_health "CPU temperature normal: ${cpu_temp}°C"
            fi
        fi
    else
        info_health "Temperature sensors not available (install lm_sensors)"
    fi
    
    # Check SMART status for disks
    if command -v smartctl >/dev/null; then
        for disk in /dev/sd? /dev/nvme?n?; do
            if [[ -b "$disk" ]]; then
                local smart_status
                smart_status=$(smartctl -H "$disk" 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}' || echo "UNKNOWN")
                
                if [[ "$smart_status" == "PASSED" ]]; then
                    success_health "SMART status for $disk: PASSED"
                elif [[ "$smart_status" == "FAILED" ]]; then
                    error_health "SMART status for $disk: FAILED"
                else
                    info_health "SMART status for $disk: $smart_status"
                fi
            fi
        done
    else
        info_health "SMART monitoring not available (install smartmontools)"
    fi
}

# Generate comprehensive report
generate_report() {
    info_health "Generating health check report..."
    
    cat > "$REPORT_FILE" << EOF
System Health Check Report
=========================
Generated: $(date)
Hostname: $(hostnamectl --static)

SUMMARY
=======
Total Checks: $((INFO_ITEMS + WARNINGS + ERRORS))
Warnings: $WARNINGS
Errors: $ERRORS
Overall Status: $(if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then echo "HEALTHY"; elif [[ $ERRORS -eq 0 ]]; then echo "MINOR ISSUES"; else echo "ISSUES DETECTED"; fi)

SYSTEM INFORMATION
==================
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
Kernel: $(uname -r)
Uptime: $(uptime -p)
Load Average: $(uptime | awk -F'load average:' '{print $2}')

RESOURCE USAGE
==============
$(free -h)

DISK USAGE
==========
$(df -h | grep -v tmpfs)

ACTIVE SERVICES
===============
$(systemctl list-units --type=service --state=active --no-pager --no-legend | wc -l) active services

FAILED SERVICES
===============
$(systemctl --failed --no-pager --no-legend || echo "None")

NETWORK STATUS
==============
$(ip addr show | grep -E "(inet |state )" | head -10)

RECENT LOG ERRORS
=================
$(journalctl --since "24 hours ago" --priority=err --no-pager | tail -10 || echo "None")

RECOMMENDATIONS
===============
$(if [[ $ERRORS -gt 0 ]]; then
echo "- CRITICAL: Address error_health conditions immediately"
echo "- Review system logs: journalctl -xb"
echo "- Check hardware status"
fi)

$(if [[ $WARNINGS -gt 0 ]]; then
echo "- WARNING: Review warning conditions"
echo "- Consider system maintenance"
echo "- Monitor resource usage"
fi)

$(if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
echo "- System appears healthy"
echo "- Continue regular monitoring"
echo "- Consider running updates: pacman -Syu"
fi)

EOF
    
    success_health "Health check report generated: $REPORT_FILE"
}

# Main health check function
run_health_check() {
    local start_time=$(date +%s)
    
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC}               ${GREEN}Arch Linux System Health Check${NC}               ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Initialize structured logging files
    echo "# Health Check Structured Log - $(date)" > "$LOG_FILE.structured"
    echo "# Health Check Metrics - $(date)" > "$LOG_FILE.metrics"
    
    # Run checks with performance measurement
    measure_performance "system_load" check_system_load
    echo ""
    
    measure_performance "memory_check" check_memory
    echo ""
    
    measure_performance "disk_check" check_disk_usage
    echo ""
    
    measure_performance "services_check" check_services
    echo ""
    
    measure_performance "network_check" check_network
    echo ""
    
    measure_performance "security_check" check_security
    echo ""
    
    measure_performance "logs_check" check_logs
    echo ""
    
    measure_performance "packages_check" check_packages
    echo ""
    
    measure_performance "hardware_check" check_hardware
    echo ""
    
    measure_performance "monitoring_check" check_monitoring_health
    echo ""
    
    measure_performance "container_check" check_container_health
    echo ""
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    add_metric "health_check_duration_total" "$total_duration" "seconds" ""
    
    # Enhanced Summary
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC}                    ${YELLOW}Health Check Summary${NC}                    ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local total_checks=$((INFO_ITEMS + SUCCESS_ITEMS + WARNINGS + ERRORS))
    echo -e "${BOLD}Total Checks:${NC}   $total_checks"
    echo -e "${GREEN}${BOLD}Success:${NC}        $SUCCESS_ITEMS"
    echo -e "${BLUE}${BOLD}Info:${NC}           $INFO_ITEMS"
    echo -e "${YELLOW}${BOLD}Warnings:${NC}       $WARNINGS"
    echo -e "${RED}${BOLD}Errors:${NC}         $ERRORS"
    echo -e "${BOLD}Duration:${NC}       ${total_duration}s"
    echo ""
    
    # Add final metrics
    add_metric "health_check_total" "$total_checks" "checks" ""
    add_metric "health_check_success" "$SUCCESS_ITEMS" "checks" ""
    add_metric "health_check_warnings" "$WARNINGS" "checks" ""
    add_metric "health_check_errors" "$ERRORS" "checks" ""
    
    # Overall status determination
    local overall_status
    local exit_code
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        overall_status="HEALTHY"
        exit_code=0
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║${NC}                    ${GREEN}✅ SYSTEM HEALTHY${NC}                     ${GREEN}${BOLD}║${NC}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    elif [[ $ERRORS -eq 0 ]]; then
        overall_status="MINOR_ISSUES"
        exit_code=1
        echo -e "${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}${BOLD}║${NC}                   ${YELLOW}⚠ MINOR ISSUES DETECTED${NC}               ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}Review warning conditions above${NC}"
    else
        overall_status="CRITICAL_ISSUES"
        exit_code=2
        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║${NC}                 ${RED}❌ CRITICAL ISSUES DETECTED${NC}              ${RED}${BOLD}║${NC}"
        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${RED}${BOLD}Immediate attention required!${NC}"
    fi
    
    add_metric "health_check_status" "$exit_code" "" "status=\"$overall_status\""
    
    echo ""
    echo -e "${BOLD}Log Files:${NC}"
    echo -e "  Standard:   ${BLUE}$LOG_FILE${NC}"
    echo -e "  Structured: ${BLUE}$LOG_FILE.structured${NC}"
    echo -e "  Metrics:    ${BLUE}$LOG_FILE.metrics${NC}"
    
    return $exit_code
}

# Main function
main() {
    local generate_report_flag=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--report)
                generate_report_flag=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -r, --report    Generate detailed report"
                echo "  -v, --verbose   Verbose output"
                echo "  -h, --help      Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    local exit_code
    run_health_check
    exit_code=$?
    
    if [[ "$generate_report_flag" == true ]]; then
        generate_report
        echo "View full report: cat $REPORT_FILE"
    fi
    
    exit $exit_code
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi