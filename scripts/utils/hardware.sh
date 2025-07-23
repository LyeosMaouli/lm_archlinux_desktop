#!/bin/bash
#
# hardware.sh - Hardware Detection and Validation Utility
#
# Consolidates hardware detection functionality from multiple scripts:
# - hardware_validation.sh
# - Hardware detection code scattered across deployment scripts
# - System compatibility checking
#
# Usage:
#   ./hardware.sh [COMMAND] [OPTIONS]
#   source hardware.sh && detect_hardware
#
# Commands:
#   detect               Detect all hardware components
#   validate             Validate system compatibility
#   cpu                  Show CPU information
#   gpu                  Show GPU information  
#   memory               Show memory information
#   disk                 Show disk information
#   laptop               Check if system is laptop
#   report               Generate hardware report
#   help                 Show help
#

# Load common functions
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=../internal/common.sh
source "$SCRIPT_DIR/../internal/common.sh"

# Hardware detection results (global state)
declare -A HARDWARE_INFO
HARDWARE_DETECTED=false

# Compatibility requirements
readonly MIN_RAM_GB=2
readonly MIN_DISK_GB=20
readonly REQUIRED_CPU_FLAGS=("x86-64" "sse2" "sse4_1")
readonly SUPPORTED_GPU_VENDORS=("intel" "amd" "nvidia")

#
# System Information Detection
#

# Detect system type and boot mode
detect_system_info() {
    log_debug "Detecting system information..."
    
    # Architecture
    HARDWARE_INFO["arch"]=$(uname -m)
    
    # Kernel version
    HARDWARE_INFO["kernel"]=$(uname -r)
    
    # Boot mode (UEFI vs BIOS)
    if [[ -d /sys/firmware/efi ]]; then
        HARDWARE_INFO["boot_mode"]="UEFI"
    else
        HARDWARE_INFO["boot_mode"]="BIOS"
    fi
    
    # Virtualization check
    local virt_type="none"
    if [[ -f /sys/class/dmi/id/sys_vendor ]]; then
        local sys_vendor
        sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
        case "$sys_vendor" in
            *VMware*) virt_type="vmware" ;;
            *VirtualBox*) virt_type="virtualbox" ;;
            *QEMU*) virt_type="qemu" ;;
            *Microsoft*) virt_type="hyperv" ;;
        esac
    fi
    
    # Additional virtualization detection
    if [[ "$virt_type" == "none" ]]; then
        if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
            virt_type="unknown_vm"
        fi
    fi
    
    HARDWARE_INFO["virtualization"]="$virt_type"
    
    # System vendor and model
    if [[ -f /sys/class/dmi/id/sys_vendor ]]; then
        HARDWARE_INFO["vendor"]=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "Unknown")
    fi
    
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        HARDWARE_INFO["model"]=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
    fi
    
    log_debug "System info detected: ${HARDWARE_INFO[arch]} ${HARDWARE_INFO[boot_mode]} ${HARDWARE_INFO[virtualization]}"
}

#
# CPU Detection
#

