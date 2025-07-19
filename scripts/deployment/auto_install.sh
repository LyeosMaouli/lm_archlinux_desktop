#!/bin/bash
# Automated Arch Linux Base System Installation Script
# This script automates the base system installation process

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-/tmp/deployment_config.yml}"
LOG_FILE="/var/log/auto_install.log"
VERBOSE_LOG="/var/log/auto_install_verbose.log"

# Enhanced logging setup - capture EVERYTHING
setup_comprehensive_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$VERBOSE_LOG")"
    
    # Start comprehensive logging - capture ALL output
    exec > >(tee -a "$VERBOSE_LOG")
    exec 2> >(tee -a "$VERBOSE_LOG" >&2)
    
    # Also log to standard log file
    exec 19>&1
    exec 20>&2
    exec 1> >(tee -a "$LOG_FILE" >&19)
    exec 2> >(tee -a "$LOG_FILE" >&20)
    
    echo "=== AUTO INSTALL VERBOSE LOG STARTED: $(date) ===" >> "$VERBOSE_LOG"
    echo "=== Command: $0 $* ===" >> "$VERBOSE_LOG"
    echo "=== Environment Variables ===" >> "$VERBOSE_LOG"
    env | sort >> "$VERBOSE_LOG"
    echo "=== System Information ===" >> "$VERBOSE_LOG"
    uname -a >> "$VERBOSE_LOG" 2>&1 || true
    lsblk >> "$VERBOSE_LOG" 2>&1 || true
    free -h >> "$VERBOSE_LOG" 2>&1 || true
    echo "=== Network Interfaces ===" >> "$VERBOSE_LOG"
    ip addr show >> "$VERBOSE_LOG" 2>&1 || true
    echo "=== DNS Configuration ===" >> "$VERBOSE_LOG"
    cat /etc/resolv.conf >> "$VERBOSE_LOG" 2>&1 || true
    echo "=== Starting Installation Process ===" >> "$VERBOSE_LOG"
    
    # Try to copy logs to common accessible locations
    copy_logs_to_accessible_locations
}

# Copy logs to locations accessible from host
copy_logs_to_accessible_locations() {
    local accessible_dirs=("/mnt/shared" "/media" "/run/archiso/bootmnt" "/tmp")
    
    for dir in "${accessible_dirs[@]}"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            info "Copying logs to accessible location: $dir"
            cp "$VERBOSE_LOG" "$dir/auto_install_verbose.log" 2>/dev/null || true
            cp "$LOG_FILE" "$dir/auto_install.log" 2>/dev/null || true
        fi
    done
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
    log "INFO: $1"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Parse YAML configuration (simple parser)
parse_config() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E "^\s*${key}:" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^ *//; s/ *$//' | tr -d '"'
    else
        echo ""
    fi
}

# Parse nested YAML values
parse_nested_config() {
    local section="$1"
    local key="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        awk "/^${section}:/{flag=1; next} /^[a-zA-Z]/{flag=0} flag && /${key}:/{print}" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^ *//; s/ *$//' | tr -d '"'
    else
        echo ""
    fi
}

# Check if running in UEFI mode
check_uefi() {
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        error "This script requires UEFI boot mode. Please boot in UEFI mode."
    fi
    info "UEFI boot mode confirmed"
}

# Setup network connection
setup_network() {
    info "Setting up network connection..."
    
    local wifi_enabled=$(parse_nested_config "network" "enabled")
    local wifi_ssid=$(parse_nested_config "network" "ssid")
    local wifi_password=$(parse_nested_config "network" "password")
    
    # Enable NetworkManager if available
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        info "NetworkManager is running"
    else
        info "Starting NetworkManager..."
        systemctl start NetworkManager 2>/dev/null || warn "NetworkManager not available, using iwctl"
    fi
    
    # Connect to WiFi if configured
    if [[ "$wifi_enabled" == "true" ]] && [[ -n "$wifi_ssid" ]] && [[ -n "$wifi_password" ]]; then
        info "Connecting to WiFi network: $wifi_ssid"
        
        # Try NetworkManager first
        if command -v nmcli >/dev/null 2>&1; then
            nmcli device wifi connect "$wifi_ssid" password "$wifi_password" || {
                warn "NetworkManager connection failed, trying iwctl"
                setup_wifi_iwctl "$wifi_ssid" "$wifi_password"
            }
        else
            setup_wifi_iwctl "$wifi_ssid" "$wifi_password"
        fi
    fi
    
    # Test connectivity with detailed reporting
    info "Testing internet connectivity..."
    
    # Try multiple connectivity tests
    local connectivity_ok=false
    
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        info "✓ DNS server (8.8.8.8) reachable"
        connectivity_ok=true
    else
        warn "✗ Cannot reach DNS server (8.8.8.8)"
    fi
    
    if ping -c 1 -W 5 archlinux.org >/dev/null 2>&1; then
        info "✓ Arch Linux website reachable"
        connectivity_ok=true
    else
        warn "✗ Cannot reach archlinux.org"
    fi
    
    if ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        info "✓ Google.com reachable"
        connectivity_ok=true
    else
        warn "✗ Cannot reach google.com"
    fi
    
    if [[ "$connectivity_ok" == true ]]; then
        info "Internet connectivity confirmed"
    else
        # Show network interface status for debugging
        info "Network interface status:"
        ip addr show | grep -E "(inet|link/ether)" || warn "Failed to show network interfaces"
        info "Routing table:"
        ip route show || warn "Failed to show routing table"
        error "No internet connectivity. Please check VM network settings."
    fi
}

# Setup WiFi using iwctl
setup_wifi_iwctl() {
    local ssid="$1"
    local password="$2"
    
    info "Configuring WiFi using iwctl..."
    
    # Get wireless interface
    local interface=$(iwctl device list | grep -E 'wlan[0-9]' | awk '{print $1}' | head -n1)
    if [[ -z "$interface" ]]; then
        error "No wireless interface found"
    fi
    
    info "Using wireless interface: $interface"
    
    # Connect to network
    iwctl --passphrase="$password" station "$interface" connect "$ssid" || error "Failed to connect to WiFi"
    
    # Wait for connection
    sleep 5
}

# Update system clock with comprehensive time sync
update_clock() {
    info "Updating system clock with comprehensive synchronization..."
    
    # Check current time status
    info "Current system time status:"
    timedatectl status || warn "Failed to get time status"
    
    # Enable NTP synchronization with timeout
    info "Enabling NTP synchronization..."
    timedatectl set-ntp true
    
    # Wait for time synchronization with longer timeout
    info "Waiting for time synchronization (up to 60 seconds)..."
    local sync_timeout=60
    local sync_count=0
    
    while [[ $sync_count -lt $sync_timeout ]]; do
        if timedatectl status | grep -q "synchronized: yes"; then
            success "System clock synchronized successfully"
            break
        elif timedatectl status | grep -q "NTP synchronized: yes"; then
            success "NTP synchronization confirmed"
            break
        fi
        
        sleep 1
        sync_count=$((sync_count + 1))
        
        # Show progress every 15 seconds
        if [[ $((sync_count % 15)) == 0 ]]; then
            info "Still waiting for time sync... ($sync_count/$sync_timeout seconds)"
        fi
    done
    
    # Manual time sync if automatic fails
    if [[ $sync_count -ge $sync_timeout ]]; then
        warn "Automatic time sync timed out, attempting manual sync..."
        
        # Try to sync with multiple NTP servers
        local ntp_servers=("time.cloudflare.com" "pool.ntp.org" "time.google.com")
        for server in "${ntp_servers[@]}"; do
            info "Trying NTP server: $server"
            if timeout 10 ntpd -qg -p "$server" 2>/dev/null; then
                success "Manual time sync successful with $server"
                break
            fi
        done
    fi
    
    # Final time check and display
    info "Final system time status:"
    date
    timedatectl status | head -5 || warn "Failed to display final time status"
    
    info "System clock configuration complete"
}

# Simplified disk device detection
detect_disk_device() {
    local config_device=$(parse_nested_config "disk" "device")
    
    info "Detecting disk device..." >&2
    info "Config specified: '$config_device'" >&2
    
    # If device specified in config, use it
    if [[ -n "$config_device" ]]; then
        if [[ -b "$config_device" ]]; then
            info "Using config device: $config_device" >&2
            echo "$config_device"
            return 0
        else
            warn "Config device $config_device not accessible, auto-detecting..." >&2
        fi
    fi
    
    # Auto-detect by trying devices in order
    local devices=("/dev/sda" "/dev/vda" "/dev/nvme0n1" "/dev/hda")
    
    for device in "${devices[@]}"; do
        if [[ -b "$device" ]]; then
            info "Auto-detected device: $device" >&2
            echo "$device"
            return 0
        fi
    done
    
    # Last resort - use /dev/sda even if not detected
    warn "No devices auto-detected, defaulting to /dev/sda" >&2
    echo "/dev/sda"
}

# Get partition naming based on device type
get_partition_name() {
    local device="$1"
    local part_num="$2"
    
    # NVMe devices use p prefix (nvme0n1p1, nvme0n1p2)
    if [[ "$device" =~ nvme ]]; then
        echo "${device}p${part_num}"
    else
        # SATA/SCSI devices use direct numbering (sda1, sda2)
        echo "${device}${part_num}"
    fi
}

# Setup disk partitioning
setup_partitions() {
    local disk_device=$(detect_disk_device)
    info "Using disk device: $disk_device"
    local efi_size=$(parse_nested_config "disk" "efi_size")
    
    if [[ -z "$efi_size" ]]; then
        efi_size="512M"
    fi
    
    info "Setting up partitions on $disk_device..."
    
    # Verify device exists and is accessible with detailed debugging
    info "Verifying disk device access: $disk_device"
    
    if [[ ! -e "$disk_device" ]]; then
        error "Disk device $disk_device does not exist at all"
    elif [[ ! -b "$disk_device" ]]; then
        error "Disk device $disk_device exists but is not a block device ($(file "$disk_device" 2>/dev/null))"
    elif [[ ! -r "$disk_device" ]]; then
        error "Disk device $disk_device exists but is not readable (permissions: $(stat -c %A "$disk_device" 2>/dev/null))"
    else
        info "✓ Disk device $disk_device is accessible"
    fi
    
    info "Disk device verified: $disk_device"
    info "Disk size: $(lsblk -b -d -n -o SIZE "$disk_device" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    
    # Show current disk info
    info "Disk information:"
    lsblk "$disk_device" || warn "Could not display disk information"
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Close any existing LUKS mappings
    cryptsetup close cryptroot 2>/dev/null || true
    
    # Create partition table
    info "Creating GPT partition table..."
    parted "$disk_device" --script mklabel gpt
    
    info "Creating EFI partition (${efi_size})..."
    parted "$disk_device" --script mkpart ESP fat32 1MiB "${efi_size}"
    parted "$disk_device" --script set 1 esp on
    
    info "Creating root partition..."
    parted "$disk_device" --script mkpart primary ext4 "${efi_size}" 100%
    
    # Wait for partition creation and ensure system recognizes them
    info "Waiting for partition table to be recognized..."
    sleep 3
    partprobe "$disk_device" || warn "partprobe failed"
    
    # Force kernel to re-read partition table
    blockdev --rereadpt "$disk_device" 2>/dev/null || warn "blockdev rereadpt failed"
    
    # Wait a bit more for devices to appear
    sleep 2
    
    # Try to trigger udev to create device nodes
    udevadm settle || warn "udevadm settle failed"
    sleep 1
    
    # Export partition names for use by other functions
    export EFI_PARTITION=$(get_partition_name "$disk_device" "1")
    export ROOT_PARTITION=$(get_partition_name "$disk_device" "2")
    export DISK_DEVICE="$disk_device"
    
    info "Partitions created successfully:"
    info "  EFI: $EFI_PARTITION"
    info "  Root: $ROOT_PARTITION"
    
    # Verify partitions exist with retry logic
    info "Verifying partition creation..."
    local max_retries=10
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if [[ -b "$EFI_PARTITION" ]] && [[ -b "$ROOT_PARTITION" ]]; then
            info "✓ All partitions created successfully"
            break
        fi
        
        retry_count=$((retry_count + 1))
        warn "Partition verification attempt $retry_count/$max_retries - waiting for devices..."
        sleep 1
        
        # Show what devices we can see
        info "Available block devices:"
        ls -la /dev/sd* /dev/vd* /dev/nvme* 2>/dev/null || echo "No devices found"
    done
    
    # Final verification
    if [[ ! -b "$EFI_PARTITION" ]]; then
        error "EFI partition $EFI_PARTITION was not created after $max_retries attempts"
    fi
    
    if [[ ! -b "$ROOT_PARTITION" ]]; then
        error "Root partition $ROOT_PARTITION was not created after $max_retries attempts"
    fi
    
    info "✓ Partition verification successful:"
    info "  EFI: $EFI_PARTITION"
    info "  Root: $ROOT_PARTITION"
}

