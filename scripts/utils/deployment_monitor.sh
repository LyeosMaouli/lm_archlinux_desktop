#!/bin/bash
#
# deployment_monitor.sh - Deployment monitoring and metrics collection
#
# This script provides real-time monitoring of deployment operations,
# collecting metrics and generating alerts for the deployment process.
#

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Configuration
MONITOR_LOG_FILE="$LOG_DIR/deployment-monitor.log"
METRICS_FILE="$LOG_DIR/deployment-metrics.prom"
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_DISK=85
ALERT_THRESHOLD_LOAD=4.0
MONITOR_INTERVAL=5

# Monitoring state
MONITORING_PID=""
START_TIME=""
DEPLOYMENT_PHASE=""

#
# Monitoring Functions
#

# Initialize monitoring
init_monitoring() {
    log_info "Initializing deployment monitoring..."
    
    START_TIME=$(date +%s)
    DEPLOYMENT_PHASE="initialization"
    
    # Create monitoring log header
    cat > "$MONITOR_LOG_FILE" << EOF
# Deployment Monitoring Log
# Started: $(date)
# PID: $$
EOF
    
    # Create metrics file header
    cat > "$METRICS_FILE" << EOF
# Deployment Metrics (Prometheus format)
# Generated: $(date)
# HELP deployment_duration_seconds Duration of deployment phases
# TYPE deployment_duration_seconds gauge
# HELP deployment_memory_usage_percent Memory usage during deployment
# TYPE deployment_memory_usage_percent gauge
# HELP deployment_disk_usage_percent Disk usage during deployment
# TYPE deployment_disk_usage_percent gauge
# HELP deployment_load_average System load average during deployment
# TYPE deployment_load_average gauge
EOF
}

# Collect system metrics
collect_metrics() {
    local timestamp=$(date +%s)
    local phase="$1"
    
    # Memory metrics
    local mem_info
    mem_info=$(free -m)
    local total_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')
    local used_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
    local mem_percent=$(( (used_mem * 100) / total_mem ))
    
    # Disk metrics
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    
    # Load metrics
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    
    # CPU metrics
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d' ' -f1)
    
    # Network metrics
    local network_rx network_tx
    network_rx=$(cat /proc/net/dev | grep -E "(eth0|ens|enp|wlan)" | head -1 | awk '{print $2}' || echo "0")
    network_tx=$(cat /proc/net/dev | grep -E "(eth0|ens|enp|wlan)" | head -1 | awk '{print $10}' || echo "0")
    
    # Process metrics
    local ansible_processes
    ansible_processes=$(pgrep -c ansible || echo "0")
    
    # Write metrics to file
    cat >> "$METRICS_FILE" << EOF
deployment_memory_usage_percent{phase="$phase"} $mem_percent $timestamp
deployment_disk_usage_percent{phase="$phase"} $disk_usage $timestamp
deployment_load_average{phase="$phase"} $load_avg $timestamp
deployment_cpu_usage_percent{phase="$phase"} ${cpu_usage:-0} $timestamp
deployment_network_rx_bytes{phase="$phase"} $network_rx $timestamp
deployment_network_tx_bytes{phase="$phase"} $network_tx $timestamp
deployment_ansible_processes{phase="$phase"} $ansible_processes $timestamp
EOF
    
    # Log to monitoring file
    echo "$(date -Iseconds) [$phase] MEM:${mem_percent}% DISK:${disk_usage}% LOAD:$load_avg CPU:${cpu_usage:-0}%" >> "$MONITOR_LOG_FILE"
    
    # Check thresholds and generate alerts
    check_thresholds "$phase" "$mem_percent" "$disk_usage" "$load_avg"
}

