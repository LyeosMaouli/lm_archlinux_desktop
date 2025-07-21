#!/bin/bash
# Hardware Checker Tool
# Validates hardware compatibility for Arch Linux Hyprland system

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPORT_FILE="/tmp/hardware-check-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$REPORT_FILE"
}

print_header() {
    echo -e "\n${BLUE}=================================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=================================================================================${NC}"
}

print_section() {
    echo -e "\n${BLUE}--- $1 ---${NC}"
}

check_pass() {
    echo -e "${GREEN}[OK] PASS:${NC} $1"
}

check_fail() {
    echo -e "${RED}[FAIL] FAIL:${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1"
}

check_info() {
    echo -e "${BLUE}ℹ INFO:${NC} $1"
}

# Requirement checks
check_cpu() {
    print_section "CPU Compatibility"
    
    # Check architecture
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        check_pass "Architecture: $arch (Compatible)"
    else
        check_fail "Architecture: $arch (x86_64 required)"
        return 1
    fi
    
    # Check CPU flags
    cpu_flags=$(grep flags /proc/cpuinfo | head -1 | cut -d: -f2)
    
    # Check for essential flags
    required_flags=("lm" "cmov" "cx8" "fpu" "fxsr" "mmx" "syscall" "sse2")
    for flag in "${required_flags[@]}"; do
        if echo "$cpu_flags" | grep -q "$flag"; then
            check_pass "CPU flag '$flag' supported"
        else
            check_fail "CPU flag '$flag' missing (required)"
        fi
    done
    
    # Check for modern features
    modern_flags=("sse4_1" "sse4_2" "avx" "aes")
    for flag in "${modern_flags[@]}"; do
        if echo "$cpu_flags" | grep -q "$flag"; then
            check_pass "CPU flag '$flag' supported (performance benefit)"
        else
            check_warn "CPU flag '$flag' not available (may impact performance)"
        fi
    done
    
    # CPU cores
    cores=$(nproc)
    if [[ $cores -ge 2 ]]; then
        check_pass "CPU cores: $cores (Sufficient)"
    else
        check_warn "CPU cores: $cores (2+ recommended for Hyprland)"
    fi
    
    # CPU frequency
    if [[ -f /proc/cpuinfo ]]; then
        max_freq=$(grep "cpu MHz" /proc/cpuinfo | awk '{print $4}' | sort -nr | head -1 | cut -d. -f1)
        if [[ $max_freq -gt 1500 ]]; then
            check_pass "CPU frequency: ${max_freq}MHz (Adequate)"
        else
            check_warn "CPU frequency: ${max_freq}MHz (May be slow for desktop use)"
        fi
    fi
}

check_memory() {
    print_section "Memory Requirements"
    
    # Total memory
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_total_gb=$((mem_total_kb / 1024 / 1024))
    
    if [[ $mem_total_gb -ge 4 ]]; then
        check_pass "RAM: ${mem_total_gb}GB (Sufficient for Hyprland)"
    elif [[ $mem_total_gb -ge 2 ]]; then
        check_warn "RAM: ${mem_total_gb}GB (Minimum for basic usage)"
    else
        check_fail "RAM: ${mem_total_gb}GB (Insufficient - 4GB+ recommended)"
    fi
    
    # Available memory
    mem_available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_available_gb=$((mem_available_kb / 1024 / 1024))
    
    if [[ $mem_available_gb -ge 2 ]]; then
        check_pass "Available RAM: ${mem_available_gb}GB"
    else
        check_warn "Available RAM: ${mem_available_gb}GB (Consider closing applications)"
    fi
}

check_graphics() {
    print_section "Graphics Hardware"
    
    # Check for graphics cards
    if command -v lspci >/dev/null 2>&1; then
        gpu_info=$(lspci | grep -E "VGA|3D|Display")
        
        if [[ -n "$gpu_info" ]]; then
            check_info "Graphics hardware detected:"
            echo "$gpu_info" | while read line; do
                echo "  $line"
                
                # Check for specific vendors
                if echo "$line" | grep -qi "intel"; then
                    check_pass "Intel graphics detected (Good Wayland support)"
                elif echo "$line" | grep -qi "amd\|radeon"; then
                    check_pass "AMD graphics detected (Excellent Wayland support)"
                elif echo "$line" | grep -qi "nvidia"; then
                    check_warn "NVIDIA graphics detected (May need special configuration for Wayland)"
                fi
            done
        else
            check_fail "No graphics hardware detected"
        fi
    else
        check_warn "lspci not available - cannot check graphics hardware"
    fi
    
    # Check for hardware acceleration support
    if [[ -d /dev/dri ]]; then
        dri_devices=$(ls /dev/dri/ 2>/dev/null | wc -l)
        if [[ $dri_devices -gt 0 ]]; then
            check_pass "DRI devices available: $dri_devices"
        else
            check_warn "No DRI devices found"
        fi
    else
        check_warn "/dev/dri directory not found"
    fi
    
    # Check for VA-API support
    if [[ -e /dev/dri/renderD128 ]]; then
        check_pass "Hardware acceleration device available"
    else
        check_warn "Hardware acceleration may not be available"
    fi
}

check_storage() {
    print_section "Storage Requirements"
    
    # Check root filesystem space
    root_space=$(df / | tail -1 | awk '{print $4}')
    root_space_gb=$((root_space / 1024 / 1024))
    
    if [[ $root_space_gb -ge 20 ]]; then
        check_pass "Root filesystem space: ${root_space_gb}GB (Sufficient)"
    elif [[ $root_space_gb -ge 10 ]]; then
        check_warn "Root filesystem space: ${root_space_gb}GB (Minimal - consider cleanup)"
    else
        check_fail "Root filesystem space: ${root_space_gb}GB (Insufficient - 20GB+ recommended)"
    fi
    
    # Check for SSD
    if [[ -f /sys/block/nvme0n1/queue/rotational ]]; then
        if [[ $(cat /sys/block/nvme0n1/queue/rotational) -eq 0 ]]; then
            check_pass "NVMe SSD detected (Excellent performance)"
        fi
    elif [[ -f /sys/block/sda/queue/rotational ]]; then
        if [[ $(cat /sys/block/sda/queue/rotational) -eq 0 ]]; then
            check_pass "SSD detected (Good performance)"
        else
            check_warn "HDD detected (Consider SSD for better performance)"
        fi
    fi
    
    # Check filesystem type
    root_fs=$(findmnt -n -o FSTYPE /)
    case "$root_fs" in
        "ext4")
            check_pass "Root filesystem: $root_fs (Recommended)"
            ;;
        "btrfs")
            check_pass "Root filesystem: $root_fs (Advanced features available)"
            ;;
        "xfs")
            check_pass "Root filesystem: $root_fs (Good performance)"
            ;;
        *)
            check_warn "Root filesystem: $root_fs (May have limitations)"
            ;;
    esac
}

check_network() {
    print_section "Network Hardware"
    
    # Check for network interfaces
    interfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | wc -l)
    if [[ $interfaces -gt 0 ]]; then
        check_pass "Network interfaces available: $interfaces"
        
        # Check specific interface types
        if ip link show | grep -q "wlan"; then
            check_pass "WiFi interface detected"
        fi
        
        if ip link show | grep -qE "eth|enp"; then
            check_pass "Ethernet interface detected"
        fi
    else
        check_fail "No network interfaces found"
    fi
    
    # Check NetworkManager availability
    if systemctl list-unit-files | grep -q "NetworkManager.service"; then
        check_pass "NetworkManager available"
    else
        check_warn "NetworkManager not found (manual network configuration required)"
    fi
}

check_audio() {
    print_section "Audio Hardware"
    
    # Check for audio devices
    if [[ -d /proc/asound ]]; then
        audio_cards=$(ls /proc/asound/ | grep -E "^card[0-9]+" | wc -l)
        if [[ $audio_cards -gt 0 ]]; then
            check_pass "Audio hardware detected: $audio_cards card(s)"
        else
            check_warn "No audio cards found"
        fi
    fi
    
    # Check for PipeWire compatibility
    if command -v pipewire >/dev/null 2>&1; then
        check_pass "PipeWire available"
    else
        check_info "PipeWire not installed (will be installed during setup)"
    fi
    
    # Check for ALSA devices
    if [[ -d /dev/snd ]]; then
        snd_devices=$(ls /dev/snd/ | wc -l)
        check_pass "ALSA sound devices: $snd_devices"
    else
        check_warn "No ALSA sound devices found"
    fi
}

check_boot_system() {
    print_section "Boot System"
    
    # Check for UEFI
    if [[ -d /sys/firmware/efi ]]; then
        check_pass "UEFI boot system detected"
        
        # Check EFI variables
        if [[ -d /sys/firmware/efi/efivars ]]; then
            check_pass "EFI variables accessible"
        else
            check_warn "EFI variables not accessible"
        fi
        
        # Check for ESP
        if mountpoint -q /boot/efi || mountpoint -q /boot; then
            check_pass "EFI System Partition mounted"
        else
            check_warn "EFI System Partition not found"
        fi
    else
        check_warn "Legacy BIOS detected (UEFI recommended)"
    fi
    
    # Check for secure boot
    if [[ -f /sys/firmware/efi/efivars/SecureBoot-* ]]; then
        sb_status=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print $NF}')
        if [[ "$sb_status" == "1" ]]; then
            check_warn "Secure Boot enabled (may require additional configuration)"
        else
            check_pass "Secure Boot disabled (standard configuration)"
        fi
    fi
}

check_virtualization() {
    print_section "Virtualization"
    
    # Check if running in VM
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt_type=$(systemd-detect-virt)
        if [[ "$virt_type" != "none" ]]; then
            check_info "Running in virtual machine: $virt_type"
            
            # VM-specific checks
            case "$virt_type" in
                "kvm"|"qemu")
                    check_pass "KVM/QEMU detected (Good Wayland support)"
                    ;;
                "vmware")
                    check_warn "VMware detected (May need guest additions)"
                    ;;
                "virtualbox")
                    check_warn "VirtualBox detected (Limited 3D acceleration)"
                    ;;
                *)
                    check_info "Virtual machine type: $virt_type"
                    ;;
            esac
        else
            check_pass "Running on physical hardware"
        fi
    fi
    
    # Check for hardware virtualization support
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        check_pass "Hardware virtualization supported"
    else
        check_info "Hardware virtualization not detected"
    fi
}

check_wayland_requirements() {
    print_section "Wayland Requirements"
    
    # Check for essential Wayland libraries
    wayland_libs=(
        "libwayland-client.so"
        "libwayland-server.so"
        "libxkbcommon.so"
    )
    
    for lib in "${wayland_libs[@]}"; do
        if ldconfig -p | grep -q "$lib"; then
            check_pass "Wayland library available: $lib"
        else
            check_warn "Wayland library missing: $lib (will be installed)"
        fi
    done
    
    # Check for input support
    if [[ -d /dev/input ]]; then
        input_devices=$(ls /dev/input/event* 2>/dev/null | wc -l)
        if [[ $input_devices -gt 0 ]]; then
            check_pass "Input devices available: $input_devices"
        else
            check_warn "No input devices found"
        fi
    fi
    
    # Check for seat management
    if command -v loginctl >/dev/null 2>&1; then
        if loginctl show-seat seat0 >/dev/null 2>&1; then
            check_pass "Seat management available"
        else
            check_warn "Seat management issues detected"
        fi
    fi
}

generate_summary() {
    print_header "HARDWARE COMPATIBILITY SUMMARY"
    
    # Count results
    pass_count=$(grep -c "[OK] PASS" "$REPORT_FILE" || echo 0)
    warn_count=$(grep -c "⚠ WARN" "$REPORT_FILE" || echo 0)
    fail_count=$(grep -c "[FAIL] FAIL" "$REPORT_FILE" || echo 0)
    
    echo "Results:"
    echo -e "  ${GREEN}[OK] PASS: $pass_count${NC}"
    echo -e "  ${YELLOW}⚠ WARN: $warn_count${NC}"
    echo -e "  ${RED}[FAIL] FAIL: $fail_count${NC}"
    
    echo ""
    if [[ $fail_count -eq 0 ]]; then
        if [[ $warn_count -eq 0 ]]; then
            echo -e "${GREEN}[COMPLETE] Excellent! Your hardware is fully compatible with Arch Linux Hyprland.${NC}"
        else
            echo -e "${YELLOW}[SUCCESS] Good! Your hardware is compatible with minor considerations.${NC}"
        fi
    else
        echo -e "${RED}[WARNING]  Warning! Some hardware compatibility issues detected.${NC}"
        echo "Please review the FAIL items above before proceeding."
    fi
    
    echo ""
    echo "Full report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log "Starting hardware compatibility check"
    
    print_header "ARCH LINUX HYPRLAND HARDWARE CHECKER"
    echo "This tool validates hardware compatibility for the Arch Linux Hyprland system."
    echo "Checking system requirements and hardware support..."
    
    check_cpu
    check_memory
    check_graphics
    check_storage
    check_network
    check_audio
    check_boot_system
    check_virtualization
    check_wayland_requirements
    
    generate_summary
    
    log "Hardware compatibility check completed"
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << 'EOF'
Hardware Checker Tool - Validate hardware compatibility

This tool checks your hardware against the requirements for:
- Arch Linux base system
- Hyprland Wayland compositor
- Modern desktop environment

Usage: ./hardware_checker.sh

The tool will generate a report with:
[OK] PASS - Requirement met
⚠ WARN - Minor issue or recommendation
[FAIL] FAIL - Critical issue requiring attention

Report is saved to /tmp/hardware-check-TIMESTAMP.log

EOF
    exit 0
fi

main "$@"