#!/bin/bash
# Hardware Validation Script for Arch Linux Hyprland Automation
# Validates system hardware compatibility and requirements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/var/log/hardware_validation.log"
REPORT_FILE="/tmp/hardware_validation_report.txt"

# Minimum requirements
MIN_RAM_GB=4
MIN_STORAGE_GB=20
MIN_CPU_CORES=2

# Hardware compatibility flags
SUPPORTS_UEFI=false
SUPPORTS_ENCRYPTION=false
HAS_WIFI=false
HAS_BLUETOOTH=false
HAS_INTEL_GPU=false
HAS_NVIDIA_GPU=false
HAS_AMD_GPU=false
IS_LAPTOP=false

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[FAIL] FAIL: $1${NC}"
    log "FAIL: $1"
}

warn() {
    echo -e "${YELLOW}⚠ WARN: $1${NC}"
    log "WARN: $1"
}

success() {
    echo -e "${GREEN}[OK] PASS: $1${NC}"
    log "PASS: $1"
}

info() {
    echo -e "${CYAN}ℹ INFO: $1${NC}"
    log "INFO: $1"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Hardware validation script for Arch Linux Hyprland automation.

OPTIONS:
    -r, --report          Generate detailed report
    -v, --verbose         Show detailed hardware information
    -h, --help           Show this help message

EXAMPLES:
    $0                   # Basic validation
    $0 --report          # Generate detailed report
    $0 --verbose         # Show detailed hardware info

EOF
}

# Check UEFI support
check_uefi() {
    info "Checking UEFI support..."
    
    if [[ -d /sys/firmware/efi/efivars ]]; then
        SUPPORTS_UEFI=true
        success "UEFI boot mode detected"
        
        # Check secure boot status
        if [[ -f /sys/firmware/efi/efivars/SecureBoot-* ]]; then
            local secureboot_status
            secureboot_status=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print $NF}')
            if [[ "$secureboot_status" == "1" ]]; then
                warn "Secure Boot is enabled (may need to be disabled for some drivers)"
            else
                success "Secure Boot is disabled"
            fi
        fi
    else
        error "Legacy BIOS boot detected - UEFI required for this setup"
        return 1
    fi
}

# Check memory requirements
check_memory() {
    info "Checking memory requirements..."
    
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    
    if [[ $ram_gb -ge $MIN_RAM_GB ]]; then
        success "Memory: ${ram_gb}GB (minimum ${MIN_RAM_GB}GB)"
    else
        error "Insufficient memory: ${ram_gb}GB (minimum ${MIN_RAM_GB}GB required)"
        return 1
    fi
    
    # Check available memory
    local available_gb
    available_gb=$(free -g | awk '/^Mem:/ {print $7}')
    info "Available memory: ${available_gb}GB"
}

# Check storage requirements
check_storage() {
    info "Checking storage requirements..."
    
    local storage_gb
    storage_gb=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    
    if [[ $storage_gb -ge $MIN_STORAGE_GB ]]; then
        success "Storage: ${storage_gb}GB (minimum ${MIN_STORAGE_GB}GB)"
    else
        error "Insufficient storage: ${storage_gb}GB (minimum ${MIN_STORAGE_GB}GB required)"
        return 1
    fi
    
    # Check available storage
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    info "Available storage: ${available_gb}GB"
    
    # Check for SSD (for TRIM support)
    local root_device
    root_device=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//')
    if [[ -f "/sys/block/$(basename "$root_device")/queue/rotational" ]]; then
        local is_rotational
        is_rotational=$(cat "/sys/block/$(basename "$root_device")/queue/rotational")
        if [[ "$is_rotational" == "0" ]]; then
            success "SSD detected (TRIM support available)"
        else
            info "HDD detected (consider SSD for better performance)"
        fi
    fi
}

# Check CPU requirements
check_cpu() {
    info "Checking CPU requirements..."
    
    local cpu_cores
    cpu_cores=$(nproc)
    
    if [[ $cpu_cores -ge $MIN_CPU_CORES ]]; then
        success "CPU cores: ${cpu_cores} (minimum ${MIN_CPU_CORES})"
    else
        error "Insufficient CPU cores: ${cpu_cores} (minimum ${MIN_CPU_CORES} required)"
        return 1
    fi
    
    # Check CPU info
    local cpu_model
    cpu_model=$(lscpu | grep "Model name:" | sed 's/Model name:\s*//')
    info "CPU: $cpu_model"
    
    # Check for hardware virtualization
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        success "Hardware virtualization supported"
    else
        warn "Hardware virtualization not detected"
    fi
    
    # Check for AES-NI (for encryption)
    if grep -q "aes" /proc/cpuinfo; then
        SUPPORTS_ENCRYPTION=true
        success "AES-NI encryption support detected"
    else
        warn "AES-NI not detected (encryption may be slower)"
    fi
}

# Check graphics capabilities
check_graphics() {
    info "Checking graphics hardware..."
    
    # Check for Intel GPU
    if lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null; then
        HAS_INTEL_GPU=true
        success "Intel GPU detected"
        local intel_gpu
        intel_gpu=$(lspci | grep -i "intel.*graphics\|intel.*display" | head -1 | cut -d':' -f3)
        info "Intel GPU: $intel_gpu"
        
        # Check for Intel GPU driver
        if lsmod | grep -q "i915"; then
            success "Intel i915 driver loaded"
        else
            warn "Intel i915 driver not loaded"
        fi
    fi
    
    # Check for NVIDIA GPU
    if lspci | grep -i nvidia >/dev/null; then
        HAS_NVIDIA_GPU=true
        warn "NVIDIA GPU detected (may require proprietary drivers)"
        local nvidia_gpu
        nvidia_gpu=$(lspci | grep -i nvidia | head -1 | cut -d':' -f3)
        info "NVIDIA GPU: $nvidia_gpu"
        
        # Check for NVIDIA driver
        if lsmod | grep -q "nvidia"; then
            info "NVIDIA driver loaded"
        else
            info "NVIDIA driver not loaded (install nvidia package if needed)"
        fi
    fi
    
    # Check for AMD GPU
    if lspci | grep -i "amd\|ati" | grep -i "vga\|display" >/dev/null; then
        HAS_AMD_GPU=true
        success "AMD GPU detected"
        local amd_gpu
        amd_gpu=$(lspci | grep -i "amd\|ati" | grep -i "vga\|display" | head -1 | cut -d':' -f3)
        info "AMD GPU: $amd_gpu"
        
        # Check for AMD driver
        if lsmod | grep -q "amdgpu\|radeon"; then
            success "AMD GPU driver loaded"
        else
            warn "AMD GPU driver not loaded"
        fi
    fi
    
    # Check Wayland compatibility
    if [[ "$HAS_INTEL_GPU" == true ]] || [[ "$HAS_AMD_GPU" == true ]]; then
        success "Wayland-compatible GPU detected"
    elif [[ "$HAS_NVIDIA_GPU" == true ]]; then
        warn "NVIDIA GPU detected - Wayland support may require specific configuration"
    else
        error "No suitable GPU detected for Wayland"
        return 1
    fi
}

# Check wireless capabilities
check_wireless() {
    info "Checking wireless capabilities..."
    
    # Check for WiFi
    if ls /sys/class/net/*/wireless >/dev/null 2>&1; then
        HAS_WIFI=true
        success "WiFi adapter detected"
        
        local wifi_devices
        wifi_devices=$(ls /sys/class/net/*/wireless | wc -l)
        info "WiFi adapters: $wifi_devices"
        
        # List WiFi devices
        for wireless_dir in /sys/class/net/*/wireless; do
            local interface
            interface=$(basename "$(dirname "$wireless_dir")")
            local driver
            driver=$(readlink "/sys/class/net/$interface/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
            info "WiFi interface: $interface (driver: $driver)"
        done
    else
        warn "No WiFi adapter detected"
    fi
    
    # Check for Bluetooth
    if command -v bluetoothctl >/dev/null && bluetoothctl list | grep -q "Controller"; then
        HAS_BLUETOOTH=true
        success "Bluetooth adapter detected"
    elif lsusb | grep -i bluetooth >/dev/null || lspci | grep -i bluetooth >/dev/null; then
        HAS_BLUETOOTH=true
        warn "Bluetooth hardware detected but service not running"
    else
        info "No Bluetooth adapter detected"
    fi
}

# Check laptop-specific features
check_laptop_features() {
    info "Checking laptop-specific features..."
    
    # Check if system is a laptop
    local chassis_type
    chassis_type=$(dmidecode -s chassis-type 2>/dev/null || echo "unknown")
    
    if [[ "$chassis_type" =~ ^(Laptop|Notebook|Portable)$ ]]; then
        IS_LAPTOP=true
        success "Laptop detected"
        
        # Check battery
        if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
            success "Battery detected"
            
            # Check battery status
            for battery in /sys/class/power_supply/BAT*; do
                local bat_name
                bat_name=$(basename "$battery")
                local capacity
                capacity=$(cat "$battery/capacity" 2>/dev/null || echo "unknown")
                local status
                status=$(cat "$battery/status" 2>/dev/null || echo "unknown")
                info "Battery $bat_name: ${capacity}% ($status)"
            done
        else
            warn "No battery detected on laptop"
        fi
        
        # Check AC adapter
        if ls /sys/class/power_supply/A{C,DP}* >/dev/null 2>&1; then
            success "AC adapter detected"
        else
            warn "No AC adapter detected"
        fi
        
        # Check for lid switch
        if [[ -f /proc/acpi/button/lid/LID*/state ]] || grep -q "lid" /proc/acpi/wakeup 2>/dev/null; then
            success "Lid switch detected"
        else
            info "Lid switch not detected"
        fi
        
        # Check for backlight control
        if ls /sys/class/backlight/*/ >/dev/null 2>&1; then
            success "Backlight control available"
            for backlight in /sys/class/backlight/*/; do
                local bl_name
                bl_name=$(basename "$backlight")
                info "Backlight device: $bl_name"
            done
        else
            warn "No backlight control detected"
        fi
    else
        info "Desktop system detected"
    fi
}

# Check audio system
check_audio() {
    info "Checking audio system..."
    
    # Check for audio devices
    if lspci | grep -i audio >/dev/null; then
        success "Audio hardware detected"
        
        local audio_devices
        audio_devices=$(lspci | grep -i audio | wc -l)
        info "Audio devices: $audio_devices"
        
        # Check ALSA
        if [[ -d /proc/asound ]]; then
            success "ALSA subsystem present"
        else
            warn "ALSA subsystem not detected"
        fi
        
        # Check PulseAudio/PipeWire
        if command -v pulseaudio >/dev/null; then
            info "PulseAudio available"
        fi
        
        if command -v pipewire >/dev/null; then
            success "PipeWire available (recommended for Wayland)"
        else
            warn "PipeWire not detected (recommended for Hyprland)"
        fi
    else
        error "No audio hardware detected"
        return 1
    fi
}

# Check virtualization environment
check_virtualization() {
    info "Checking virtualization environment..."
    
    # Check if running in VM
    local virt_type
    virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
    
    if [[ "$virt_type" != "none" ]]; then
        warn "Running in virtual machine: $virt_type"
        info "Some hardware features may not be available"
        
        # VM-specific checks
        case "$virt_type" in
            "vmware")
                info "VMware detected - install open-vm-tools for better integration"
                ;;
            "virtualbox")
                info "VirtualBox detected - install virtualbox-guest-utils for better integration"
                ;;
            "kvm"|"qemu")
                info "KVM/QEMU detected - install qemu-guest-agent for better integration"
                ;;
        esac
    else
        success "Running on physical hardware"
    fi
}