# Detect CPU information
detect_cpu() {
    log_debug "Detecting CPU information..."
    
    if [[ ! -f /proc/cpuinfo ]]; then
        log_error "Cannot access /proc/cpuinfo"
        return 1
    fi
    
    # CPU vendor
    local cpu_vendor
    cpu_vendor=$(grep "vendor_id" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}' 2>/dev/null || echo "unknown")
    
    case "$cpu_vendor" in
        GenuineIntel) HARDWARE_INFO["cpu_vendor"]="intel" ;;
        AuthenticAMD) HARDWARE_INFO["cpu_vendor"]="amd" ;;
        *) HARDWARE_INFO["cpu_vendor"]="unknown" ;;
    esac
    
    # CPU model
    local cpu_model
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//' 2>/dev/null || echo "Unknown")
    HARDWARE_INFO["cpu_model"]="$cpu_model"
    
    # CPU cores
    local cpu_cores
    cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    HARDWARE_INFO["cpu_cores"]="$cpu_cores"
    
    # CPU frequency
    local cpu_freq="unknown"
    if [[ -f /proc/cpuinfo ]]; then
        cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}' | awk '{print int($1)}' 2>/dev/null || echo "unknown")
    fi
    HARDWARE_INFO["cpu_freq"]="$cpu_freq"
    
    # CPU flags/features
    local cpu_flags
    cpu_flags=$(grep "^flags" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}' 2>/dev/null || echo "")
    HARDWARE_INFO["cpu_flags"]="$cpu_flags"
    
    # Check for required CPU features
    local missing_flags=()
    for flag in "${REQUIRED_CPU_FLAGS[@]}"; do
        if [[ "$cpu_flags" != *"$flag"* ]]; then
            missing_flags+=("$flag")
        fi
    done
    
    HARDWARE_INFO["cpu_missing_flags"]="${missing_flags[*]}"
    
    # 64-bit support check
    local is_64bit="false"
    if [[ "$cpu_flags" == *"lm"* ]] || [[ "$(uname -m)" == "x86_64" ]]; then
        is_64bit="true"
    fi
    HARDWARE_INFO["cpu_64bit"]="$is_64bit"
    
    log_debug "CPU detected: ${HARDWARE_INFO[cpu_vendor]} ${HARDWARE_INFO[cpu_model]} (${HARDWARE_INFO[cpu_cores]} cores)"
}

#
# GPU Detection
#

# Detect GPU information
detect_gpu() {
    log_debug "Detecting GPU information..."
    
    local gpu_info=""
    local gpu_vendor="unknown"
    local gpu_model="Unknown"
    
    # Try lspci first
    if command_exists lspci; then
        gpu_info=$(lspci | grep -E "(VGA|3D|Display)" 2>/dev/null || echo "")
        
        if [[ -n "$gpu_info" ]]; then
            # Extract vendor
            if echo "$gpu_info" | grep -qi "intel"; then
                gpu_vendor="intel"
            elif echo "$gpu_info" | grep -qi "nvidia"; then
                gpu_vendor="nvidia" 
            elif echo "$gpu_info" | grep -qi "amd\|ati\|radeon"; then
                gpu_vendor="amd"
            fi
            
            # Extract model (first GPU)
            gpu_model=$(echo "$gpu_info" | head -1 | sed 's/.*: //' | sed 's/ (rev.*//')
        fi
    fi
    
    # Fallback to /sys filesystem
    if [[ "$gpu_vendor" == "unknown" ]]; then
        for gpu_path in /sys/class/drm/card*/device/; do
            if [[ -f "$gpu_path/vendor" ]]; then
                local vendor_id
                vendor_id=$(cat "$gpu_path/vendor" 2>/dev/null)
                case "$vendor_id" in
                    0x8086) gpu_vendor="intel" ;;
                    0x10de) gpu_vendor="nvidia" ;;
                    0x1002) gpu_vendor="amd" ;;
                esac
                break
            fi
        done
    fi
    
    HARDWARE_INFO["gpu_vendor"]="$gpu_vendor"
    HARDWARE_INFO["gpu_model"]="$gpu_model"
    HARDWARE_INFO["gpu_info"]="$gpu_info"
    
    # Detect multiple GPUs
    local gpu_count=0
    if [[ -n "$gpu_info" ]]; then
        gpu_count=$(echo "$gpu_info" | wc -l)
    fi
    HARDWARE_INFO["gpu_count"]="$gpu_count"
    
    # Check if GPU is supported
    local gpu_supported="false"
    for vendor in "${SUPPORTED_GPU_VENDORS[@]}"; do
        if [[ "$gpu_vendor" == "$vendor" ]]; then
            gpu_supported="true"
            break
        fi
    done
    HARDWARE_INFO["gpu_supported"]="$gpu_supported"
    
    log_debug "GPU detected: $gpu_vendor $gpu_model (count: $gpu_count)"
}

#
# Memory Detection
#

