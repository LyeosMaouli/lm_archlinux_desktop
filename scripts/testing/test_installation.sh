#!/bin/bash
# Installation Test Script for Arch Linux Hyprland Automation
# Validates that the base system installation completed successfully

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging
log_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name - $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test functions
test_arch_linux() {
    if [[ -f /etc/arch-release ]]; then
        log_test "Operating System" "PASS" "Arch Linux detected"
    else
        log_test "Operating System" "FAIL" "Not running on Arch Linux"
    fi
}

test_uefi_boot() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        log_test "Boot Mode" "PASS" "UEFI boot confirmed"
    else
        log_test "Boot Mode" "FAIL" "Not booted in UEFI mode"
    fi
}

test_systemd() {
    if systemctl --version >/dev/null 2>&1; then
        log_test "Init System" "PASS" "systemd is running"
    else
        log_test "Init System" "FAIL" "systemd not detected"
    fi
}

test_network() {
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_test "Network Connectivity" "PASS" "Internet connection available"
    else
        log_test "Network Connectivity" "FAIL" "No internet connection"
    fi
}

test_package_manager() {
    if command -v pacman >/dev/null 2>&1; then
        log_test "Package Manager" "PASS" "pacman available"
        
        # Test if pacman database is functional
        if pacman -Q linux >/dev/null 2>&1; then
            log_test "Package Database" "PASS" "pacman database functional"
        else
            log_test "Package Database" "FAIL" "pacman database issues"
        fi
    else
        log_test "Package Manager" "FAIL" "pacman not found"
    fi
}

test_essential_packages() {
    local essential_packages=("linux" "base" "systemd" "networkmanager")
    
    for package in "${essential_packages[@]}"; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            log_test "Essential Package: $package" "PASS" "Package installed"
        else
            log_test "Essential Package: $package" "FAIL" "Package missing"
        fi
    done
}

test_bootloader() {
    if command -v bootctl >/dev/null 2>&1; then
        log_test "Bootloader Binary" "PASS" "bootctl available"
        
        # Test if systemd-boot is installed
        if bootctl status >/dev/null 2>&1; then
            log_test "Bootloader Installation" "PASS" "systemd-boot installed"
        else
            log_test "Bootloader Installation" "FAIL" "systemd-boot not properly installed"
        fi
    else
        log_test "Bootloader Binary" "FAIL" "bootctl not found"
    fi
}

test_user_accounts() {
    # Check if the main user exists
    if id lyeosmaouli >/dev/null 2>&1; then
        log_test "Main User Account" "PASS" "User 'lyeosmaouli' exists"
        
        # Check if user has sudo access
        if groups lyeosmaouli | grep -q wheel; then
            log_test "User Sudo Access" "PASS" "User in wheel group"
        else
            log_test "User Sudo Access" "FAIL" "User not in wheel group"
        fi
    else
        log_test "Main User Account" "FAIL" "User 'lyeosmaouli' not found"
    fi
}

test_services() {
    local critical_services=("NetworkManager" "systemd-resolved")
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_test "Service: $service" "PASS" "Service active"
        elif systemctl is-enabled --quiet "$service"; then
            log_test "Service: $service" "PASS" "Service enabled (not running)"
        else
            log_test "Service: $service" "FAIL" "Service not enabled/active"
        fi
    done
}

test_filesystem() {
    # Check root filesystem
    if mount | grep -q "/ "; then
        local fs_type
        fs_type=$(mount | grep "/ " | awk '{print $5}')
        log_test "Root Filesystem" "PASS" "Root mounted ($fs_type)"
    else
        log_test "Root Filesystem" "FAIL" "Root filesystem issues"
    fi
    
    # Check EFI partition
    if mount | grep -q "/boot "; then
        log_test "EFI Partition" "PASS" "EFI partition mounted"
    else
        log_test "EFI Partition" "FAIL" "EFI partition not mounted"
    fi
}

test_time_sync() {
    if timedatectl status | grep -q "synchronized: yes\|NTP synchronized: yes"; then
        log_test "Time Synchronization" "PASS" "System time synchronized"
    else
        log_test "Time Synchronization" "FAIL" "Time not synchronized"
    fi
}

test_locale() {
    if locale | grep -q "LANG=en_US.UTF-8"; then
        log_test "System Locale" "PASS" "Locale set to en_US.UTF-8"
    else
        log_test "System Locale" "FAIL" "Incorrect locale configuration"
    fi
}

test_keyboard() {
    if [[ -f /etc/vconsole.conf ]] && grep -q "KEYMAP=fr" /etc/vconsole.conf; then
        log_test "Keyboard Layout" "PASS" "French keyboard layout configured"
    else
        log_test "Keyboard Layout" "FAIL" "Keyboard layout not configured"
    fi
}

# Main test runner
run_tests() {
    echo -e "${BLUE}Arch Linux Installation Validation Tests${NC}"
    echo "========================================"
    echo ""
    
    test_arch_linux
    test_uefi_boot
    test_systemd
    test_network
    test_package_manager
    test_essential_packages
    test_bootloader
    test_user_accounts
    test_services
    test_filesystem
    test_time_sync
    test_locale
    test_keyboard
    
    echo ""
    echo "========================================"
    echo -e "${BLUE}Test Results Summary${NC}"
    echo "========================================"
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ All tests passed! Installation appears successful.${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Some tests failed. Installation may have issues.${NC}"
        return 1
    fi
}

# Generate detailed report
generate_report() {
    local report_file="/tmp/installation_test_report.txt"
    
    cat > "$report_file" << EOF
Arch Linux Installation Test Report
===================================
Generated: $(date)
Hostname: $(hostnamectl --static)

SYSTEM INFORMATION
==================
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
Kernel: $(uname -r)
Architecture: $(uname -m)
Boot Mode: $(if [[ -d /sys/firmware/efi/efivars ]]; then echo "UEFI"; else echo "BIOS"; fi)

HARDWARE
========
CPU: $(lscpu | grep "Model name:" | sed 's/Model name:\s*//')
Memory: $(free -h | awk '/^Mem:/ {print $2}')
Disk: $(df -h / | tail -1 | awk '{print $2 " total, " $4 " available"}')

NETWORK
=======
Interfaces: $(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo | tr '\n' ' ')
DNS: $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ' ')

SERVICES
========
Active Services: $(systemctl list-units --type=service --state=active --no-pager --no-legend | wc -l)
Failed Services: $(systemctl list-units --type=service --state=failed --no-pager --no-legend | wc -l)

TEST RESULTS
============
Total Tests: $TESTS_TOTAL
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED

$(if [[ $TESTS_FAILED -eq 0 ]]; then echo "STATUS: INSTALLATION SUCCESSFUL"; else echo "STATUS: INSTALLATION ISSUES DETECTED"; fi)

RECOMMENDATIONS
===============
$(if [[ $TESTS_FAILED -gt 0 ]]; then
echo "- Review failed tests above"
echo "- Check system logs: journalctl -xb"
echo "- Verify configuration files"
echo "- Consider reinstallation if critical tests failed"
else
echo "- Installation completed successfully"
echo "- Ready for desktop environment deployment"
echo "- Consider running security tests next"
fi)

EOF
    
    echo "Detailed report saved to: $report_file"
}

# Main function
main() {
    local generate_report_flag=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--report)
                generate_report_flag=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -r, --report    Generate detailed report"
                echo "  -h, --help      Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if ! run_tests; then
        if [[ "$generate_report_flag" == true ]]; then
            generate_report
        fi
        exit 1
    fi
    
    if [[ "$generate_report_flag" == true ]]; then
        generate_report
    fi
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi