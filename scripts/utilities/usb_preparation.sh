#!/bin/bash
# USB Preparation Script for Arch Linux Hyprland Automation
# Prepares USB drive with Arch Linux ISO and automation files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ARCH_ISO_URL="https://archlinux.org/download/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/tmp/usb_preparation.log"

# Default values
USB_DEVICE=""
ISO_PATH=""
DOWNLOAD_ISO=false
FORMAT_USB=true
ADD_AUTOMATION=true
VERIFY_ISO=true

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

info() {
    echo -e "${CYAN}INFO: $1${NC}"
    log "INFO: $1"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

USB preparation script for Arch Linux Hyprland automation.
Prepares a bootable USB drive with Arch Linux ISO and automation files.

OPTIONS:
    -d, --device DEVICE      USB device (e.g., /dev/sdb)
    -i, --iso PATH           Path to Arch Linux ISO file
    -D, --download           Download latest Arch Linux ISO
    --no-format              Skip USB formatting (use existing partition)
    --no-automation          Skip adding automation files to USB
    --no-verify              Skip ISO verification
    -h, --help               Show this help message

EXAMPLES:
    $0 --device /dev/sdb --download
    $0 -d /dev/sdc -i ~/archlinux.iso
    $0 --device /dev/sdb --iso ./arch.iso --no-verify

WARNING: This script will DESTROY all data on the specified USB device!

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--device)
                USB_DEVICE="$2"
                shift 2
                ;;
            -i|--iso)
                ISO_PATH="$2"
                shift 2
                ;;
            -D|--download)
                DOWNLOAD_ISO=true
                shift
                ;;
            --no-format)
                FORMAT_USB=false
                shift
                ;;
            --no-automation)
                ADD_AUTOMATION=false
                shift
                ;;
            --no-verify)
                VERIFY_ISO=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

# Validate inputs
validate_inputs() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for USB operations"
    fi
    
    # Validate USB device
    if [[ -z "$USB_DEVICE" ]]; then
        error "USB device must be specified with --device"
    fi
    
    if [[ ! -b "$USB_DEVICE" ]]; then
        error "USB device $USB_DEVICE does not exist or is not a block device"
    fi
    
    # Check if device is mounted
    if mount | grep -q "$USB_DEVICE"; then
        warn "USB device $USB_DEVICE is currently mounted"
        info "Unmounting all partitions on $USB_DEVICE..."
        umount "${USB_DEVICE}"* 2>/dev/null || true
    fi
    
    # Validate ISO requirements
    if [[ "$DOWNLOAD_ISO" == false ]] && [[ -z "$ISO_PATH" ]]; then
        error "Either --download or --iso must be specified"
    fi
    
    if [[ -n "$ISO_PATH" ]] && [[ ! -f "$ISO_PATH" ]]; then
        error "ISO file not found: $ISO_PATH"
    fi
}

# List available USB devices
list_usb_devices() {
    info "Available USB storage devices:"
    
    local usb_devices
    usb_devices=$(lsblk -d -o NAME,SIZE,TYPE,TRAN | grep usb | awk '{print "/dev/" $1 " (" $2 ")"}' || echo "None found")
    
    if [[ "$usb_devices" == "None found" ]]; then
        warn "No USB storage devices detected"
    else
        echo "$usb_devices" | while read -r device; do
            echo "  $device"
        done
    fi
    echo ""
}

# Download latest Arch Linux ISO
download_iso() {
    if [[ "$DOWNLOAD_ISO" == false ]]; then
        return 0
    fi
    
    info "Downloading latest Arch Linux ISO..."
    
    local download_dir="/tmp/arch_iso_download"
    mkdir -p "$download_dir"
    
    # Get the latest ISO URL from the download page
    info "Fetching download information..."
    local iso_url
    iso_url=$(curl -s "$ARCH_ISO_URL" | grep -o 'https://.*\.iso' | head -1)
    
    if [[ -z "$iso_url" ]]; then
        error "Could not determine latest ISO URL"
    fi
    
    local iso_filename
    iso_filename=$(basename "$iso_url")
    ISO_PATH="$download_dir/$iso_filename"
    
    info "Downloading: $iso_filename"
    info "This may take several minutes..."
    
    if ! curl -L -o "$ISO_PATH" "$iso_url"; then
        error "Failed to download ISO"
    fi
    
    success "ISO downloaded: $ISO_PATH"
    
    # Download checksums for verification
    if [[ "$VERIFY_ISO" == true ]]; then
        info "Downloading checksums..."
        local checksum_url="${iso_url}.sha256"
        curl -s -L -o "$ISO_PATH.sha256" "$checksum_url" || warn "Could not download checksum"
    fi
}

# Verify ISO integrity
verify_iso() {
    if [[ "$VERIFY_ISO" == false ]]; then
        info "Skipping ISO verification"
        return 0
    fi
    
    info "Verifying ISO integrity..."
    
    local checksum_file="$ISO_PATH.sha256"
    
    if [[ ! -f "$checksum_file" ]]; then
        warn "Checksum file not found, skipping verification"
        return 0
    fi
    
    # Extract expected checksum
    local expected_checksum
    expected_checksum=$(cat "$checksum_file" | awk '{print $1}')
    
    # Calculate actual checksum
    info "Calculating SHA256 checksum (this may take a moment)..."
    local actual_checksum
    actual_checksum=$(sha256sum "$ISO_PATH" | awk '{print $1}')
    
    if [[ "$expected_checksum" == "$actual_checksum" ]]; then
        success "ISO verification passed"
    else
        error "ISO verification failed! File may be corrupted."
    fi
}

# Prepare USB device
prepare_usb_device() {
    info "Preparing USB device: $USB_DEVICE"
    
    # Show device information
    local device_info
    device_info=$(lsblk -d -o NAME,SIZE,MODEL "$USB_DEVICE" | tail -1)
    info "Device info: $device_info"
    
    # Confirm with user
    echo ""
    warn "This will COMPLETELY ERASE all data on $USB_DEVICE"
    echo -n "Are you sure you want to continue? [y/N]: "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Operation cancelled by user"
        exit 0
    fi
    
    if [[ "$FORMAT_USB" == true ]]; then
        info "Formatting USB device..."
        
        # Wipe existing filesystem signatures
        wipefs -a "$USB_DEVICE" || warn "Could not wipe filesystem signatures"
        
        # Create new partition table
        parted "$USB_DEVICE" --script mklabel msdos
        
        # Create single partition
        parted "$USB_DEVICE" --script mkpart primary fat32 1MiB 100%
        parted "$USB_DEVICE" --script set 1 boot on
        
        # Wait for partition to appear
        sleep 2
        partprobe "$USB_DEVICE"
        
        # Format partition
        local partition="${USB_DEVICE}1"
        mkfs.fat -F32 -n "ARCHLINUX" "$partition"
        
        success "USB device formatted"
    else
        info "Skipping USB formatting as requested"
    fi
}

# Write ISO to USB
write_iso_to_usb() {
    info "Writing ISO to USB device..."
    info "This will take several minutes, please be patient..."
    
    # Use dd to write ISO
    local iso_size
    iso_size=$(du -h "$ISO_PATH" | cut -f1)
    info "ISO size: $iso_size"
    
    if ! dd if="$ISO_PATH" of="$USB_DEVICE" bs=4M status=progress oflag=sync; then
        error "Failed to write ISO to USB device"
    fi
    
    # Sync to ensure all data is written
    sync
    
    success "ISO written to USB device"
}

