# VirtualBox Testing Guide: Arch Linux Hyprland Automation

This guide provides step-by-step instructions for testing the Arch Linux Hyprland automation system in a VirtualBox environment before deploying to your main work laptop.

## Prerequisites

### Required Software
- **VirtualBox** 7.0 or newer
- **Arch Linux ISO** (latest release)
- At least **8GB RAM** and **60GB disk space** for the VM
- **Git** for cloning the repository

### Download Links
- VirtualBox: https://www.virtualbox.org/wiki/Downloads
- Arch Linux ISO: https://archlinux.org/download/

## Phase 1: VirtualBox VM Setup

### 1.1 Create New Virtual Machine

```bash
# VM Configuration Specifications
- Name: ArchLinux-Hyprland-Test
- Type: Linux
- Version: Arch Linux (64-bit)
- Memory: 4096 MB (minimum) / 8192 MB (recommended)
- Hard Disk: Create new VDI, 60 GB dynamically allocated
```

### 1.2 VM Settings Configuration

**System Settings:**
```bash
# Motherboard Tab
- Boot Order: Hard Disk, Optical, Network
- Chipset: PIIX3
- Enable EFI: ✓ (Important for systemd-boot)

# Processor Tab
- Processor(s): 2-4 CPUs
- Enable PAE/NX: ✓
- Enable VT-x/AMD-V: ✓
```

**Display Settings:**
```bash
# Screen Tab
- Video Memory: 128 MB
- Graphics Controller: VMSVGA
- Enable 3D Acceleration: ✓
```

**Network Settings:**
```bash
# Adapter 1
- Enable Network Adapter: ✓
- Attached to: NAT
- Advanced → Cable Connected: ✓
```

**Storage Settings:**
```bash
# Add Arch Linux ISO to optical drive
- Controller: IDE → Add Optical Drive
- Choose: archlinux-YYYY.MM.DD-x86_64.iso
```

## Phase 2: Arch Linux Base Installation

### 2.1 Boot from ISO

1. Start the VM
2. Select "Arch Linux install medium" from boot menu
3. Wait for the live environment to load

### 2.2 Basic System Preparation

```bash
# Verify UEFI boot mode
ls /sys/firmware/efi/efivars
# Should show EFI variables

# Connect to internet (NAT should work automatically)
ping archlinux.org

# Update system clock
timedatectl set-ntp true
```

### 2.3 Partition the Disk

```bash
# Create partition scheme for systemd-boot + LUKS
fdisk /dev/sda

# Partition layout:
# /dev/sda1: 512M EFI System Partition (type: EFI System)
# /dev/sda2: Rest LUKS encrypted (type: Linux filesystem)

# Commands in fdisk:
g          # Create GPT partition table
n          # New partition 1 (EFI)
1          # Partition number
<Enter>    # Default first sector
+512M      # Size
t          # Change type
1          # EFI System

n          # New partition 2 (Root)
2          # Partition number
<Enter>    # Default first sector
<Enter>    # Default last sector (rest of disk)

w          # Write changes
```

### 2.4 Setup Encryption (Optional but Recommended)

```bash
# Setup LUKS encryption
cryptsetup luksFormat /dev/sda2
# Enter a secure passphrase (remember this for testing)

# Open encrypted partition
cryptsetup open /dev/sda2 cryptroot
```

### 2.5 Format Filesystems

```bash
# Format EFI partition
mkfs.fat -F32 /dev/sda1

# Format root partition
mkfs.ext4 /dev/mapper/cryptroot  # If using encryption
# OR
mkfs.ext4 /dev/sda2              # If not using encryption
```

### 2.6 Mount Filesystems

```bash
# Mount root
mount /dev/mapper/cryptroot /mnt  # If using encryption
# OR
mount /dev/sda2 /mnt             # If not using encryption

# Create and mount EFI partition
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
```

### 2.7 Install Base System

```bash
# Install essential packages
pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo git openssh

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into new system
arch-chroot /mnt
```

### 2.8 Basic System Configuration

```bash
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

# Configure hosts
cat > /etc/hosts << EOF
127.0.0.1    localhost
::1          localhost
127.0.1.1    phoenix.localdomain    phoenix
EOF
```

### 2.9 Configure Boot Loader (systemd-boot)

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

# Create boot entry
cat > /boot/loader/entries/arch.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=/dev/mapper/cryptroot rw quiet
EOF

# If not using encryption, use:
# options  root=/dev/sda2 rw quiet
```

### 2.10 Configure Encryption Boot (If Using LUKS)

```bash
# Add encrypt hook to mkinitcpio
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

# Update boot entry with encryption
sed -i 's/options  root=\/dev\/mapper\/cryptroot rw quiet/options  cryptdevice=\/dev\/sda2:cryptroot root=\/dev\/mapper\/cryptroot rw quiet/' /boot/loader/entries/arch.conf
```

### 2.11 Final Base Setup

```bash
# Set root password
passwd

# Create main user
useradd -m -G wheel -s /bin/bash lyeosmaouli
passwd lyeosmaouli

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable NetworkManager
systemctl enable NetworkManager

# Enable SSH
systemctl enable sshd

# Exit chroot and reboot
exit
umount -R /mnt
reboot
```

## Phase 3: Deploy Automation System

### 3.1 Post-Boot Setup

```bash
# After reboot, log in as lyeosmaouli
# Connect to internet
sudo nmcli device wifi connect "SSID" password "password"
# OR for wired connection, it should connect automatically

# Verify internet connectivity
ping google.com
```

### 3.2 Clone Repository

```bash
# Install git if not already available
sudo pacman -S git

# Clone the automation repository
cd /home/lyeosmaouli
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Set up SSH key (copy from host machine or generate new)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# If you have existing SSH keys, copy them:
# Copy ssh/lm-archlinux-deploy and ssh/lm-archlinux-deploy.pub to ~/.ssh/
# OR generate new keys:
ssh-keygen -t ed25519 -C "test@vm" -f ~/.ssh/id_ed25519
```

### 3.3 Install Python and Ansible

```bash
# Install Python and pip
sudo pacman -S python python-pip

# Install Ansible and dependencies
pip install --user -r requirements.txt

# Add pip binaries to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify Ansible installation
ansible --version
```

### 3.4 Install Ansible Collections

```bash
# Install required Ansible collections
ansible-galaxy install -r configs/ansible/requirements.yml
```

## Phase 4: Test Deployment

### 4.1 Test Bootstrap Phase

```bash
# Test bootstrap playbook
cd /home/lyeosmaouli/lm_archlinux_desktop

# Run bootstrap
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/bootstrap.yml

# Check for errors and verify completion
sudo systemctl status NetworkManager
sudo systemctl status sshd
```

### 4.2 Test Desktop Installation

```bash
# Run desktop installation
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/desktop.yml

# This will install Hyprland and all desktop components
# The installation may take 30-60 minutes depending on internet speed
```

### 4.3 Test Security Hardening

```bash
# Run security hardening
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/security.yml

# Verify security components
sudo ufw status
sudo systemctl status fail2ban
sudo systemctl status auditd
```

### 4.4 Test Full Deployment

```bash
# Test the main playbook (equivalent to all phases)
ansible-playbook -i configs/ansible/inventory/localhost.yml local.yml

# This should run through all interactive prompts:
# - User password confirmation
# - Root password confirmation
# - LUKS passphrase (if using encryption)
# - Deployment confirmation
```

## Phase 5: Validation and Testing

### 5.1 Reboot and Test Desktop

```bash
# Reboot to test the complete system
sudo reboot

# After reboot, you should see SDDM login screen
# Log in as lyeosmaouli and select "Hyprland" session
```

### 5.2 Desktop Environment Tests

**Test Hyprland Components:**
```bash
# Test key bindings:
Super + T          # Terminal (Kitty)
Super + R          # Application launcher (Wofi)
Super + E          # File manager (Thunar)
Super + Q          # Close window
Super + L          # Lock screen
Super + 1-9        # Switch workspaces

# Test applications:
firefox           # Web browser
code              # VS Code (if AUR packages installed)
pavucontrol       # Audio controls
```

### 5.3 System Validation

```bash
# Check services
systemctl status sddm
systemctl status NetworkManager
systemctl --user status pipewire

# Check security
sudo ufw status
sudo fail2ban-client status

# Check desktop environment
echo $XDG_CURRENT_DESKTOP  # Should show "Hyprland"
echo $XDG_SESSION_TYPE     # Should show "wayland"

# Test audio
pactl info
# Test with: speaker-test -c 2

# Test network
nmcli device status
ping google.com
```

### 5.4 Run Built-in Tests

```bash
# Use the provided monitoring scripts
sudo /usr/local/bin/ufw-status
sudo /usr/local/bin/fail2ban-status
sudo /usr/local/bin/audit-analysis

# Check AUR packages
/home/lyeosmaouli/.local/bin/aur-backup
```

## Phase 6: Troubleshooting Common Issues

### 6.1 Boot Issues

**Black screen after reboot:**
```bash
# Boot from Arch ISO, mount encrypted partition, and chroot
cryptsetup open /dev/sda2 cryptroot
mount /dev/mapper/cryptroot /mnt
mount /dev/sda1 /mnt/boot
arch-chroot /mnt

# Check systemd-boot configuration
bootctl status
cat /boot/loader/entries/arch.conf
```

**SDDM not starting:**
```bash
# Check SDDM status
sudo systemctl status sddm
sudo journalctl -u sddm

# Manually start SDDM
sudo systemctl start sddm
```

### 6.2 Desktop Environment Issues

**Hyprland won't start:**
```bash
# Check if Hyprland is installed
which Hyprland

# Try starting manually
Hyprland

# Check logs
journalctl --user -u hyprland
```

**No audio:**
```bash
# Check PipeWire services
systemctl --user status pipewire
systemctl --user status wireplumber

# Restart audio services
systemctl --user restart pipewire
systemctl --user restart wireplumber
```

### 6.3 Network Issues

**No internet connection:**
```bash
# Check NetworkManager
sudo systemctl status NetworkManager
sudo systemctl restart NetworkManager

# List available connections
nmcli device wifi list
nmcli connection show
```

### 6.4 Ansible Issues

**Playbook fails:**
```bash
# Run with verbose output
ansible-playbook -vvv -i configs/ansible/inventory/localhost.yml local.yml

# Check specific role
ansible-playbook -i configs/ansible/inventory/localhost.yml local.yml --tags "base"

# Skip failing components
ansible-playbook -i configs/ansible/inventory/localhost.yml local.yml --skip-tags "aur"
```

## Phase 7: Success Criteria Checklist

### ✅ Deployment Success Validation

- [ ] VM boots successfully to SDDM login screen
- [ ] Can log in as lyeosmaouli user
- [ ] Hyprland desktop environment loads properly
- [ ] Basic applications work (terminal, file manager, browser)
- [ ] Audio system functions correctly
- [ ] Network connectivity is working
- [ ] Security services are running (UFW, fail2ban, audit)
- [ ] AUR packages are installed and functional
- [ ] SSH access is working
- [ ] System is stable and responsive

### ✅ Security Validation

- [ ] UFW firewall is active and configured
- [ ] fail2ban is monitoring SSH attempts
- [ ] Audit system is logging security events
- [ ] File permissions are properly secured
- [ ] User has appropriate sudo access
- [ ] SSH is properly hardened

### ✅ Desktop Environment Validation

- [ ] Hyprland compositor is running
- [ ] Waybar status bar is functional
- [ ] Wofi application launcher works
- [ ] Mako notifications are working
- [ ] Kitty terminal is properly configured
- [ ] Audio controls (pavucontrol) are accessible
- [ ] File manager (Thunar) opens correctly

## Phase 8: Performance Testing

### 8.1 Resource Usage Check

```bash
# Check memory usage
free -h
htop

# Check disk usage
df -h
lsblk

# Check system performance
systemctl status
systemd-analyze blame
```

### 8.2 Boot Time Analysis

```bash
# Analyze boot time
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain
```

## Next Steps After Successful VM Testing

### 1. Document Issues Found
- Create a list of any issues encountered
- Note workarounds or fixes applied
- Update automation scripts if needed

### 2. Prepare for Production Deployment
- Backup your work laptop
- Ensure you have recovery options
- Plan deployment timing

### 3. Production Deployment
- Create Arch Linux installation USB
- Follow the same process on actual hardware
- Deploy automation system

### 4. Post-Deployment
- Run security audits
- Configure additional applications
- Set up backup routines
- Monitor system performance

## Support and Resources

### Log Locations
- Ansible logs: `/var/log/ansible/`
- System logs: `journalctl`
- SDDM logs: `journalctl -u sddm`
- Hyprland logs: `journalctl --user`

### Useful Commands
```bash
# Makefile targets for maintenance
make status          # Check system status
make test           # Run validation tests
make backup         # Create configuration backup
make clean          # Clean temporary files

# Manual maintenance
sudo pacman -Syu    # Update system
yay -Sua           # Update AUR packages
sudo systemctl daemon-reload  # Reload systemd
```

---

**This testing guide ensures a safe, controlled environment for validating the Arch Linux Hyprland automation system before production deployment.**