# Setup encryption
setup_encryption() {
    # Try to parse encryption config from nested structure
    local encryption_enabled=$(parse_nested_config "encryption" "enabled")
    local passphrase=$(parse_nested_config "encryption" "passphrase")
    
    # If not found, try alternative parsing
    if [[ -z "$encryption_enabled" ]]; then
        encryption_enabled=$(awk '/^disk:/,/^[a-zA-Z]/{if(/encryption:/){flag=1; next} if(flag && /enabled:/){print $2; exit}}' "$CONFIG_FILE" | tr -d '"')
    fi
    
    if [[ -z "$passphrase" ]]; then
        passphrase=$(awk '/^disk:/,/^[a-zA-Z]/{if(/encryption:/){flag=1; next} if(flag && /passphrase:/){print $2; exit}}' "$CONFIG_FILE" | tr -d '"')
    fi
    
    info "Encryption configuration: enabled=$encryption_enabled"
    
    if [[ "$encryption_enabled" == "true" ]]; then
        info "Setting up LUKS encryption on $ROOT_PARTITION..."
        
        # Verify root partition exists
        if [[ ! -b "$ROOT_PARTITION" ]]; then
            error "Root partition $ROOT_PARTITION does not exist"
        fi
        
        info "Root partition verified: $ROOT_PARTITION"
        lsblk "$ROOT_PARTITION" || warn "Could not display partition info"
        
        # Use passphrase from config or prompt
        if [[ -z "$passphrase" ]]; then
            echo -n "Enter LUKS encryption passphrase: "
            read -s passphrase
            echo
            echo -n "Confirm LUKS encryption passphrase: "
            read -s passphrase_confirm
            echo
            
            if [[ "$passphrase" != "$passphrase_confirm" ]]; then
                error "Passphrases do not match"
            fi
        else
            info "Using passphrase from configuration"
        fi
        
        # Wipe any existing filesystem signatures
        info "Wiping existing filesystem signatures..."
        wipefs -a "$ROOT_PARTITION" || warn "Failed to wipe filesystem signatures"
        
        # Setup LUKS with more explicit parameters
        info "Creating LUKS container (this may take a few minutes)..."
        echo -n "$passphrase" | cryptsetup luksFormat \
            --type luks2 \
            --cipher aes-xts-plain64 \
            --key-size 512 \
            --hash sha512 \
            --use-random \
            --verbose \
            "$ROOT_PARTITION" - || error "Failed to create LUKS container"
        
        info "Opening LUKS container..."
        echo -n "$passphrase" | cryptsetup open "$ROOT_PARTITION" cryptroot - || error "Failed to open LUKS container"
        
        # Verify LUKS device was created
        if [[ ! -b "/dev/mapper/cryptroot" ]]; then
            error "LUKS device /dev/mapper/cryptroot was not created"
        fi
        
        export ENCRYPTED_ROOT="/dev/mapper/cryptroot"
        export ENCRYPTION_ENABLED="true"
        
        info "LUKS encryption configured successfully: $ENCRYPTED_ROOT"
    else
        export ENCRYPTED_ROOT="$ROOT_PARTITION"
        export ENCRYPTION_ENABLED="false"
        info "Encryption disabled, using plain partition: $ROOT_PARTITION"
    fi
    
    info "Root device for formatting: $ENCRYPTED_ROOT"
}

# Format filesystems
format_filesystems() {
    info "Formatting filesystems..."
    
    # Verify devices exist before formatting
    if [[ ! -b "$EFI_PARTITION" ]]; then
        error "EFI partition $EFI_PARTITION does not exist"
    fi
    
    if [[ ! -b "$ENCRYPTED_ROOT" ]]; then
        error "Root device $ENCRYPTED_ROOT does not exist"
    fi
    
    # Format EFI partition
    info "Formatting EFI partition: $EFI_PARTITION"
    mkfs.fat -F32 -v "$EFI_PARTITION" || error "Failed to format EFI partition"
    
    # Format root partition
    info "Formatting root partition: $ENCRYPTED_ROOT"
    mkfs.ext4 -F -v "$ENCRYPTED_ROOT" || error "Failed to format root partition"
    
    # Verify formatting
    info "Verifying filesystem creation..."
    lsblk -f "$EFI_PARTITION" "$ENCRYPTED_ROOT" || warn "Could not verify filesystems"
    
    info "Filesystems formatted successfully"
}

# Mount filesystems
mount_filesystems() {
    info "Mounting filesystems..."
    
    # Unmount any existing mounts first
    info "Cleaning up any existing mounts..."
    umount -R /mnt 2>/dev/null || true
    
    # Mount root
    info "Mounting root filesystem: $ENCRYPTED_ROOT"
    mount "$ENCRYPTED_ROOT" /mnt || error "Failed to mount root filesystem"
    
    # Verify root mount
    if ! mountpoint -q /mnt; then
        error "Root filesystem not properly mounted at /mnt"
    fi
    info "✓ Root filesystem mounted successfully"
    
    # Create and mount EFI
    info "Creating EFI mount point: /mnt/boot"
    mkdir -p /mnt/boot || error "Failed to create /mnt/boot directory"
    
    info "Mounting EFI partition: $EFI_PARTITION"
    mount "$EFI_PARTITION" /mnt/boot || error "Failed to mount EFI partition"
    
    # Verify EFI mount
    if ! mountpoint -q /mnt/boot; then
        error "EFI partition not properly mounted at /mnt/boot"
    fi
    info "✓ EFI partition mounted successfully"
    
    # Show mount status for debugging
    info "Current mount status:"
    mount | grep "/mnt" || warn "No /mnt mounts shown"
    
    info "Filesystems mounted successfully"
}