# Add automation files to USB
add_automation_files() {
    if [[ "$ADD_AUTOMATION" == false ]]; then
        info "Skipping automation files"
        return 0
    fi
    
    info "Adding automation files to USB..."
    
    # Mount the USB device
    local mount_point="/mnt/usb_prep"
    mkdir -p "$mount_point"
    
    # Find the correct partition (usually the second one after ISO writing)
    local usb_partition
    if [[ -b "${USB_DEVICE}2" ]]; then
        usb_partition="${USB_DEVICE}2"
    elif [[ -b "${USB_DEVICE}1" ]]; then
        usb_partition="${USB_DEVICE}1"
    else
        warn "Could not find suitable partition for automation files"
        return 0
    fi
    
    if ! mount "$usb_partition" "$mount_point" 2>/dev/null; then
        warn "Could not mount USB partition for automation files"
        return 0
    fi
    
    # Create automation directory
    local automation_dir="$mount_point/automation"
    mkdir -p "$automation_dir"
    
    # Copy key automation files
    if [[ -d "$PROJECT_ROOT" ]]; then
        info "Copying automation scripts..."
        
        # Copy bootstrap script
        if [[ -f "$PROJECT_ROOT/scripts/bootstrap/bootstrap.sh" ]]; then
            cp "$PROJECT_ROOT/scripts/bootstrap/bootstrap.sh" "$automation_dir/"
            chmod +x "$automation_dir/bootstrap.sh"
        fi
        
        # Copy deployment scripts
        if [[ -d "$PROJECT_ROOT/scripts/deployment" ]]; then
            cp -r "$PROJECT_ROOT/scripts/deployment" "$automation_dir/"
            find "$automation_dir/deployment" -name "*.sh" -exec chmod +x {} \;
        fi
        
        # Copy configuration templates
        if [[ -d "$PROJECT_ROOT/profiles" ]]; then
            cp -r "$PROJECT_ROOT/profiles" "$automation_dir/"
        fi
        
        # Create README for the USB
        cat > "$automation_dir/README.txt" << EOF
Arch Linux Hyprland Automation Files
====================================

This USB drive contains the Arch Linux Hyprland automation system.

QUICK START:
1. Boot from this USB drive
2. Connect to internet
3. Run: bash /run/archiso/bootmnt/automation/bootstrap.sh

MANUAL SETUP:
1. Boot from USB and complete base Arch installation
2. Copy automation files: cp -r /run/archiso/bootmnt/automation ~/
3. Run bootstrap: cd ~/automation && bash bootstrap.sh

FILES INCLUDED:
- bootstrap.sh: Initial system setup
- deployment/: Deployment scripts
- profiles/: Configuration profiles

For more information, visit:
https://github.com/LyeosMaouli/lm_archlinux_desktop

Generated: $(date)
EOF
        
        success "Automation files added to USB"
    else
        warn "Project root not found, skipping automation files"
    fi
    
    # Unmount
    umount "$mount_point"
    rmdir "$mount_point"
}

# Verify USB creation
verify_usb() {
    info "Verifying USB creation..."
    
    # Check if USB is bootable
    if file -s "$USB_DEVICE" | grep -q "DOS/MBR boot sector"; then
        success "USB appears to be bootable"
    else
        warn "USB may not be bootable"
    fi
    
    # Show partition information
    info "USB partition information:"
    lsblk "$USB_DEVICE" | sed 's/^/  /'
    
    success "USB preparation completed"
}

# Generate summary
show_summary() {
    echo ""
    echo -e "${BLUE}USB Preparation Summary${NC}"
    echo "======================="
    echo "USB Device: $USB_DEVICE"
    echo "ISO Source: $ISO_PATH"
    echo "Automation Files: $(if [[ "$ADD_AUTOMATION" == true ]]; then echo "Included"; else echo "Not included"; fi)"
    echo "Log File: $LOG_FILE"
    echo ""
    echo -e "${GREEN}USB drive is ready for installation!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Safely eject the USB drive"
    echo "2. Boot target system from USB"
    echo "3. Follow the installation process"
    if [[ "$ADD_AUTOMATION" == true ]]; then
        echo "4. Use automation files in /run/archiso/bootmnt/automation/"
    fi
    echo ""
}

# Main function
main() {
    echo -e "${BLUE}Arch Linux USB Preparation Script${NC}"
    echo "=================================="
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Show available USB devices
    list_usb_devices
    
    # Validate inputs
    validate_inputs
    
    # Download ISO if requested
    download_iso
    
    # Verify ISO
    verify_iso
    
    # Prepare USB device
    prepare_usb_device
    
    # Write ISO to USB
    write_iso_to_usb
    
    # Add automation files
    add_automation_files
    
    # Verify creation
    verify_usb
    
    # Show summary
    show_summary
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi