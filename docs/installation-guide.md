# Installation Guide: Arch Linux Hyprland Desktop Automation

The **easiest way** to get a complete, secure, modern Arch Linux desktop system. From bare ISO to fully configured Hyprland desktop in just one command!

## 🌟 Revolutionary Zero-Touch Installation

**BREAKTHROUGH**: Answer just 3 questions and get a complete desktop system!

### What Makes This Special
- ✅ **No configuration files** to edit
- ✅ **Auto-detects everything** (timezone, keyboard, hardware)
- ✅ **Smart networking** (auto-connects ethernet, simple WiFi setup)
- ✅ **Secure by design** (passwords prompted safely, never stored)
- ✅ **Complete automation** (30-60 minutes from ISO to desktop)
- ✅ **Enterprise security** (firewall, encryption, hardening)
- ✅ **Modern tools** (Hyprland, VS Code, development stack)

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

### Method 1: 🌟 Zero-Touch Installation (RECOMMENDED)
**3 questions = Complete desktop!** Ultimate simplicity.

### Method 2: ⚡ Quick Setup 
5 questions with more customization options.

### Method 3: 🤖 Advanced Automated
Manual configuration file editing for power users.

### Method 4: 🔧 Traditional Manual
Step-by-step manual installation (for troubleshooting).

---

## Method 1: 🌟 Zero-Touch Installation (REVOLUTIONARY!)

**The ultimate in simplicity** - Answer 3 questions, get a complete desktop!

### Step 1: Prepare Installation Media
```bash
# Download latest Arch Linux ISO
curl -O https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso

# Create bootable USB (Linux/macOS)
sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Windows: Use Rufus or similar tool
```

### Step 2: Boot and Deploy
1. **Boot from USB** - Select "Arch Linux install medium"
2. **Run one command:**

```bash
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/zero_touch_deploy.sh | bash
```

3. **Answer 3 simple questions:**
   - 👤 Your username
   - 💻 Computer name  
   - 🔒 Enable encryption? (Y/n)

4. **Sit back and relax!** ☕

### What Happens Automatically:
- ✅ **Auto-detects**: Timezone, keyboard layout, best disk
- ✅ **Network setup**: Ethernet auto-connects, WiFi menu if needed
- ✅ **Secure passwords**: Prompted safely (never stored in files)
- ✅ **Complete installation**: Base system + desktop + apps + security
- ✅ **Ready to use**: 30-60 minutes later, complete modern desktop!

**No configuration files to edit. No manual network setup. No password management. Just works!**

---

## Method 2: ⚡ Quick Setup (5 Questions)

More customization options:

```bash
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/quick_deploy.sh | bash
```

**Additional questions:**
- 🌍 Timezone
- ⌨️ Keyboard layout

---

## Method 3: 🤖 Advanced Automated Installation

For users who want to edit configuration files manually:

### Create Configuration File
```bash
# Download template
curl -O https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/example_deployment_config.yml

# Customize it
cp example_deployment_config.yml deployment_config.yml
nano deployment_config.yml
```

### Run Deployment
```bash
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/master_auto_deploy.sh -o deploy.sh
chmod +x deploy.sh
CONFIG_FILE=./deployment_config.yml ./deploy.sh auto
```

## Method Comparison

| Feature | Zero-Touch | Quick Setup | Advanced | Manual |
|---------|------------|-------------|-----------|---------|
| **Questions** | 3 | 5 | 0* | Many |
| **Time to start** | 30 seconds | 2 minutes | 5 minutes | 30+ minutes |
| **Auto-detection** | ✅ Everything | ✅ Most | ❌ None | ❌ None |
| **Config files** | ❌ None | ❌ None | ✅ Manual | ✅ Manual |
| **Networking** | ✅ Auto | ✅ Auto | ⚠️ Manual | ⚠️ Manual |
| **Passwords** | ✅ Secure prompts | ✅ Secure prompts | ⚠️ In files | ✅ Prompts |
| **Customization** | Basic | Medium | Full | Full |
| **Difficulty** | Beginner | Beginner | Advanced | Expert |

*Advanced method uses pre-made config file

**Recommendation**: Use **Zero-Touch** for simplicity, **Quick Setup** for minor customization, **Advanced** for full control.

---

## What You Get

After installation, you'll have a **complete, secure, modern desktop system**:

### 🖥️ Desktop Environment
- **Hyprland** - Modern Wayland compositor with tiling
- **Waybar** - Beautiful status bar with system info
- **Wofi** - Application launcher
- **Mako** - Notification system
- **Kitty** - GPU-accelerated terminal
- **SDDM** - Secure display manager

### 🔒 Security Features
- **UFW Firewall** - Configured and active
- **fail2ban** - Protects against brute force attacks
- **Full disk encryption** - LUKS encryption (if enabled)
- **SSH hardening** - Key-based authentication only
- **Audit logging** - Complete system activity logs
- **Automatic security updates**

### 📦 Applications Ready
- **Firefox** - Web browser
- **Visual Studio Code** - Modern code editor
- **Discord** - Communication
- **Development tools** - Git, Docker, Node.js, Python, Rust, Go
- **System tools** - htop, neovim, tmux, tree
- **Audio/Video** - PipeWire with Bluetooth support

### ⚡ Power & Performance
- **TLP** - Laptop power management
- **Intel GPU optimization** - Hardware acceleration
- **Thermal management** - Keeps laptop cool
- **Fast mirrors** - Optimized package downloads
- **Zram** - Compressed swap for better performance

---

## Post-Installation

After the automated installation completes:

### 1. First Boot
- System reboots automatically
- SDDM login screen appears
- Login with your username and password

### 2. Desktop Tour
```bash
# Open terminal (Super + Return)
kitty

# Launch applications (Super + D)
wofi

# View system info
neofetch

# Check security status
sudo ufw status
sudo fail2ban-client status
```

### 3. Verify Installation
```bash
# Run system health check
./tools/system_info.sh

# Check hardware compatibility
./tools/hardware_checker.sh

# Verify security configuration
sudo ./scripts/security/security_audit.sh
```

---

## Troubleshooting

### Common Issues

**No internet after installation:**
```bash
# Check network status
nmcli device status

# Connect to WiFi
nmcli device wifi connect "SSID" password "password"
```

**Hyprland won't start:**
```bash
# Check logs
journalctl -u sddm
```

**Performance issues:**
```bash
# Check system resources
htop

# Check for errors
dmesg | grep -i error
```

### Getting Help
- Check logs in `/var/log/`
- Review configuration in `~/.config/hypr/`
- Run diagnostic tools in `./tools/`

---

The automation ensures a smooth, secure, and complete installation. You'll have a production-ready system within an hour!

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