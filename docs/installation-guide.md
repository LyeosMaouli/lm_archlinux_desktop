# Installation Guide: Arch Linux Hyprland Desktop Automation

This guide provides comprehensive instructions for deploying the Arch Linux Hyprland automation system on your work laptop.

## Overview

This automation system transforms a minimal Arch Linux installation into a fully-configured Hyprland desktop environment with:

- **Desktop Environment**: Hyprland Wayland compositor with Waybar, Wofi, Mako, Kitty
- **Security**: UFW firewall, fail2ban, audit logging, system hardening
- **Applications**: Firefox, VS Code, Discord, Zoom, and essential development tools
- **Audio**: PipeWire with Bluetooth support
- **Package Management**: Secure AUR integration with yay

## Prerequisites

### Hardware Requirements
- **Target**: Work laptop with Intel GPU
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 60GB available space
- **Network**: Internet connection for package downloads

### Software Requirements
- Arch Linux ISO (latest)
- USB drive (8GB minimum)
- SSH key pair for repository access

## Installation Methods

Choose one of the following installation approaches:

### Method 1: Fresh Installation (Recommended)
Complete system installation from scratch with full control over partitioning and encryption.

### Method 2: Existing Arch System
Deploy on an existing Arch Linux installation with minimal base system.

---

## Method 1: Fresh Installation

### Phase 1: Prepare Installation Media

#### 1.1 Download Arch Linux ISO
```bash
# Download latest Arch Linux ISO
curl -O https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso

# Verify checksum (optional but recommended)
curl -O https://mirror.rackspace.com/archlinux/iso/latest/sha256sums.txt
sha256sum -c sha256sums.txt --ignore-missing
```

#### 1.2 Create Bootable USB
```bash
# Linux/macOS
sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Windows (use Rufus or similar tool)
# Select ISO, target USB drive, and flash
```

### Phase 2: Base System Installation

#### 2.1 Boot from USB
1. Insert USB drive and boot from it
2. Select "Arch Linux install medium"
3. Wait for boot process to complete

#### 2.2 Pre-installation Setup
```bash
# Verify UEFI boot mode
ls /sys/firmware/efi/efivars

# Connect to internet
# For WiFi:
iwctl
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "SSID"
exit

# For Ethernet (usually automatic):
ping archlinux.org

# Update system clock
timedatectl set-ntp true
```

#### 2.3 Disk Partitioning
```bash
# List available disks
lsblk

# Partition the disk (replace /dev/nvme0n1 with your disk)
fdisk /dev/nvme0n1

# Create GPT partition table and partitions:
g          # Create GPT
n          # New partition 1 (EFI)
1
<Enter>    # Default start
+512M      # 512MB for EFI
t          # Change type
1          # EFI System

n          # New partition 2 (Root)
2
<Enter>    # Default start
<Enter>    # Use remaining space

w          # Write changes
```

#### 2.4 Encryption Setup (Recommended)
```bash
# Set up LUKS encryption on root partition
cryptsetup luksFormat /dev/nvme0n1p2
# Enter a strong passphrase

# Open encrypted partition
cryptsetup open /dev/nvme0n1p2 cryptroot
```

#### 2.5 Filesystem Creation
```bash
# Format EFI partition
mkfs.fat -F32 /dev/nvme0n1p1

# Format root partition
mkfs.ext4 /dev/mapper/cryptroot  # Encrypted
# OR
mkfs.ext4 /dev/nvme0n1p2        # Non-encrypted
```

#### 2.6 Mount Filesystems
```bash
# Mount root
mount /dev/mapper/cryptroot /mnt  # Encrypted
# OR
mount /dev/nvme0n1p2 /mnt        # Non-encrypted

# Mount EFI
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

#### 2.7 Install Base System
```bash
# Update mirror list
reflector --country "United Kingdom" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Install essential packages
pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo git openssh neovim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
```

#### 2.8 Configure Base System
```bash
# Chroot into new system
arch-chroot /mnt

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
cat > /etc/hosts << EOF
127.0.0.1    localhost
::1          localhost
127.0.1.1    phoenix.localdomain    phoenix
EOF
```

#### 2.9 Configure Bootloader
```bash
# Install systemd-boot
bootctl install