# Detect memory information
detect_memory() {
    log_debug "Detecting memory information..."
    
    if [[ ! -f /proc/meminfo ]]; then
        log_error "Cannot access /proc/meminfo"
        return 1
    fi
    
    # Total memory
    local total_mem_kb
    total_mem_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    
    HARDWARE_INFO["memory_total_kb"]="$total_mem_kb"
    HARDWARE_INFO["memory_total_gb"]="$total_mem_gb"
    
    # Available memory
    local available_mem_kb
    available_mem_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local available_mem_gb=$((available_mem_kb / 1024 / 1024))
    
    HARDWARE_INFO["memory_available_kb"]="$available_mem_kb"
    HARDWARE_INFO["memory_available_gb"]="$available_mem_gb"
    
    # Swap information
    local swap_total_kb
    swap_total_kb=$(grep "SwapTotal:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
    local swap_total_gb=$((swap_total_kb / 1024 / 1024))
    
    HARDWARE_INFO["swap_total_kb"]="$swap_total_kb"
    HARDWARE_INFO["swap_total_gb"]="$swap_total_gb"
    
    # Memory type detection (if available)
    local memory_type="unknown"
    if command_exists dmidecode && check_root; then
        memory_type=$(dmidecode -t memory 2>/dev/null | grep "Type:" | head -1 | awk '{print $2}' || echo "unknown")
    fi
    HARDWARE_INFO["memory_type"]="$memory_type"
    
    # Check if memory meets requirements
    local memory_sufficient="false"
    if [[ $total_mem_gb -ge $MIN_RAM_GB ]]; then
        memory_sufficient="true"
    fi
    HARDWARE_INFO["memory_sufficient"]="$memory_sufficient"
    
    log_debug "Memory detected: ${total_mem_gb}GB total, ${available_mem_gb}GB available"
}

#
# Storage Detection
#

# Detect storage information
detect_storage() {
    log_debug "Detecting storage information..."
    
    # Get disk information using various methods
    local disks=()
    local total_storage_gb=0
    
    # Method 1: /proc/partitions
    if [[ -f /proc/partitions ]]; then
        while read -r major minor blocks name; do
            # Skip header and non-disk entries
            [[ "$major" =~ ^[0-9]+$ ]] || continue
            [[ "$name" =~ ^[hsv]d[a-z]$|^nvme[0-9]+n[0-9]+$|^mmcblk[0-9]+$ ]] || continue
            
            local size_gb=$((blocks / 1024 / 1024))
            if [[ $size_gb -gt 0 ]]; then
                disks+=("$name:${size_gb}GB")
                ((total_storage_gb += size_gb))
            fi
        done < /proc/partitions
    fi
    
    # Method 2: lsblk (if available)
    if command_exists lsblk && [[ ${#disks[@]} -eq 0 ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[^[:space:]]+[[:space:]]+[0-9.]+[KMGT][[:space:]]+disk ]]; then
                local name size
                name=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $4}')
                disks+=("$name:$size")
                
                # Convert to GB for total calculation
                local size_gb
                if [[ "$size" =~ ([0-9.]+)([KMGT]) ]]; then
                    local num="${BASH_REMATCH[1]}"
                    local unit="${BASH_REMATCH[2]}"
                    case "$unit" in
                        K) size_gb=$(($(echo "$num * 0.001" | bc -l 2>/dev/null || echo "0") | awk '{print int($1)}')) ;;
                        M) size_gb=$(($(echo "$num * 0.1" | bc -l 2>/dev/null || echo "0") | awk '{print int($1)}')) ;;
                        G) size_gb=$(echo "$num" | awk '{print int($1)}') ;;
                        T) size_gb=$(($(echo "$num * 1000" | bc -l 2>/dev/null || echo "0") | awk '{print int($1)}')) ;;
                    esac
                    ((total_storage_gb += size_gb))
                fi
            fi
        done < <(lsblk -d -o NAME,SIZE,TYPE 2>/dev/null)
    fi
    
    HARDWARE_INFO["storage_disks"]="${disks[*]}"
    HARDWARE_INFO["storage_total_gb"]="$total_storage_gb"
    
    # Check if storage meets requirements
    local storage_sufficient="false"
    if [[ $total_storage_gb -ge $MIN_DISK_GB ]]; then
        storage_sufficient="true"
    fi
    HARDWARE_INFO["storage_sufficient"]="$storage_sufficient"
    
    # Detect storage type (SSD vs HDD)
    local storage_types=()
    for disk in "${disks[@]}"; do
        local disk_name
        disk_name=$(echo "$disk" | cut -d: -f1)
        
        local is_ssd="unknown"
        if [[ -f "/sys/block/$disk_name/queue/rotational" ]]; then
            local rotational
            rotational=$(cat "/sys/block/$disk_name/queue/rotational" 2>/dev/null || echo "1")
            if [[ "$rotational" == "0" ]]; then
                is_ssd="true"
                storage_types+=("SSD")
            else
                is_ssd="false"
                storage_types+=("HDD")
            fi
        fi
    done
    
    HARDWARE_INFO["storage_types"]="${storage_types[*]}"
    
    log_debug "Storage detected: ${#disks[@]} disks, ${total_storage_gb}GB total"
}

