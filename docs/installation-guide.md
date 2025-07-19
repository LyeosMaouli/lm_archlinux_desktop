# Installation Guide: Arch Linux Hyprland Desktop Automation

This guide provides comprehensive instructions for deploying the Arch Linux Hyprland automation system on your work laptop with **maximum automation** to minimize manual steps.

## 🚀 Automated Installation (Recommended)

The automation system now provides **fully automated installation** with minimal user interaction. Most manual steps have been eliminated through intelligent automation scripts.

### Key Automation Features
- **Automated network setup** (WiFi/Ethernet with configuration)
- **Automated disk partitioning and encryption** 
- **Automated base system installation**
- **Automated desktop environment deployment**
- **Automated security hardening**
- **Automated post-installation configuration**

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
- Network credentials (WiFi SSID/password if needed)
- No SSH keys required (automatically generated)

## Installation Methods

### Method 1: 🤖 Fully Automated Installation (Recommended)
**Zero manual configuration** - Everything automated through configuration file.

### Method 2: ⚡ Quick Semi-Automated 
Minimal manual steps with automated deployment.

### Method 3: 🔧 Manual Installation
Traditional manual approach (for advanced users or troubleshooting).

---

## Method 1: 🤖 Fully Automated Installation

### Phase 1: Prepare Installation Media and Configuration

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

#### 1.3 Create Deployment Configuration
Create your automation configuration file with your specific settings:

```bash
# Download the configuration template
curl -O https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/deployment_config.yml

# Edit with your settings
nano deployment_config.yml
```

**Key settings to customize:**
```yaml
# Network Configuration (for automatic WiFi connection)
network:
  wifi:
    enabled: true
    ssid: "Your-WiFi-Network"      # Your WiFi name
    password: "your-wifi-password"  # Your WiFi password

# User Configuration
user:
  username: "lyeosmaouli"
  password: "your-secure-password"  # Or leave empty to be prompted

# Disk Configuration
disk:
  device: "/dev/nvme0n1"  # Your target disk
  encryption:
    enabled: true
    passphrase: "your-encryption-passphrase"  # Or leave empty

# Automation Settings
automation:
  skip_confirmations: true   # Set to true for fully unattended
  auto_reboot: true         # Automatically reboot when needed
```

#### 1.4 Boot and Run Master Automation
1. Insert USB drive and boot from it
2. Select "Arch Linux install medium"
3. Wait for boot process to complete
4. **Run the master automation script:**

```bash
# Download and run the master automation script
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/master_auto_deploy.sh -o master_auto_deploy.sh
chmod +x master_auto_deploy.sh

# Upload your configuration file to the live environment
# (Transfer via USB, wget, or nano/vim)

# Run fully automated installation
CONFIG_FILE=./deployment_config.yml ./master_auto_deploy.sh auto
```

**That's it!** The script will automatically:
- ✅ Connect to your WiFi network
- ✅ Partition and encrypt your disk  
- ✅ Install the base Arch Linux system
- ✅ Configure bootloader and users
- ✅ Reboot to installed system
- ✅ Deploy complete Hyprland desktop
- ✅ Install and configure all applications
- ✅ Apply security hardening
- ✅ Run post-installation validation

### Phase 2: Wait for Completion

The automation runs completely unattended. You'll see progress updates and can monitor logs:

```bash
# Monitor installation progress (if needed)
tail -f /var/log/master_auto_deploy.log

# The system will automatically reboot between phases
# Final completion will show desktop ready message
```

**Total time:** Approximately 30-60 minutes depending on internet speed.

---

## Method 2: ⚡ Quick Semi-Automated

This method provides a balance between automation and control, with minimal manual steps.

### Phase 1: Manual Base Installation
Follow traditional Arch installation steps for base system only:
1. Boot from ISO and connect to internet
2. Partition disk manually
3. Install base system: `pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo git`
4. Configure basic system (timezone, locale, users)
5. Install bootloader and reboot

### Phase 2: Automated Desktop Deployment
```bash
# After first boot, download and run automation
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/master_auto_deploy.sh -o master_auto_deploy.sh
chmod +x master_auto_deploy.sh

# Run desktop deployment only
./master_auto_deploy.sh desktop
```

---

## Method 3: 🔧 Manual Installation (Advanced Users)

For advanced users who want full control over each step.

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

## 🎉 Post-Installation - System Ready!

If you used Method 1 (Fully Automated), your system is already configured and validated. The automation handles all post-installation tasks automatically.

### ✅ Automated Post-Installation (Method 1)

The automation system automatically handles:
- **System validation** - All components tested
- **Service verification** - All services enabled and running  
- **Security audit** - Complete security configuration verified
- **Desktop testing** - Key bindings and applications validated
- **Maintenance setup** - Update scripts and monitoring configured

### 🔧 Manual Validation (Methods 2-3)

If you used semi-automated or manual installation, run validation:

#### Quick System Status Check
```bash
# Run automated validation
system-status

# Or run comprehensive validation
./lm_archlinux_desktop/scripts/deployment/auto_post_install.sh
```

#### Manual Testing
```bash
# Reboot to test complete system
sudo reboot

# System should boot to SDDM login manager
# Log in as lyeosmaouli and select "Hyprland" session

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