# Configure loader
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 5
console-mode max
editor no
EOF

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)  # Encrypted
# OR
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)       # Non-encrypted

# Create boot entry for encrypted system
cat > /boot/loader/entries/arch.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  cryptdevice=/dev/nvme0n1p2:cryptroot root=/dev/mapper/cryptroot rw quiet
EOF

# For non-encrypted system:
cat > /boot/loader/entries/arch.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  root=UUID=$ROOT_UUID rw quiet
EOF
```

#### 2.10 Configure Encryption (If Using LUKS)
```bash
# Install intel-ucode for Intel processors
pacman -S intel-ucode

# Configure mkinitcpio for encryption
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Rebuild initramfs
mkinitcpio -P
```

#### 2.11 User Setup
```bash
# Set root password
passwd

# Create main user
useradd -m -G wheel -s /bin/bash lyeosmaouli
passwd lyeosmaouli

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd
```

#### 2.12 Finalize Installation
```bash
# Exit chroot
exit

# Unmount all partitions
umount -R /mnt

# Reboot
reboot
```

### Phase 3: Deploy Automation System

#### 3.1 Post-Boot Setup
```bash
# Remove USB drive and boot from hard disk
# Log in as lyeosmaouli

# Connect to internet
sudo systemctl start NetworkManager
sudo nmcli device wifi connect "SSID" password "password"
# Verify connectivity
ping google.com
```

#### 3.2 Clone Repository
```bash
# Navigate to home directory
cd ~

# Clone the automation repository
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Copy SSH keys to proper location
mkdir -p ~/.ssh
cp ssh/lm-archlinux-deploy ~/.ssh/id_rsa
cp ssh/lm-archlinux-deploy.pub ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

#### 3.3 Install Ansible
```bash
# Install Python and pip
sudo pacman -S python python-pip

# Install Ansible and dependencies using Makefile
make install

# Add pip binaries to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3.4 Deploy System

**Option A: Complete Deployment (Recommended)**
```bash
# Run the complete automation
make full-install

# This will run:
# 1. Bootstrap (base system setup)
# 2. Desktop (Hyprland installation)  
# 3. Security (hardening configuration)
```

**Option B: Step-by-Step Deployment**
```bash
# Step 1: Bootstrap
make bootstrap

# Step 2: Desktop Environment
make desktop

# Step 3: Security Hardening
make security
```

**Option C: Manual Playbook Execution**
```bash
# Main playbook with interactive prompts
ansible-playbook -i configs/ansible/inventory/localhost.yml local.yml

# Individual playbooks
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/bootstrap.yml
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/desktop.yml
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/security.yml
```

---

## Method 2: Existing Arch System

### Prerequisites
- Existing Arch Linux installation with base system
- User with sudo privileges
- Internet connectivity

### Quick Deployment
```bash
# Clone repository
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Install Ansible
make install

# Deploy complete system
make full-install
```

---

## Post-Installation Configuration

### Phase 4: System Validation

#### 4.1 Reboot and Test
```bash
# Reboot to test complete system
sudo reboot

# System should boot to SDDM login manager
# Log in as lyeosmaouli and select "Hyprland" session
```

#### 4.2 Desktop Environment Test
```bash
# Test key bindings:
Super + T          # Terminal (Kitty)
Super + R          # Application launcher (Wofi)
Super + E          # File manager (Thunar)
Super + L          # Lock screen
Super + 1-9        # Switch workspaces

# Verify desktop environment
echo $XDG_CURRENT_DESKTOP  # Should show "Hyprland"
echo $XDG_SESSION_TYPE     # Should show "wayland"
```

#### 4.3 System Services Check
```bash
# Check critical services
systemctl status sddm
systemctl status NetworkManager
systemctl --user status pipewire
sudo systemctl status ufw
sudo systemctl status fail2ban
sudo systemctl status auditd
```

#### 4.4 Security Validation
```bash
# Check firewall status
sudo ufw status verbose

# Check fail2ban
sudo fail2ban-client status

# Run security audit
sudo /usr/local/bin/permission-audit
sudo /usr/local/bin/audit-analysis
```

### Phase 5: Application Testing

#### 5.1 Core Applications
```bash
# Test essential applications
firefox           # Web browser
code              # VS Code (if AUR packages installed)
thunar            # File manager
kitty             # Terminal
```

#### 5.2 Audio System
```bash
# Test audio
pactl info
pavucontrol       # Audio control panel
speaker-test -c 2 # Audio test
```

#### 5.3 AUR Packages
```bash
# Check AUR package status
/home/lyeosmaouli/.local/bin/aur-backup
yay -Qm          # List AUR packages
```

### Phase 6: Maintenance Setup

#### 6.1 System Monitoring
```bash
# Set up regular maintenance
make status      # Check system status
make backup      # Backup configurations

# Schedule maintenance (optional)
sudo systemctl enable --now systemd-timer
```

#### 6.2 Update Procedures
```bash
# System updates
sudo pacman -Syu              # Update official packages
yay -Sua                      # Update AUR packages
/home/lyeosmaouli/.local/bin/update-aur  # Automated AUR updates
```

## Troubleshooting

### Common Issues

#### Boot Problems
```bash
# If system won't boot:
# 1. Boot from Arch ISO
# 2. Decrypt and mount root partition
# 3. Check bootloader configuration
# 4. Repair if necessary

cryptsetup open /dev/nvme0n1p2 cryptroot
mount /dev/mapper/cryptroot /mnt
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt
bootctl status
```

#### Desktop Environment Issues
```bash
# If Hyprland won't start:
systemctl --user status pipewire
journalctl --user -u hyprland

# Restart desktop services:
systemctl --user restart pipewire
systemctl restart sddm
```

#### Network Issues
```bash
# Network troubleshooting:
sudo systemctl restart NetworkManager
nmcli device status
nmcli connection show
```

#### Ansible Deployment Issues
```bash
# Debug Ansible problems:
ansible-playbook -vvv [playbook] # Verbose output
make test                        # Run validation tests
make clean                       # Clean temporary files
```

### Recovery Options

#### System Recovery
```bash
# Boot from Arch ISO for system recovery
# Mount encrypted partitions
# Chroot and repair system
# Restore from backups if needed
```

#### Configuration Recovery
```bash
# Restore from Git backups
git checkout HEAD~1 configs/  # Revert to previous config
make backup                   # Create backup before changes
```

## Advanced Configuration

### Custom Profiles
```bash
# Use different configuration profiles
# Edit configs/profiles/work/ansible/vars.yml
# Customize for specific needs
```

### Additional Security
```bash
# Enhanced security options
ansible-playbook configs/ansible/playbooks/security.yml --extra-vars "enable_strict_hardening=yes"
```

### Performance Tuning
```bash
# Laptop-specific optimizations
# Power management configurations
# Graphics optimizations
```

## Maintenance and Updates

### Regular Maintenance
```bash
# Weekly maintenance routine
make status       # Check system health
make backup       # Backup configurations
sudo pacman -Syu  # Update system packages
yay -Sua         # Update AUR packages
```

### Security Audits
```bash
# Monthly security check
sudo /usr/local/bin/ufw-status
sudo /usr/local/bin/fail2ban-status
sudo /usr/local/bin/audit-analysis
sudo /usr/local/bin/permission-audit
```

### Backup Strategy
```bash
# Configuration backups
make backup                    # Local backup
git commit -am "Config update" # Version control
git push origin main          # Remote backup
```

---

**This installation guide provides a complete pathway from bare metal to a fully-configured Hyprland desktop environment with enterprise-grade security and automation.**