# Check alert thresholds
check_thresholds() {
    local phase="$1"
    local mem_percent="$2"
    local disk_usage="$3"
    local load_avg="$4"
    
    # Memory threshold
    if [[ $mem_percent -gt $ALERT_THRESHOLD_MEMORY ]]; then
        send_alert "HIGH_MEMORY" "Memory usage $mem_percent% exceeds threshold $ALERT_THRESHOLD_MEMORY% during $phase"
    fi
    
    # Disk threshold
    if [[ $disk_usage -gt $ALERT_THRESHOLD_DISK ]]; then
        send_alert "HIGH_DISK" "Disk usage $disk_usage% exceeds threshold $ALERT_THRESHOLD_DISK% during $phase"
    fi
    
    # Load threshold
    if (( $(echo "$load_avg > $ALERT_THRESHOLD_LOAD" | bc -l) )); then
        send_alert "HIGH_LOAD" "Load average $load_avg exceeds threshold $ALERT_THRESHOLD_LOAD during $phase"
    fi
}

# Send alert
send_alert() {
    local alert_type="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    log_warn "ALERT [$alert_type]: $message"
    
    # Write alert to monitoring log
    echo "$timestamp [ALERT] $alert_type: $message" >> "$MONITOR_LOG_FILE"
    
    # Write alert metric
    echo "deployment_alert{type=\"$alert_type\",phase=\"$DEPLOYMENT_PHASE\"} 1 $(date +%s)" >> "$METRICS_FILE"
    
    # Optional: Send to external monitoring system
    # if command -v curl >/dev/null 2>&1 && [[ -n "${WEBHOOK_URL:-}" ]]; then
    #     curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" \
    #          -d "{\"alert\":\"$alert_type\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" >/dev/null 2>&1 || true
    # fi
}

# Start background monitoring
start_monitoring() {
    local phase="$1"
    
    if [[ -n "$MONITORING_PID" ]] && kill -0 "$MONITORING_PID" 2>/dev/null; then
        log_debug "Monitoring already running (PID: $MONITORING_PID)"
        return 0
    fi
    
    log_info "Starting deployment monitoring for phase: $phase"
    DEPLOYMENT_PHASE="$phase"
    
    # Start monitoring in background
    (
        while true; do
            collect_metrics "$phase"
            sleep "$MONITOR_INTERVAL"
        done
    ) &
    
    MONITORING_PID=$!
    log_debug "Started monitoring process (PID: $MONITORING_PID)"
}

# Stop monitoring
stop_monitoring() {
    if [[ -n "$MONITORING_PID" ]] && kill -0 "$MONITORING_PID" 2>/dev/null; then
        log_info "Stopping deployment monitoring (PID: $MONITORING_PID)"
        kill "$MONITORING_PID" 2>/dev/null || true
        wait "$MONITORING_PID" 2>/dev/null || true
        MONITORING_PID=""
    fi
}

# Update deployment phase
update_phase() {
    local new_phase="$1"
    
    log_info "Deployment phase changed: $DEPLOYMENT_PHASE -> $new_phase"
    DEPLOYMENT_PHASE="$new_phase"
    
    # Record phase change
    local timestamp=$(date +%s)
    echo "deployment_phase_change{from=\"$DEPLOYMENT_PHASE\",to=\"$new_phase\"} 1 $timestamp" >> "$METRICS_FILE"
}

# Generate monitoring report
generate_monitoring_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    log_info "Generating deployment monitoring report..."
    
    local report_file="$LOG_DIR/deployment-monitoring-report.txt"
    
    cat > "$report_file" << EOF
Deployment Monitoring Report
===========================
Generated: $(date)
Duration: ${duration}s

SUMMARY
=======
Start Time: $(date -d "@$START_TIME")
End Time: $(date)
Total Duration: ${duration} seconds
Final Phase: $DEPLOYMENT_PHASE

METRICS COLLECTED
================
$(wc -l < "$METRICS_FILE") metrics collected
Monitoring log: $MONITOR_LOG_FILE
Metrics file: $METRICS_FILE

ALERTS GENERATED
===============
$(grep -c "\[ALERT\]" "$MONITOR_LOG_FILE" 2>/dev/null || echo "0") alerts generated

$(if [[ -f "$MONITOR_LOG_FILE" ]]; then
    echo "Alert Summary:"
    grep "\[ALERT\]" "$MONITOR_LOG_FILE" 2>/dev/null | awk -F'ALERT] ' '{print "- " $2}' || echo "No alerts"
fi)

RESOURCE USAGE SUMMARY
=====================
Peak Memory Usage: $(awk '/deployment_memory_usage_percent/ {if($2>max) max=$2} END {print max "%"}' "$METRICS_FILE" 2>/dev/null || echo "Unknown")
Peak Disk Usage: $(awk '/deployment_disk_usage_percent/ {if($2>max) max=$2} END {print max "%"}' "$METRICS_FILE" 2>/dev/null || echo "Unknown")
Peak Load Average: $(awk '/deployment_load_average/ {if($2>max) max=$2} END {print max}' "$METRICS_FILE" 2>/dev/null || echo "Unknown")

RECOMMENDATIONS
==============
$(if grep -q "HIGH_MEMORY" "$MONITOR_LOG_FILE" 2>/dev/null; then
    echo "- Consider increasing available memory or reducing parallel operations"
fi)
$(if grep -q "HIGH_DISK" "$MONITOR_LOG_FILE" 2>/dev/null; then
    echo "- Free up disk space before future deployments"
fi)
$(if grep -q "HIGH_LOAD" "$MONITOR_LOG_FILE" 2>/dev/null; then
    echo "- Consider reducing parallel jobs or scheduling during off-peak hours"
fi)

EOF
    
    log_success "Monitoring report generated: $report_file"
    echo "$report_file"
}

# Cleanup function
cleanup_monitoring() {
    stop_monitoring
    
    if [[ -n "$START_TIME" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - START_TIME))
        echo "deployment_duration_seconds{phase=\"total\"} $duration $(date +%s)" >> "$METRICS_FILE"
    fi
    
    log_debug "Monitoring cleanup completed"
}

# Signal handlers
trap cleanup_monitoring EXIT
trap 'stop_monitoring; exit 130' INT TERM

#
# CLI Interface
#

show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
  start PHASE     Start monitoring for deployment phase
  stop            Stop monitoring
  phase PHASE     Update current deployment phase
  report          Generate monitoring report
  status          Show monitoring status
  metrics         Show current metrics
  help            Show this help

OPTIONS:
  --interval SEC  Monitoring interval in seconds (default: $MONITOR_INTERVAL)
  --memory-alert  Memory alert threshold percent (default: $ALERT_THRESHOLD_MEMORY)
  --disk-alert    Disk alert threshold percent (default: $ALERT_THRESHOLD_DISK)
  --load-alert    Load alert threshold (default: $ALERT_THRESHOLD_LOAD)

EXAMPLES:
  $0 start install           # Start monitoring for install phase
  $0 phase desktop           # Update to desktop phase
  $0 stop                    # Stop monitoring
  $0 report                  # Generate final report

EOF
}

main() {
    local command=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|phase|report|status|metrics|help)
                command="$1"
                shift
                break
                ;;
            --interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            --memory-alert)
                ALERT_THRESHOLD_MEMORY="$2"
                shift 2
                ;;
            --disk-alert)
                ALERT_THRESHOLD_DISK="$2"
                shift 2
                ;;
            --load-alert)
                ALERT_THRESHOLD_LOAD="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize monitoring if needed
    if [[ ! -f "$MONITOR_LOG_FILE" ]] && [[ "$command" != "help" ]]; then
        init_monitoring
    fi
    
    # Execute command
    case "$command" in
        start)
            local phase="${1:-deployment}"
            start_monitoring "$phase"
            ;;
        stop)
            stop_monitoring
            ;;
        phase)
            local phase="${1:-unknown}"
            update_phase "$phase"
            ;;
        report)
            local report_file
            report_file=$(generate_monitoring_report)
            cat "$report_file"
            ;;
        status)
            if [[ -n "$MONITORING_PID" ]] && kill -0 "$MONITORING_PID" 2>/dev/null; then
                echo "Monitoring: ACTIVE (PID: $MONITORING_PID)"
                echo "Phase: $DEPLOYMENT_PHASE"
                echo "Duration: $(($(date +%s) - START_TIME))s"
            else
                echo "Monitoring: INACTIVE"
            fi
            ;;
        metrics)
            if [[ -f "$METRICS_FILE" ]]; then
                echo "Current Metrics:"
                tail -20 "$METRICS_FILE"
            else
                echo "No metrics available"
            fi
            ;;
        help|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi