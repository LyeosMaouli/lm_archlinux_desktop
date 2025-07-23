#!/bin/bash
# Log Analysis Helper for Arch Installation Debugging
# Extracts and analyzes key information from installation logs

set -euo pipefail

# Colors for output (only set if not already defined)
if [[ -z "$RED" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Log file paths (only set if not already defined)
if [[ -z "$VERBOSE_LOG" ]]; then
    VERBOSE_LOG="/var/log/auto_install_verbose.log"
fi
if [[ -z "$VM_VERBOSE_LOG" ]]; then
    VM_VERBOSE_LOG="/var/log/auto_vm_test_verbose.log"
fi
if [[ -z "$STANDARD_LOG" ]]; then
    STANDARD_LOG="/var/log/auto_install.log"
fi

info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Find the most recent log file
find_log_file() {
    local log_file=""
    
    if [[ -f "$VERBOSE_LOG" ]]; then
        log_file="$VERBOSE_LOG"
    elif [[ -f "$VM_VERBOSE_LOG" ]]; then
        log_file="$VM_VERBOSE_LOG"
    elif [[ -f "$STANDARD_LOG" ]]; then
        log_file="$STANDARD_LOG"
    fi
    
    echo "$log_file"
}

# Extract error messages
extract_errors() {
    local log_file="$1"
    
    info "=== ERROR MESSAGES ==="
    grep -i "error\|fail\|timeout\|invalid\|corrupt" "$log_file" | tail -20 || echo "No error messages found"
    
    echo
    info "=== PACMAN SPECIFIC ERRORS ==="
    grep -A 5 -B 5 "pacman\|pacstrap" "$log_file" | grep -i "error\|fail\|invalid" | tail -10 || echo "No pacman errors found"
    
    echo
    info "=== KEYRING ISSUES ==="
    grep -A 3 -B 3 "keyring\|signature\|gpg" "$log_file" | tail -10 || echo "No keyring issues found"
    
    echo
    info "=== NETWORK/MIRROR ISSUES ==="
    grep -A 3 -B 3 "mirror\|download\|timeout\|connection" "$log_file" | tail -10 || echo "No network issues found"
}

# Extract system information
extract_system_info() {
    local log_file="$1"
    
    info "=== SYSTEM INFORMATION ==="
    grep -A 10 "System Information" "$log_file" || echo "No system info found"
    
    echo
    info "=== NETWORK CONFIGURATION ==="
    grep -A 10 "Network Interfaces\|DNS Configuration" "$log_file" || echo "No network info found"
    
    echo
    info "=== MIRROR CONFIGURATION ==="
    grep -A 20 "Mirror status downloaded\|Creating optimized mirror" "$log_file" || echo "No mirror info found"
}

# Show recent activity
show_recent_activity() {
    local log_file="$1"
    
    info "=== LAST 50 LOG ENTRIES ==="
    tail -50 "$log_file"
}

# Main analysis function
main() {
    local log_file
    log_file=$(find_log_file)
    
    if [[ -z "$log_file" ]]; then
        error "No log files found. Expected locations:"
        echo "  - $VERBOSE_LOG"
        echo "  - $VM_VERBOSE_LOG" 
        echo "  - $STANDARD_LOG"
        exit 1
    fi
    
    info "Analyzing log file: $log_file"
    echo "Log file size: $(du -h "$log_file" | cut -f1)"
    echo "Last modified: $(stat -c %y "$log_file" 2>/dev/null || stat -f %Sm "$log_file" 2>/dev/null || echo "unknown")"
    echo
    
    # Perform analysis
    extract_errors "$log_file"
    echo
    extract_system_info "$log_file"
    echo
    show_recent_activity "$log_file"
    
    echo
    info "=== LOG LOCATIONS ==="
    echo "Full verbose log: $log_file"
    echo "Standard log: $STANDARD_LOG (if exists)"
    echo
    info "To view full log: cat $log_file"
    info "To follow live: tail -f $log_file"
    info "To search for term: grep -i 'search_term' $log_file"
}

# Run main function
main "$@"