#!/bin/bash
# scripts/bootstrap/prepare_usb.sh - Fixed paths

set -euo pipefail

# Configuration
USB_DEVICE="/dev/sdb"
REPO_URL="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
WORK_DIR="/tmp/usb-prep"
ARCH_ISO_URL="https://mirror.archlinux.org/iso/latest/archlinux-x86_64.iso"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

prepare_usb() {
    local device=$1
    
    echo "Preparing USB device: $device"
    echo "Project root: $PROJECT_ROOT"
    
    # Download latest Arch ISO
    curl -L "$ARCH_ISO_URL" -o "$WORK_DIR/archlinux.iso"
    
    # Create bootable USB
    dd if="$WORK_DIR/archlinux.iso" of="$device" bs=4M status=progress
    sync
    
    # Mount USB for configuration injection
    mkdir -p "$WORK_DIR/usb_mount"
    mount "${device}2" "$WORK_DIR/usb_mount"
    
    # Inject configuration files FROM YOUR REPO
    mkdir -p "$WORK_DIR/usb_mount/lm_archlinux_desktop"
    cp -r "$PROJECT_ROOT/configs" "$WORK_DIR/usb_mount/lm_archlinux_desktop/"
    cp -r "$PROJECT_ROOT/scripts" "$WORK_DIR/usb_mount/lm_archlinux_desktop/"
    
    # Create autorun script
    cat > "$WORK_DIR/usb_mount/lm_archlinux_desktop/autorun.sh" << 'EOF'
#!/bin/bash
# Auto-execution script for embedded configurations
cd /lm_archlinux_desktop
archinstall --config configs/archinstall/user_configuration.json \
             --creds configs/archinstall/user_credentials.json \
             --silent
EOF
    
    chmod +x "$WORK_DIR/usb_mount/lm_archlinux_desktop/autorun.sh"
    
    umount "$WORK_DIR/usb_mount"
    echo "USB preparation complete"
}

# Rest of the script...