# Generate detailed report
generate_report() {
    info "Generating hardware validation report..."
    
    cat > "$REPORT_FILE" << EOF
Hardware Validation Report
=========================
Generated: $(date)
System: $(hostnamectl --static || echo "unknown")

SYSTEM OVERVIEW
===============
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')
Kernel: $(uname -r)
Architecture: $(uname -m)
Uptime: $(uptime -p)

HARDWARE SUMMARY
================
UEFI Support: $SUPPORTS_UEFI
Encryption Support: $SUPPORTS_ENCRYPTION
System Type: $(if [[ "$IS_LAPTOP" == true ]]; then echo "Laptop"; else echo "Desktop"; fi)
Virtualization: $(systemd-detect-virt 2>/dev/null || echo "Physical")

PROCESSOR
=========
Model: $(lscpu | grep "Model name:" | sed 's/Model name:\s*//')
Cores: $(nproc)
Architecture: $(lscpu | grep "Architecture:" | sed 's/Architecture:\s*//')
Virtualization: $(lscpu | grep "Virtualization:" | sed 's/Virtualization:\s*//' || echo "Not supported")

MEMORY
======
Total: $(free -h | awk '/^Mem:/ {print $2}')
Available: $(free -h | awk '/^Mem:/ {print $7}')
Swap: $(free -h | awk '/^Swap:/ {print $2}')

STORAGE
=======
$(df -h / | awk 'NR==2 {print "Root filesystem: " $2 " total, " $4 " available"}')
$(lsblk -d -o NAME,SIZE,TYPE,TRAN | grep -E "(disk|ssd)")

GRAPHICS
========
Intel GPU: $HAS_INTEL_GPU
NVIDIA GPU: $HAS_NVIDIA_GPU
AMD GPU: $HAS_AMD_GPU

Graphics Hardware:
$(lspci | grep -i "vga\|display\|graphics" | sed 's/^/  /')

NETWORK
=======
WiFi: $HAS_WIFI
Bluetooth: $HAS_BLUETOOTH

Network Interfaces:
$(ip link show | grep -E "^[0-9]+:" | sed 's/^/  /')

AUDIO
=====
$(lspci | grep -i audio | sed 's/^/  /' || echo "  No PCI audio devices detected")

POWER MANAGEMENT (Laptop)
=========================
Battery: $(if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then echo "Present"; else echo "Not detected"; fi)
AC Adapter: $(if ls /sys/class/power_supply/A{C,DP}* >/dev/null 2>&1; then echo "Present"; else echo "Not detected"; fi)
Backlight: $(if ls /sys/class/backlight/*/ >/dev/null 2>&1; then echo "Available"; else echo "Not available"; fi)

COMPATIBILITY ASSESSMENT
========================
Hyprland Compatibility: $(if [[ "$HAS_INTEL_GPU" == true ]] || [[ "$HAS_AMD_GPU" == true ]]; then echo "[OK] Compatible"; else echo "⚠ May require additional configuration"; fi)
Wayland Support: $(if [[ "$HAS_INTEL_GPU" == true ]] || [[ "$HAS_AMD_GPU" == true ]]; then echo "[OK] Native support"; elif [[ "$HAS_NVIDIA_GPU" == true ]]; then echo "⚠ Requires specific drivers"; else echo "[FAIL] Limited support"; fi)
Power Management: $(if [[ "$IS_LAPTOP" == true ]]; then echo "[OK] Laptop optimizations available"; else echo "ℹ Desktop configuration"; fi)

RECOMMENDATIONS
===============
EOF

    # Add specific recommendations
    if [[ "$HAS_NVIDIA_GPU" == true ]]; then
        echo "- Install nvidia and nvidia-utils packages for NVIDIA GPU support" >> "$REPORT_FILE"
        echo "- Consider using nvidia-dkms for better kernel compatibility" >> "$REPORT_FILE"
    fi
    
    if [[ "$IS_LAPTOP" == true ]]; then
        echo "- Install TLP for power management optimization" >> "$REPORT_FILE"
        echo "- Configure thermald for thermal management" >> "$REPORT_FILE"
    fi
    
    if [[ "$HAS_WIFI" == true ]]; then
        echo "- Ensure NetworkManager is enabled for WiFi management" >> "$REPORT_FILE"
    fi
    
    if ! command -v pipewire >/dev/null; then
        echo "- Install PipeWire for optimal Wayland audio support" >> "$REPORT_FILE"
    fi
    
    success "Report generated: $REPORT_FILE"
}

# Main validation function
run_validation() {
    echo -e "${BLUE}Hardware Validation for Arch Linux Hyprland${NC}"
    echo "============================================="
    echo ""
    
    local failed_checks=0
    
    # Run all checks
    check_uefi || ((failed_checks++))
    echo ""
    
    check_memory || ((failed_checks++))
    echo ""
    
    check_storage || ((failed_checks++))
    echo ""
    
    check_cpu || ((failed_checks++))
    echo ""
    
    check_graphics || ((failed_checks++))
    echo ""
    
    check_wireless
    echo ""
    
    check_laptop_features
    echo ""
    
    check_audio || ((failed_checks++))
    echo ""
    
    check_virtualization
    echo ""
    
    # Summary
    echo -e "${BLUE}VALIDATION SUMMARY${NC}"
    echo "=================="
    
    if [[ $failed_checks -eq 0 ]]; then
        success "All critical checks passed"
        echo -e "${GREEN}[OK] System is compatible with Arch Linux Hyprland automation${NC}"
    else
        error "$failed_checks critical check(s) failed"
        echo -e "${RED}[FAIL] System may not be fully compatible${NC}"
        echo "Please review the failed checks above"
    fi
    
    echo ""
    return $failed_checks
}

# Parse arguments and run
main() {
    local generate_report=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--report)
                generate_report=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Run validation
    if ! run_validation; then
        exit 1
    fi
    
    # Generate report if requested
    if [[ "$generate_report" == true ]]; then
        generate_report
        echo "View the full report with: cat $REPORT_FILE"
    fi
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi