# Arch Linux Hyprland Desktop Automation

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff&style=flat)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?logo=wayland&logoColor=000&style=flat)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=fff&style=flat)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A comprehensive Ansible automation system that transforms a minimal Arch Linux installation into a fully-configured Hyprland desktop environment with enterprise-grade security and modern development tools.

## 🚀 Features

### 🖥️ Desktop Environment
- **Hyprland** - Modern Wayland compositor with intelligent tiling
- **Waybar** - Highly customizable status bar
- **Wofi** - Application launcher with search
- **Mako** - Notification daemon
- **Kitty** - GPU-accelerated terminal emulator
- **SDDM** - Display manager with Wayland support

### 🔒 Security & Hardening
- **UFW Firewall** - Configured with restrictive defaults
- **fail2ban** - Intrusion prevention system
- **Audit System** - Comprehensive security logging
- **Kernel Hardening** - Security-focused kernel parameters
- **File Permissions** - Properly secured system files
- **SSH Hardening** - Secure remote access configuration

### 📦 Package Management
- **Pacman** - Official Arch repositories with UK mirrors
- **Yay** - Secure AUR helper with verification
- **Security Scanning** - Package integrity verification
- **Auto-Updates** - Optional automated update system

### 🎵 Audio & Media
- **PipeWire** - Modern audio system with low latency
- **Bluetooth** - Full Bluetooth audio support
- **Hardware Acceleration** - Intel GPU optimization

### 🛠️ Development Tools
- **Visual Studio Code** - Modern code editor
- **Git Configuration** - Development workflow setup
- **Language Support** - Python, Node.js, Rust, Go ready
- **Terminal Tools** - Enhanced CLI experience

## 📋 System Requirements

### Hardware
- **CPU**: x86_64 architecture (Intel/AMD)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 60GB available space
- **Graphics**: Intel GPU (optimized), others supported
- **Network**: Internet connection for initial setup

### Software
- Arch Linux ISO (latest)
- **No SSH keys required** - Automatically generated during setup

### Target Configuration
- **Bootloader**: systemd-boot (UEFI)
- **Filesystem**: ext4 with optional LUKS encryption
- **Swap**: Hybrid zram + hibernation swapfile
- **Locale**: UK mirrors, en_US.UTF-8, AZERTY keyboard
- **Timezone**: Europe/Paris

## 🚀 Quick Start

### 🤖 Fully Automated Installation (Zero Manual Steps!)
**NEW**: Complete automation from ISO to desktop in one command!

```bash
# 1. Boot from Arch Linux ISO
# 2. Run the master automation:

curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/master_auto_deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh auto

# That's it! 30-60 minutes later: Complete Hyprland desktop ready!
```

**Features:**
- 🔧 **Zero configuration** - Smart defaults for everything
- 🌐 **Automatic network** - WiFi/Ethernet auto-detection  
- 💾 **Automated partitioning** - Disk setup with encryption
- 🎨 **Complete desktop** - Hyprland + all applications
- 🔒 **Security hardening** - Firewall, fail2ban, audit
- ✅ **Validation testing** - Comprehensive system verification

### ⚡ Alternative Methods

**Option 1: Semi-Automated (Manual base + Auto desktop)**
```bash
# Install base Arch manually, then run:
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/master_auto_deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh desktop
```

**Option 2: Traditional Approach (Advanced users)**
```bash
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop
make install        # Install Ansible and dependencies
make full-install   # Deploy complete system
```

**Option 3: VirtualBox Testing (Fully Automated)**
```bash
# Boot VM from Arch ISO, then run:
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/testing/auto_vm_test.sh -o vm_test.sh
chmod +x vm_test.sh
./vm_test.sh
```

## 📖 Documentation

### 📚 Quick Links
- **[Installation Guide](docs/installation-guide.md)** - Complete deployment instructions
- **[VirtualBox Testing](docs/virtualbox-testing-guide.md)** - Safe testing environment setup
- **[Implementation Plan](docs/implementation-plan.md)** - Project status and completion checklist
- **[Project Structure](docs/project-structure.md)** - Complete codebase documentation
- **[Security Policy](SECURITY.md)** - Security guidelines and best practices

### 🎯 Available Make Targets
```bash
make help           # Show all available targets
make install        # Install Ansible and dependencies
make bootstrap      # Run initial system setup
make desktop        # Install Hyprland desktop environment
make security       # Apply security hardening
make full-install   # Complete deployment (bootstrap + desktop + security)
make test           # Run validation tests
make status         # Check system status
make backup         # Backup configurations
make clean          # Clean temporary files
```

## 🏗️ Architecture

### 📁 Directory Structure
```
lm_archlinux_desktop/
├── configs/ansible/          # Ansible configuration
│   ├── roles/               # Ansible roles
│   │   ├── base_system/     # Core system setup
│   │   ├── users_security/  # User management & SSH
│   │   ├── hyprland_desktop/# Desktop environment
│   │   ├── aur_packages/    # AUR package management
│   │   └── system_hardening/# Security hardening
│   ├── playbooks/          # Deployment playbooks
│   ├── inventory/          # Host configurations
│   └── group_vars/         # Global variables
├── scripts/                # Utility scripts
├── docs/                   # Documentation
└── ssh/                   # SSH keys for repository access
```

### 🔧 Core Components

#### Ansible Roles
- **base_system** - Locale, packages, services, bootloader, swap
- **users_security** - User creation, SSH hardening, PAM configuration
- **hyprland_desktop** - Complete Wayland desktop with applications
- **aur_packages** - Secure AUR management with yay
- **system_hardening** - Firewall, fail2ban, audit, kernel security

#### Playbooks
- **local.yml** - Main playbook with interactive prompts
- **bootstrap.yml** - Initial system configuration
- **desktop.yml** - Desktop environment deployment
- **security.yml** - Security hardening application

## 🎮 Desktop Experience

### ⌨️ Key Bindings
```bash
Super + T           # Terminal (Kitty)
Super + R           # Application launcher (Wofi)
Super + E           # File manager (Thunar)
Super + Q           # Close window
Super + L           # Lock screen
Super + F           # Fullscreen toggle
Super + 1-9         # Switch workspaces
Super + Shift + 1-9 # Move window to workspace
```

### 🎨 Theming
- **GTK Theme**: Adwaita Dark
- **Icon Theme**: Papirus Dark
- **Cursor Theme**: Bibata
- **Font**: JetBrains Mono
- **Color Scheme**: Catppuccin Mocha (terminal)

## 🔒 Security Features

### 🛡️ Network Security
- UFW firewall with deny-by-default policy
- fail2ban monitoring SSH, HTTP, and custom services
- Network security kernel parameters
- Secure SSH configuration

### 📊 System Monitoring
- Comprehensive audit logging
- File integrity monitoring
- SUID/SGID file tracking
- Security audit scripts

### 🔐 Access Control
- Restricted sudo configuration
- Secure file permissions
- PAM security policies
- User session management

## 🧪 Testing

### Pre-Production Testing
1. **VirtualBox VM** - Safe testing environment
2. **Component Testing** - Individual role validation
3. **Integration Testing** - Full system deployment
4. **Security Testing** - Hardening verification

### Validation Scripts
```bash
/usr/local/bin/ufw-status           # Firewall status
/usr/local/bin/fail2ban-status      # Intrusion prevention
/usr/local/bin/audit-analysis       # Security audit
/usr/local/bin/permission-audit     # File permissions
```

## 🔧 Maintenance

### Regular Maintenance
```bash
# System updates
sudo pacman -Syu                    # Official packages
yay -Sua                           # AUR packages

# Security monitoring
sudo /usr/local/bin/audit-analysis  # Security events
sudo fail2ban-client status        # Banned IPs

# System health
make status                        # Overall status
make backup                        # Configuration backup
```

### AUR Package Management
```bash
~/.local/bin/aur-backup            # Backup AUR packages
~/.local/bin/aur-cleanup           # Clean package cache
~/.local/bin/aur-security-audit    # Security audit
```

## 🤝 Contributing

### Development Setup
```bash
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop
make dev-setup      # Install development tools
make lint          # Run code quality checks
```

### Contribution Guidelines
1. Test changes in VirtualBox VM first
2. Follow Ansible best practices
3. Update documentation for new features
4. Ensure security considerations are addressed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Arch Linux** community for the excellent documentation
- **Hyprland** developers for the amazing Wayland compositor
- **Ansible** for the powerful automation framework
- **Catppuccin** for the beautiful color schemes

## 📞 Support

### Getting Help
- **Documentation**: Check `docs/` directory
- **Issues**: Create GitHub issue with logs and system info
- **Testing**: Use VirtualBox testing guide for safe experimentation

### Useful Resources
- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [Hyprland Documentation](https://hyprland.org/)
- [Ansible Documentation](https://docs.ansible.com/)

---

**Transform your Arch Linux installation into a modern, secure, and beautiful desktop environment with just a few commands!** 🚀