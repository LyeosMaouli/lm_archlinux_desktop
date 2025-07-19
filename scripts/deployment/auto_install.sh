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
    
    # Test connectivity
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        info "Internet connectivity confirmed"
    else
        error "No internet connectivity. Please check network configuration."
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

# Update system clock
update_clock() {
    info "Updating system clock..."
    timedatectl set-ntp true
    sleep 2
    info "System clock synchronized"
}

# Detect available disk devices
detect_disk_device() {
    local config_device=$(parse_nested_config "disk" "device")
    
    info "Disk detection debug:"
    info "  Config device: '$config_device'"
    
    # If device specified in config and exists, use it
    if [[ -n "$config_device" ]] && [[ -b "$config_device" ]]; then
        info "  Using config device: $config_device"
        echo "$config_device"
        return 0
    fi
    
    # Auto-detect common disk devices
    local devices=("/dev/nvme0n1" "/dev/sda" "/dev/vda" "/dev/hda")
    
    info "  Checking available devices:"
    for device in "${devices[@]}"; do
        if [[ -b "$device" ]]; then
            info "  ✓ Found: $device"
            echo "$device"
            return 0
        else
            info "  ✗ Missing: $device"
        fi
    done
    
    # If no device found, return default
    local default_device="/dev/sda"
    warn "No disk device found, using default: $default_device"
    echo "$default_device"
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
    local efi_size=$(parse_nested_config "disk" "efi_size")
    
    if [[ -z "$efi_size" ]]; then
        efi_size="512M"
    fi
    
    info "Setting up partitions on $disk_device..."
    
    # Verify device exists
    if [[ ! -b "$disk_device" ]]; then
        error "Disk device $disk_device does not exist or is not accessible"
    fi
    
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
    
    # Wait for partition creation
    sleep 2
    partprobe "$disk_device" || warn "partprobe failed"
    sleep 1
    
    # Export partition names for use by other functions
    export EFI_PARTITION=$(get_partition_name "$disk_device" "1")
    export ROOT_PARTITION=$(get_partition_name "$disk_device" "2")
    export DISK_DEVICE="$disk_device"
    
    info "Partitions created successfully:"
    info "  EFI: $EFI_PARTITION"
    info "  Root: $ROOT_PARTITION"
    
    # Verify partitions exist
    if [[ ! -b "$EFI_PARTITION" ]]; then
        error "EFI partition $EFI_PARTITION was not created"
    fi
    
    if [[ ! -b "$ROOT_PARTITION" ]]; then
        error "Root partition $ROOT_PARTITION was not created"
    fi
}

# Setup encryption
setup_encryption() {
    local encryption_enabled=$(parse_nested_config "disk" "enabled")
    local passphrase=$(parse_nested_config "disk" "passphrase")
    
    if [[ "$encryption_enabled" == "true" ]]; then
        info "Setting up LUKS encryption on $ROOT_PARTITION..."
        
        # Verify root partition exists
        if [[ ! -b "$ROOT_PARTITION" ]]; then
            error "Root partition $ROOT_PARTITION does not exist"
        fi
        
        # Prompt for passphrase if not provided
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
        fi
        
        # Wipe any existing filesystem signatures
        wipefs -a "$ROOT_PARTITION" || warn "Failed to wipe filesystem signatures"
        
        # Setup LUKS with more explicit parameters
        info "Creating LUKS container..."
        echo -n "$passphrase" | cryptsetup luksFormat \
            --type luks2 \
            --cipher aes-xts-plain64 \
            --key-size 512 \
            --hash sha512 \
            --use-random \
            "$ROOT_PARTITION" - || error "Failed to create LUKS container"
        
        info "Opening LUKS container..."
        echo -n "$passphrase" | cryptsetup open "$ROOT_PARTITION" cryptroot - || error "Failed to open LUKS container"
        
        export ENCRYPTED_ROOT="/dev/mapper/cryptroot"
        export ENCRYPTION_ENABLED="true"
        
        info "LUKS encryption configured successfully"
    else
        export ENCRYPTED_ROOT="$ROOT_PARTITION"
        export ENCRYPTION_ENABLED="false"
        info "Encryption disabled, using plain partition: $ROOT_PARTITION"
    fi
}

# Format filesystems
format_filesystems() {
    info "Formatting filesystems..."
    
    # Format EFI partition
    info "Formatting EFI partition: $EFI_PARTITION"
    mkfs.fat -F32 "$EFI_PARTITION" || error "Failed to format EFI partition"
    
    # Format root partition
    info "Formatting root partition: $ENCRYPTED_ROOT"
    mkfs.ext4 -F "$ENCRYPTED_ROOT" || error "Failed to format root partition"
    
    info "Filesystems formatted successfully"
}

# Mount filesystems
mount_filesystems() {
    info "Mounting filesystems..."
    
    # Mount root
    info "Mounting root filesystem: $ENCRYPTED_ROOT"
    mount "$ENCRYPTED_ROOT" /mnt || error "Failed to mount root filesystem"
    
    # Create and mount EFI
    info "Creating EFI mount point and mounting: $EFI_PARTITION"
    mkdir -p /mnt/boot
    mount "$EFI_PARTITION" /mnt/boot || error "Failed to mount EFI partition"
    
    # Verify mounts
    if ! mountpoint -q /mnt; then
        error "Root filesystem not properly mounted"
    fi
    
    if ! mountpoint -q /mnt/boot; then
        error "EFI partition not properly mounted"
    fi
    
    info "Filesystems mounted successfully"
}

# Install base system
install_base_system() {
    local country=$(parse_config "country")
    
    info "Updating mirror list..."
    if [[ -n "$country" ]]; then
        reflector --country "$country" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    else
        reflector --country "United Kingdom" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    fi
    
    info "Installing base system packages..."
    pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo git openssh neovim intel-ucode
    
    info "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
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
    info "Starting automated Arch Linux installation..."
    
    # Check prerequisites
    check_uefi
    
    # Load configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Configuration file not found at $CONFIG_FILE"
        warn "Using default values and prompting for required information"
    fi
    
    # Installation steps
    setup_network
    update_clock
    setup_partitions
    setup_encryption
    format_filesystems
    mount_filesystems
    install_base_system
    configure_system
    configure_bootloader
    setup_users
    copy_configs
    
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