#
# Laptop Detection
#

# Check if system is a laptop
detect_laptop() {
    log_debug "Checking if system is a laptop..."
    
    local is_laptop="false"
    
    # Method 1: Battery detection
    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        is_laptop="true"
    fi
    
    # Method 2: DMI chassis type
    if [[ "$is_laptop" == "false" && -f /sys/class/dmi/id/chassis_type ]]; then
        local chassis_type
        chassis_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
        
        # Laptop chassis types: 8=Portable, 9=Laptop, 10=Notebook, 14=Sub Notebook
        case "$chassis_type" in
            8|9|10|14) is_laptop="true" ;;
        esac
    fi
    
    # Method 3: Lid switch detection
    if [[ "$is_laptop" == "false" && -d /proc/acpi/button/lid ]]; then
        is_laptop="true"
    fi
    
    # Method 4: Power supply type detection
    if [[ "$is_laptop" == "false" ]]; then
        for ps in /sys/class/power_supply/A{C,DP}*; do
            if [[ -f "$ps/type" ]]; then
                local ps_type
                ps_type=$(cat "$ps/type" 2>/dev/null)
                if [[ "$ps_type" == "Mains" ]] || [[ "$ps_type" == "ADP" ]]; then
                    is_laptop="true"
                    break
                fi
            fi
        done
    fi
    
    HARDWARE_INFO["is_laptop"]="$is_laptop"
    
    # Detect battery information if laptop
    if [[ "$is_laptop" == "true" ]]; then
        local battery_info=""
        local battery_capacity=""
        
        for battery in /sys/class/power_supply/BAT*; do
            if [[ -f "$battery/capacity" ]]; then
                battery_capacity=$(cat "$battery/capacity" 2>/dev/null || echo "unknown")
            fi
            if [[ -f "$battery/model_name" ]]; then
                local model_name
                model_name=$(cat "$battery/model_name" 2>/dev/null || echo "unknown")
                battery_info="$model_name"
            fi
            break
        done
        
        HARDWARE_INFO["battery_capacity"]="$battery_capacity"
        HARDWARE_INFO["battery_info"]="$battery_info"
    fi
    
    log_debug "Laptop detection: $is_laptop"
}

#
# Network Hardware Detection
#

# Detect network hardware
detect_network_hardware() {
    log_debug "Detecting network hardware..."
    
    local ethernet_devices=()
    local wifi_devices=()
    
    # Method 1: Using /sys/class/net
    for interface in /sys/class/net/*/; do
        local iface_name
        iface_name=$(basename "$interface")
        [[ "$iface_name" == "lo" ]] && continue
        
        # Check if wireless
        if [[ -d "$interface/wireless" ]]; then
            wifi_devices+=("$iface_name")
        elif [[ -f "$interface/type" ]]; then
            local type
            type=$(cat "$interface/type" 2>/dev/null)
            if [[ "$type" == "1" ]]; then  # Ethernet type
                ethernet_devices+=("$iface_name")
            fi
        fi
    done
    
    # Method 2: Using lspci (if available)
    if command_exists lspci; then
        local net_info
        net_info=$(lspci | grep -E "(Network|Ethernet|Wireless)" 2>/dev/null || echo "")
        HARDWARE_INFO["network_pci_info"]="$net_info"
    fi
    
    HARDWARE_INFO["ethernet_devices"]="${ethernet_devices[*]}"
    HARDWARE_INFO["wifi_devices"]="${wifi_devices[*]}"
    HARDWARE_INFO["network_device_count"]="$((${#ethernet_devices[@]} + ${#wifi_devices[@]}))"
    
    log_debug "Network hardware: ${#ethernet_devices[@]} ethernet, ${#wifi_devices[@]} WiFi"
}

#
# Complete Hardware Detection
#

# Detect all hardware components
detect_hardware() {
    log_info "Detecting hardware components..."
    
    # Initialize hardware info
    HARDWARE_INFO=()
    
    # Run all detection functions
    detect_system_info || log_warn "System info detection failed"
    detect_cpu || log_warn "CPU detection failed"
    detect_gpu || log_warn "GPU detection failed" 
    detect_memory || log_warn "Memory detection failed"
    detect_storage || log_warn "Storage detection failed"
    detect_laptop || log_warn "Laptop detection failed"
    detect_network_hardware || log_warn "Network hardware detection failed"
    
    HARDWARE_DETECTED=true
    log_info "Hardware detection completed"
    
    return 0
}

#
# Validation Functions
#

# Validate system requirements
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    if [[ "$HARDWARE_DETECTED" != "true" ]]; then
        log_warn "Hardware not detected yet, running detection first..."
        detect_hardware
    fi
    
    local validation_errors=()
    local validation_warnings=()
    
    # Check architecture
    if [[ "${HARDWARE_INFO[arch]}" != "x86_64" ]]; then
        validation_errors+=("Unsupported architecture: ${HARDWARE_INFO[arch]} (x86_64 required)")
    fi
    
    # Check boot mode
    if [[ "${HARDWARE_INFO[boot_mode]}" != "UEFI" ]]; then
        validation_warnings+=("BIOS boot mode detected (UEFI recommended)")
    fi
    
    # Check 64-bit support
    if [[ "${HARDWARE_INFO[cpu_64bit]}" != "true" ]]; then
        validation_errors+=("64-bit CPU support required")
    fi
    
    # Check CPU flags
    if [[ -n "${HARDWARE_INFO[cpu_missing_flags]}" ]]; then
        validation_errors+=("Missing required CPU flags: ${HARDWARE_INFO[cpu_missing_flags]}")
    fi
    
    # Check memory
    if [[ "${HARDWARE_INFO[memory_sufficient]}" != "true" ]]; then
        validation_errors+=("Insufficient RAM: ${HARDWARE_INFO[memory_total_gb]}GB (minimum ${MIN_RAM_GB}GB required)")
    fi
    
    # Check storage
    if [[ "${HARDWARE_INFO[storage_sufficient]}" != "true" ]]; then
        validation_errors+=("Insufficient storage: ${HARDWARE_INFO[storage_total_gb]}GB (minimum ${MIN_DISK_GB}GB required)")
    fi
    
    # Check GPU support
    if [[ "${HARDWARE_INFO[gpu_supported]}" != "true" ]]; then
        validation_warnings+=("GPU vendor may not be fully supported: ${HARDWARE_INFO[gpu_vendor]}")
    fi
    
    # Check network hardware
    if [[ "${HARDWARE_INFO[network_device_count]}" == "0" ]]; then
        validation_warnings+=("No network devices detected")
    fi
    
    # Report results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "System validation failed with ${#validation_errors[@]} errors:"
        for error in "${validation_errors[@]}"; do
            log_error "  ✗ $error"
        done
        
        if [[ ${#validation_warnings[@]} -gt 0 ]]; then
            log_warn "Additional warnings:"
            for warning in "${validation_warnings[@]}"; do
                log_warn "  ⚠ $warning"
            done
        fi
        
        return 1
    fi
    
    if [[ ${#validation_warnings[@]} -gt 0 ]]; then
        log_warn "System validation passed with ${#validation_warnings[@]} warnings:"
        for warning in "${validation_warnings[@]}"; do
            log_warn "  ⚠ $warning"
        done
    fi
    
    log_info "✓ System meets all requirements"
    return 0
}

# Validate for specific use cases
validate_for_hyprland() {
    log_info "Validating system for Hyprland desktop..."
    
    if ! validate_system_requirements; then
        log_error "Basic system requirements not met"
        return 1
    fi
    
    local warnings=()
    
    # Check for GPU acceleration
    if [[ "${HARDWARE_INFO[gpu_vendor]}" == "unknown" ]]; then
        warnings+=("GPU vendor unknown - hardware acceleration may not work")
    elif [[ "${HARDWARE_INFO[gpu_vendor]}" == "nvidia" ]]; then
        warnings+=("NVIDIA GPU detected - may require proprietary drivers for optimal Wayland support")
    fi
    
    # Check memory for desktop environment
    local mem_gb="${HARDWARE_INFO[memory_total_gb]}"
    if [[ $mem_gb -lt 4 ]]; then
        warnings+=("Low memory for desktop environment (${mem_gb}GB) - consider 4GB+ for optimal performance")
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Hyprland validation warnings:"
        for warning in "${warnings[@]}"; do
            log_warn "  ⚠ $warning"
        done
    fi
    
    log_info "✓ System compatible with Hyprland desktop"
    return 0
}

#
# Reporting Functions
#

# Generate hardware report
generate_hardware_report() {
    if [[ "$HARDWARE_DETECTED" != "true" ]]; then
        detect_hardware
    fi
    
    echo "=========================================="
    echo "  Hardware Detection Report"
    echo "=========================================="
    echo
    
    echo "System Information:"
    echo "  Architecture: ${HARDWARE_INFO[arch]:-Unknown}"
    echo "  Boot Mode: ${HARDWARE_INFO[boot_mode]:-Unknown}"
    echo "  Virtualization: ${HARDWARE_INFO[virtualization]:-none}"
    echo "  Vendor: ${HARDWARE_INFO[vendor]:-Unknown}"
    echo "  Model: ${HARDWARE_INFO[model]:-Unknown}"
    echo "  Laptop: ${HARDWARE_INFO[is_laptop]:-unknown}"
    echo
    
    echo "CPU Information:"
    echo "  Vendor: ${HARDWARE_INFO[cpu_vendor]:-unknown}"
    echo "  Model: ${HARDWARE_INFO[cpu_model]:-Unknown}"
    echo "  Cores: ${HARDWARE_INFO[cpu_cores]:-unknown}"
    echo "  Frequency: ${HARDWARE_INFO[cpu_freq]:-unknown} MHz"
    echo "  64-bit Support: ${HARDWARE_INFO[cpu_64bit]:-unknown}"
    if [[ -n "${HARDWARE_INFO[cpu_missing_flags]}" ]]; then
        echo "  Missing Flags: ${HARDWARE_INFO[cpu_missing_flags]}"
    fi
    echo
    
    echo "GPU Information:"
    echo "  Vendor: ${HARDWARE_INFO[gpu_vendor]:-unknown}"
    echo "  Model: ${HARDWARE_INFO[gpu_model]:-Unknown}"
    echo "  Count: ${HARDWARE_INFO[gpu_count]:-0}"
    echo "  Supported: ${HARDWARE_INFO[gpu_supported]:-unknown}"
    echo
    
    echo "Memory Information:"
    echo "  Total: ${HARDWARE_INFO[memory_total_gb]:-0} GB"
    echo "  Available: ${HARDWARE_INFO[memory_available_gb]:-0} GB"
    echo "  Type: ${HARDWARE_INFO[memory_type]:-unknown}"
    echo "  Sufficient: ${HARDWARE_INFO[memory_sufficient]:-unknown}"
    echo
    
    echo "Storage Information:"
    echo "  Total: ${HARDWARE_INFO[storage_total_gb]:-0} GB"
    echo "  Disks: ${HARDWARE_INFO[storage_disks]:-none}"
    echo "  Types: ${HARDWARE_INFO[storage_types]:-unknown}"
    echo "  Sufficient: ${HARDWARE_INFO[storage_sufficient]:-unknown}"
    echo
    
    echo "Network Hardware:"
    echo "  Ethernet: ${HARDWARE_INFO[ethernet_devices]:-none}"
    echo "  WiFi: ${HARDWARE_INFO[wifi_devices]:-none}"
    echo "  Total Devices: ${HARDWARE_INFO[network_device_count]:-0}"
    echo
    
    if [[ "${HARDWARE_INFO[is_laptop]}" == "true" ]]; then
        echo "Battery Information:"
        echo "  Capacity: ${HARDWARE_INFO[battery_capacity]:-unknown}%"
        echo "  Model: ${HARDWARE_INFO[battery_info]:-unknown}"
        echo
    fi
    
    echo "System Requirements:"
    validate_system_requirements >/dev/null 2>&1
    local validation_result=$?
    if [[ $validation_result -eq 0 ]]; then
        echo "  Status: ✓ All requirements met"
    else
        echo "  Status: ✗ Some requirements not met (see validation output)"
    fi
    
    echo "=========================================="
}

# Show specific hardware component
show_hardware_component() {
    local component="$1"
    
    if [[ "$HARDWARE_DETECTED" != "true" ]]; then
        detect_hardware
    fi
    
    case "$component" in
        cpu)
            echo "CPU: ${HARDWARE_INFO[cpu_vendor]} ${HARDWARE_INFO[cpu_model]}"
            echo "Cores: ${HARDWARE_INFO[cpu_cores]}"
            echo "Frequency: ${HARDWARE_INFO[cpu_freq]} MHz"
            echo "64-bit: ${HARDWARE_INFO[cpu_64bit]}"
            ;;
        gpu)
            echo "GPU: ${HARDWARE_INFO[gpu_vendor]} ${HARDWARE_INFO[gpu_model]}"
            echo "Count: ${HARDWARE_INFO[gpu_count]}"
            echo "Supported: ${HARDWARE_INFO[gpu_supported]}"
            ;;
        memory)
            echo "Memory: ${HARDWARE_INFO[memory_total_gb]} GB total"
            echo "Available: ${HARDWARE_INFO[memory_available_gb]} GB"
            echo "Type: ${HARDWARE_INFO[memory_type]}"
            ;;
        disk)
            echo "Storage: ${HARDWARE_INFO[storage_total_gb]} GB total"
            echo "Disks: ${HARDWARE_INFO[storage_disks]}"
            echo "Types: ${HARDWARE_INFO[storage_types]}"
            ;;
        laptop)
            echo "Laptop: ${HARDWARE_INFO[is_laptop]}"
            if [[ "${HARDWARE_INFO[is_laptop]}" == "true" ]]; then
                echo "Battery: ${HARDWARE_INFO[battery_capacity]}%"
            fi
            ;;
        *)
            log_error "Unknown component: $component"
            return 1
            ;;
    esac
}

#
# Command Line Interface
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    
    case "${1:-help}" in
        detect)
            detect_hardware
            ;;
        validate)
            if [[ "$2" == "hyprland" ]]; then
                validate_for_hyprland
            else
                validate_system_requirements
            fi
            ;;
        cpu|gpu|memory|disk|laptop)
            show_hardware_component "$1"
            ;;
        report)
            generate_hardware_report
            ;;
        help|*)
            cat << EOF
Hardware Detection and Validation Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  detect               Detect all hardware components
  validate [hyprland]  Validate system requirements
  cpu                  Show CPU information
  gpu                  Show GPU information  
  memory               Show memory information
  disk                 Show storage information
  laptop               Check if system is laptop
  report               Generate complete hardware report
  help                 Show this help

Examples:
  $0 detect           # Detect all hardware
  $0 validate         # Check system requirements
  $0 validate hyprland # Check Hyprland compatibility
  $0 report           # Show complete hardware report
  $0 cpu              # Show CPU details only

Requirements:
  - Minimum ${MIN_RAM_GB}GB RAM
  - Minimum ${MIN_DISK_GB}GB storage
  - x86_64 architecture
  - Required CPU flags: ${REQUIRED_CPU_FLAGS[*]}
  - Supported GPU vendors: ${SUPPORTED_GPU_VENDORS[*]}

EOF
            ;;
    esac
fi