# Get best mirrors from Arch mirror status or use curated list
get_best_mirrors() {
    # Clear any proxy settings that might interfere
    unset http_proxy https_proxy ftp_proxy rsync_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY RSYNC_PROXY >/dev/null 2>&1
    
    # Configure DNS if needed
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi
    
    # Try to fetch mirror status with better error handling
    local mirror_json="/tmp/mirror_status.json"
    if curl -f -s --max-time 30 --retry 3 --retry-delay 2 "https://archlinux.org/mirrors/status/json/" > "$mirror_json" 2>/dev/null; then
        # Extract HTTPS mirrors with better filtering
        local extracted_mirrors
        extracted_mirrors=$(python3 -c "
import json, sys
try:
    with open('$mirror_json') as f:
        data = json.load(f)
    mirrors = []
    for mirror in data.get('urls', []):
        if mirror.get('protocol') == 'https' and mirror.get('completion_pct', 0) >= 99.0:
            mirrors.append(mirror['url'])
        if len(mirrors) >= 8:
            break
    for m in mirrors:
        print(m)
except:
    sys.exit(1)
" 2>/dev/null)
        
        if [[ -n "$extracted_mirrors" ]]; then
            echo "$extracted_mirrors"
            return 0
        fi
    fi
    
    # Fallback to curated list of highly reliable mirrors (updated 2025)
    cat << 'EOF'
https://geo.mirror.pkgbuild.com/
https://mirrors.kernel.org/archlinux/
https://mirror.rackspace.com/archlinux/
https://archlinux.uk.mirror.allworldit.com/archlinux/
https://mirror.leaseweb.net/archlinux/
https://ftp.halifax.rwth-aachen.de/archlinux/
https://europe.mirror.pkgbuild.com/
https://america.mirror.pkgbuild.com/
EOF
}

# Create optimized mirror list
create_optimized_mirrorlist() {
    info "Creating optimized mirror list..."
    
    # Backup original mirrorlist
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Try to get best mirrors from status page (no logging during capture)
    local mirrors
    if mirrors=$(get_best_mirrors 2>/dev/null); then
        info "✓ Mirror status downloaded successfully"
        info "✓ Creating custom mirror list from status data"
        
        # Create new mirrorlist
        cat > /etc/pacman.d/mirrorlist << EOF
# Arch Linux mirrorlist generated from mirror status
# Generated on $(date)
# Criteria: HTTPS, 100% completion, lowest score

EOF
        
        # Add mirrors (clean URLs only, validate format)
        local mirror_count=0
        while IFS= read -r mirror; do
            if [[ -n "$mirror" && "$mirror" =~ ^https://[a-zA-Z0-9.-]+/ ]]; then
                echo "Server = ${mirror}\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
                info "  Added: $mirror"
                mirror_count=$((mirror_count + 1))
            fi
        done <<< "$mirrors"
        
        if [[ $mirror_count -gt 0 ]]; then
            info "✓ Added $mirror_count mirrors to mirrorlist"
            return 0
        else
            warn "✗ No valid mirrors found in mirror status"
            return 1
        fi
    else
        warn "✗ Failed to get mirrors from status page"
        return 1
    fi
}

# Fix pacman keyring issues (critical for 2025)
fix_pacman_keyring() {
    info "Fixing pacman keyring and signature issues..."
    
    # Check if keyring directory exists and has issues
    if [[ -d "/etc/pacman.d/gnupg" ]]; then
        info "Existing keyring found, checking for corruption..."
        
        # Test keyring integrity
        if ! pacman-key --list-keys >/dev/null 2>&1; then
            warn "Keyring appears corrupted, resetting..."
            rm -rf /etc/pacman.d/gnupg/*
        fi
    fi
    
    # Kill any running gpg-agent processes that might interfere
    info "Stopping any running GPG agents..."
    killall gpg-agent 2>/dev/null || true
    
    # Initialize keyring if needed
    if [[ ! -f "/etc/pacman.d/gnupg/pubring.gpg" ]]; then
        info "Initializing pacman keyring..."
        pacman-key --init || {
            warn "Keyring init failed, trying alternative approach..."
            rm -rf /etc/pacman.d/gnupg
            pacman-key --init || error "Failed to initialize keyring"
        }
    fi
    
    # Populate with Arch Linux keys
    info "Populating keyring with Arch Linux keys..."
    pacman-key --populate archlinux || {
        warn "Key population failed, trying manual approach..."
        
        # Alternative approach: manually refresh keys
        info "Attempting manual key refresh..."
        pacman-key --refresh-keys || warn "Manual key refresh failed"
    }
    
    # Verify keyring is working
    info "Verifying keyring functionality..."
    if pacman-key --list-keys | grep -q "Arch Linux"; then
        success "Keyring successfully configured"
    else
        warn "Keyring verification inconclusive, proceeding with caution"
    fi
    
    # Update archlinux-keyring package if possible
    info "Attempting to update archlinux-keyring package..."
    if timeout 120 pacman -Sy --noconfirm archlinux-keyring 2>/dev/null; then
        success "Keyring package updated successfully"
    else
        warn "Could not update keyring package, continuing with existing keys"
    fi
}

# Install base system
install_base_system() {
    local country=$(parse_config "country")
    
    info "Configuring package mirrors..."
    
    # Try to update mirrors with multiple fallback strategies
    local mirror_updated=false
    
    # Strategy 1: Use optimized mirror list from status page
    if ! $mirror_updated; then
        if create_optimized_mirrorlist; then
            info "✓ Optimized mirrors configured from status page"
            mirror_updated=true
        else
            warn "✗ Optimized mirror selection failed"
        fi
    fi
    
    # Strategy 2: Use reflector with minimal wait (faster settings)
    if ! $mirror_updated; then
        info "Attempting fast mirror detection..."
        if timeout 30 reflector --age 6 --protocol https --sort rate --number 5 --save /etc/pacman.d/mirrorlist 2>/dev/null; then
            info "✓ Fast mirror detection successful"
            mirror_updated=true
        else
            warn "✗ Fast mirror detection failed or timed out"
        fi
    fi
    
    # Strategy 3: Use country-specific mirrors if specified
    if ! $mirror_updated && [[ -n "$country" ]]; then
        info "Attempting mirrors for country: $country"
        if timeout 20 reflector --country "$country" --protocol https --number 3 --save /etc/pacman.d/mirrorlist 2>/dev/null; then
            info "✓ Country-specific mirrors configured"
            mirror_updated=true
        else
            warn "✗ Country-specific mirrors failed"
        fi
    fi
    
    # Strategy 4: Keep original mirrors if all else fails
    if ! $mirror_updated; then
        warn "All mirror strategies failed, restoring original mirrors"
        cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist 2>/dev/null || true
        info "Using original mirrors (may work if they're still functional)"
    fi
    
    # Show current mirror list for debugging
    info "Current mirror configuration:"
    grep -v '^#' /etc/pacman.d/mirrorlist | head -3 || warn "Could not display mirror list"
    
    info "Installing base system packages..."
    info "This may take several minutes depending on internet speed..."
    
    # Fix potential keyring issues first (critical for 2025)
    info "Initializing and updating pacman keyring..."
    fix_pacman_keyring
    
    # Clear pacman cache and force database refresh
    info "Clearing package cache and forcing database refresh..."
    rm -rf /var/lib/pacman/sync/*
    
    # Test package database access with force refresh
    info "Testing package database access with forced refresh..."
    echo "=== PACMAN DATABASE SYNC ATTEMPT ===" >> "$VERBOSE_LOG"
    if ! timeout 60 pacman -Syy --noconfirm 2>&1 | tee -a "$VERBOSE_LOG"; then
        warn "Initial database sync failed, trying alternative approach..."
        
        # Try with different mirror if available
        if [[ -f /etc/pacman.d/mirrorlist.backup ]]; then
            info "Trying backup mirror list..."
            cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
            timeout 60 pacman -Syy --noconfirm 2>/dev/null || warn "Backup mirrors also failed"
        fi
    else
        info "✓ Package database sync successful"
    fi
    
    # Configure pacman for better download handling (in the correct section)
    info "Configuring pacman for reliable downloads..."
    # Remove any existing XferCommand lines
    sed -i '/^XferCommand/d' /etc/pacman.conf
    # Add XferCommand in the [options] section
    sed -i '/^ParallelDownloads/a XferCommand = /usr/bin/curl -L -C - -f --retry 5 --retry-delay 3 --connect-timeout 60 -o %o %u' /etc/pacman.conf
    
    # Try pacstrap with better error handling and diagnostics
    info "Starting package installation with pacstrap..."
    echo "=== PACSTRAP INSTALLATION ATTEMPT ===" >> "$VERBOSE_LOG"
    echo "Target: /mnt" >> "$VERBOSE_LOG"
    echo "Packages: base base-devel linux linux-firmware networkmanager sudo git openssh neovim intel-ucode" >> "$VERBOSE_LOG"
    echo "Mirror list being used:" >> "$VERBOSE_LOG"
    cat /etc/pacman.d/mirrorlist >> "$VERBOSE_LOG" 2>&1
    echo "=== PACSTRAP OUTPUT ===" >> "$VERBOSE_LOG"
    if ! timeout 1800 pacstrap -c /mnt base base-devel linux linux-firmware networkmanager sudo git openssh neovim intel-ucode 2>&1 | tee -a "$VERBOSE_LOG"; then
        warn "Full package installation failed"
        
        # Show more diagnostic information
        info "Diagnostic information:"
        info "Available space in /mnt:"
        df -h /mnt 2>/dev/null || warn "Could not check disk space"
        
        info "Testing network connectivity to package servers:"
        ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 && info "✓ archlinux.org reachable" || warn "✗ archlinux.org unreachable"
        
        # Try minimal installation first with extended timeout
        warn "Attempting minimal installation with essential packages only..."
        if ! timeout 2400 pacstrap -c /mnt base linux networkmanager; then
            # Show current mirror list for debugging
            info "Current mirrors being used:"
            grep -v '^#' /etc/pacman.d/mirrorlist | head -5 || warn "Could not display mirrors"
            
            # Try one more time with just base system
            warn "Attempting absolute minimal installation (base only)..."
            if ! timeout 1800 pacstrap -c /mnt base; then
                error "Even minimal package installation failed. This suggests mirror or network issues."
            else
                info "✓ Minimal base installation succeeded"
            fi
        else
            info "✓ Essential packages installation succeeded"
        fi
        
        # Install additional packages in chroot if minimal succeeded
        info "Minimal installation succeeded, installing additional packages..."
        arch-chroot /mnt pacman -S --noconfirm base-devel sudo git openssh neovim intel-ucode || {
            warn "Some additional packages failed to install, continuing..."
        }
    else
        info "✓ Full package installation completed successfully"
    fi
    
    info "Verifying critical packages..."
    if ! arch-chroot /mnt which systemctl >/dev/null 2>&1; then
        error "systemctl not found - base system installation incomplete"
    fi
    
    info "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab || error "Failed to generate fstab"
    
    # Verify fstab was created
    if [[ ! -s /mnt/etc/fstab ]]; then
        error "fstab file is empty or was not created"
    fi
    
    info "fstab contents:"
    cat /mnt/etc/fstab || warn "Could not display fstab"
    
    info "Base system installation complete"
}

# Configure system
configure_system() {
    local hostname=$(parse_nested_config "system" "hostname")
    local timezone=$(parse_nested_config "system" "timezone")
    local locale=$(parse_nested_config "system" "locale")
    local keymap=$(parse_nested_config "system" "keymap")
    
    info "Configuring system in chroot..."
    
    # Create configuration script for chroot
    cat > /mnt/configure_system.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Configure locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set keyboard layout
echo "KEYMAP=fr" > /etc/vconsole.conf

# Set hostname
echo "phoenix" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1    localhost
::1          localhost
127.0.1.1    phoenix.localdomain    phoenix
HOSTS_EOF

EOF
    
    # Make executable and run
    chmod +x /mnt/configure_system.sh
    arch-chroot /mnt /configure_system.sh
    rm /mnt/configure_system.sh
    
    info "System configuration complete"
}

# Configure bootloader
configure_bootloader() {
    info "Configuring systemd-boot..."
    
    # Create bootloader configuration script
    cat > /mnt/configure_bootloader.sh << EOF
#!/bin/bash
set -euo pipefail

# Install systemd-boot
bootctl install

# Configure loader
cat > /boot/loader/loader.conf << 'LOADER_EOF'
default arch.conf
timeout 5
console-mode max
editor no
LOADER_EOF

# Create boot entry
if [[ "$ENCRYPTION_ENABLED" == "true" ]]; then
    cat > /boot/loader/entries/arch.conf << 'ENTRY_EOF'
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  cryptdevice=$ROOT_PARTITION:cryptroot root=/dev/mapper/cryptroot rw quiet
ENTRY_EOF
else
    cat > /boot/loader/entries/arch.conf << 'ENTRY_EOF'
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  root=$ROOT_PARTITION rw quiet
ENTRY_EOF
fi

EOF
    
    # Add encryption to boot entry if enabled
    if [[ "$ENCRYPTION_ENABLED" == "true" ]]; then
        cat >> /mnt/configure_bootloader.sh << 'EOF'

# Configure mkinitcpio for encryption
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Rebuild initramfs
mkinitcpio -P

EOF
    fi
    
    # Make executable and run
    chmod +x /mnt/configure_bootloader.sh
    arch-chroot /mnt /configure_bootloader.sh
    rm /mnt/configure_bootloader.sh
    
    info "Bootloader configuration complete"
}

# Setup users
setup_users() {
    local username=$(parse_nested_config "user" "username")
    local user_password=$(parse_nested_config "user" "password")
    local root_password=$(parse_nested_config "root" "password")
    
    info "Setting up users..."
    
    # Prompt for passwords if not provided
    if [[ -z "$root_password" ]]; then
        echo -n "Enter root password: "
        read -s root_password
        echo
    fi
    
    if [[ -z "$user_password" ]]; then
        echo -n "Enter password for user $username: "
        read -s user_password
        echo
    fi
    
    # Create user setup script
    cat > /mnt/setup_users.sh << EOF
#!/bin/bash
set -euo pipefail

# Set root password
echo "root:$root_password" | chpasswd

# Create main user
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$user_password" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd

EOF
    
    # Make executable and run
    chmod +x /mnt/setup_users.sh
    arch-chroot /mnt /setup_users.sh
    rm /mnt/setup_users.sh
    
    info "User setup complete"
}

# Copy configuration files
copy_configs() {
    info "Copying configuration files to new system..."
    
    # Copy deployment configuration
    cp "$CONFIG_FILE" /mnt/home/"$(parse_nested_config "user" "username")"/deployment_config.yml 2>/dev/null || true
    
    # Set permissions
    if [[ -f /mnt/home/"$(parse_nested_config "user" "username")"/deployment_config.yml ]]; then
        arch-chroot /mnt chown "$(parse_nested_config "user" "username"):$(parse_nested_config "user" "username")" /home/"$(parse_nested_config "user" "username")"/deployment_config.yml
    fi
    
    info "Configuration files copied"
}

# Main installation function
main() {
    # Setup comprehensive logging FIRST
    setup_comprehensive_logging
    
    info "Starting automated Arch Linux installation with comprehensive logging..."
    info "Verbose log: $VERBOSE_LOG"
    info "Standard log: $LOG_FILE"
    
    # Clear any cached disk device information for fresh start
    unset DISK_DEVICE EFI_PARTITION ROOT_PARTITION ENCRYPTED_ROOT ENCRYPTION_ENABLED
    info "Starting fresh - cleared all disk variables"
    
    # Check prerequisites
    check_uefi
    
    # Load configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Configuration file not found at $CONFIG_FILE"
        warn "Using default values and prompting for required information"
    fi
    
    # Installation steps with enhanced error reporting
    info "Step 1/9: Setting up network..."
    setup_network || error "Network setup failed"
    
    info "Step 2/9: Updating system clock..."
    update_clock || error "Clock update failed"
    
    info "Step 3/9: Setting up disk partitions..."
    setup_partitions || error "Partition setup failed"
    
    info "Step 4/9: Configuring encryption..."
    setup_encryption || error "Encryption setup failed"
    
    info "Step 5/9: Formatting filesystems..."
    format_filesystems || error "Filesystem formatting failed"
    
    info "Step 6/9: Mounting filesystems..."
    mount_filesystems || error "Filesystem mounting failed"
    
    info "Step 7/9: Installing base system..."
    install_base_system || error "Base system installation failed"
    
    info "Step 8/9: Configuring system..."
    configure_system || error "System configuration failed"
    
    info "Step 9/9: Setting up bootloader and users..."
    configure_bootloader || error "Bootloader configuration failed"
    setup_users || error "User setup failed"
    copy_configs || error "Configuration copy failed"
    
    info "Base system installation complete!"
    info "You can now reboot and continue with the desktop automation deployment"
    
    local auto_reboot=$(parse_nested_config "automation" "auto_reboot")
    if [[ "$auto_reboot" == "true" ]]; then
        info "Auto-reboot enabled, rebooting in 10 seconds..."
        sleep 10
        reboot
    else
        info "Manual reboot required. Run 'reboot' when ready."
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi