# Arch Linux Hyprland Desktop Automation

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff&style=flat)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?logo=wayland&logoColor=000&style=flat)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=fff&style=flat)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**🚀 DRAMATICALLY SIMPLIFIED ARCH LINUX AUTOMATION** - Transform a minimal Arch Linux installation into a fully-configured Hyprland desktop environment with **enterprise-grade security**, **advanced password management**, and **zero-touch deployment**. Now with a **unified deployment interface** and streamlined codebase!

## 🎯 New Simplified Interface

### One Command, Complete Desktop
```bash
# Complete deployment (replaces 5 different entry points)
./scripts/deploy.sh full

# Step-by-step deployment  
./scripts/deploy.sh install   # Base system
./scripts/deploy.sh desktop   # Desktop environment
./scripts/deploy.sh security  # Security hardening
```

### Dramatically Simplified Architecture
- **Before**: Multiple confusing entry points, scattered functionality
- **After**: Single unified `deploy.sh` interface with clear commands
- **Same Power**: All functionality preserved and enhanced
- **Cleaner Codebase**: Removed 12 deprecated scripts, consolidated password management

## ✨ Revolutionary Features

### 🔒 **Advanced Hybrid Password Management System**
- **4 Secure Methods**: Environment variables, encrypted files, auto-generation, interactive
- **Enterprise CI/CD Integration**: GitHub Actions workflow templates
- **AES-256 Encryption**: PBKDF2 key derivation for password files
- **Email & QR Delivery**: Multiple secure password delivery methods
- **Zero-Touch Deployment**: Complete automation from ISO to desktop

### 📱 **USB Deployment System** *(No More Typing Errors!)*
- **Pre-configured Scripts**: Edit settings on your main computer, deploy on target
- **Zero Console Typing**: No long commands to type in Arch Linux console
- **Error-Free Deployment**: Eliminates human error in manual command entry
- **Multiple Password Modes**: Supports all password management methods

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
- **Pacman** - Official Arch repositories with fastest mirrors
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

### ⚡ Power Management & Performance
- **TLP** - Advanced laptop power management
- **Intel GPU Optimization** - Hardware-specific tuning
- **CPU Frequency Scaling** - Performance and power balance
- **Thermal Management** - Temperature monitoring and control

### 🔧 System Tools & Utilities
- **Comprehensive Hardware Validation** - Compatibility checking
- **Backup & Restore System** - Full system backup with verification
- **Package Management Tools** - Unified pacman/AUR interface
- **System Information Dashboard** - Real-time status monitoring

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
- **Locale**: Fastest mirrors, en_US.UTF-8, AZERTY keyboard
- **Timezone**: Europe/Paris

## 🚀 Quick Start

### 🌟 **Simplified Zero-Touch Installation**
**NOW EVEN EASIER**: The easiest way to get Arch Linux + Hyprland with enterprise-grade security!

#### **Method 1: USB Deployment (🔥 GAME CHANGER - No Typing!)**
```bash
# STEP 1: On your main computer
# - Download usb-deployment/ folder to USB stick
# - Edit usb-deploy.sh configuration section with your preferences
# - Save and safely eject USB

# STEP 2: On target computer
# - Boot from Arch Linux ISO
# - Mount USB: mount /dev/sdX1 /mnt/usb && cd /mnt/usb
# - Run: ./usb-deploy.sh

# THAT'S IT! Zero typing errors, zero command memorization!
# 30-60 minutes later: Complete modern desktop ready!
```

#### **Method 2: Direct Clone and Deploy (Recommended)**
```bash
# 1. Boot from Arch Linux ISO
# 2. Clone and deploy with unified interface:

git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop
./scripts/deploy.sh full

# Answer just 3 questions:
# 👤 Your username
# 💻 Computer name  
# 🔒 Enable encryption? (Y/n)
#
# Everything else is auto-detected!
# Advanced password management handles security automatically!
# 30-60 minutes later: Complete modern desktop ready!
```

#### **Method 3: GitHub CI/CD Pipeline (Enterprise)**
```bash
# Use GitHub Secrets for secure deployment
# Perfect for enterprise environments and remote deployment
# Supports environment variables and encrypted password files
# See docs/github-password-storage.md for complete setup
```

**🎯 What makes it revolutionary:**
- ✅ **USB Deployment**: Edit config on main PC, deploy on target with zero typing
- ✅ **Advanced Password Management**: 4 secure methods with encryption
- ✅ **Auto-detects Everything**: Timezone, keyboard, best disk, hardware
- ✅ **Smart Networking**: Ethernet auto-connect, WiFi setup if needed  
- ✅ **Enterprise Ready**: CI/CD integration, encrypted storage, audit logging
- ✅ **Zero Configuration**: No YAML files to edit manually
- ✅ **Complete Automation**: From ISO to desktop in one command

### 🤖 Advanced Password Management Options

**🔐 Method 1: Environment Variables (CI/CD Integration)**
```bash
export DEPLOY_USER_PASSWORD="secure_password"
export DEPLOY_ROOT_PASSWORD="secure_password"
export DEPLOY_LUKS_PASSPHRASE="encryption_passphrase"
./scripts/deploy.sh full --password env
```

**🗃️ Method 2: Encrypted Password File (AES-256)**
```bash
# Create encrypted file with PBKDF2 key derivation
./scripts/utils/passwords.sh create-file passwords.enc mypassphrase user123 root456 luks789

# Deploy with encrypted file
./scripts/deploy.sh full --password file --password-file passwords.enc
```

**🎲 Method 3: Auto-Generated Passwords (Cryptographically Secure)**
```bash
# Generate cryptographically secure passwords automatically
./scripts/deploy.sh full --password generate

# View generated passwords
./scripts/utils/passwords.sh display
```

**💬 Method 4: Interactive Mode (Traditional)**
```bash
# Interactive prompts for manual password entry
./scripts/deploy.sh full --password interactive
```

**Advanced/Custom (manual config):**
```bash
# Clone repository and use custom configuration
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop
cp config/deploy.conf my_config.conf
# Edit my_config.conf with your settings
./scripts/deploy.sh full --config my_config.conf
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
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop
./scripts/deploy.sh desktop
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
- **[Password Management](docs/password-management.md)** - Advanced password system documentation
- **[GitHub Password Storage](docs/github-password-storage.md)** - Step-by-step guide for storing passwords in GitHub
- **[Target Computer Deployment](docs/target-computer-deployment.md)** - How to deploy on your actual computer using GitHub passwords
- **[USB Deployment Guide](usb-deployment/README.md)** - Easy USB stick deployment with no typing required
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
│   │   ├── system_hardening/# Security hardening
│   │   └── power_management/# Laptop power optimization
│   ├── playbooks/          # Deployment playbooks
│   ├── inventory/          # Host configurations
│   └── group_vars/         # Global variables
├── scripts/                # Utility scripts
│   ├── deployment/         # Main deployment scripts
│   ├── security/           # Password management & security
│   ├── testing/            # Validation and testing
│   ├── maintenance/        # System maintenance
│   └── utilities/          # System utilities
├── usb-deployment/         # USB deployment system
├── tools/                  # System management tools
├── templates/              # Jinja2 configuration templates
├── files/                  # Static files and assets
├── docs/                   # Comprehensive documentation
└── examples/               # CI/CD and configuration examples
```

### 🔧 Core Components

#### Ansible Roles
- **base_system** - Locale, packages, services, bootloader, swap
- **users_security** - User creation, SSH hardening, PAM configuration
- **hyprland_desktop** - Complete Wayland desktop with applications
- **aur_packages** - Secure AUR management with yay
- **system_hardening** - Firewall, fail2ban, audit, kernel security
- **power_management** - TLP, thermal management, Intel GPU optimization

#### Unified Deployment System
- **deploy.sh** - Single unified deployment entry point (replaces 5 scripts)
- **utils/** - Specialized utilities (passwords, network, hardware, validation, profiles)
- **internal/common.sh** - Shared functions library (400+ lines)
- **config/deploy.conf** - Comprehensive configuration (38+ options)

#### Password Management System
- **passwords.sh** (in utils/) - Unified password management system
- **validation.sh** (in utils/) - System validation and health checks
- **create_password_file.sh** - Legacy password file utility (use `passwords.sh create-file`)
- **GitHub CI/CD Integration** - Enterprise deployment workflows

#### Playbooks
- **local.yml** - Main playbook with interactive prompts
- **bootstrap.yml** - Initial system configuration
- **desktop.yml** - Desktop environment deployment
- **security.yml** - Security hardening application
- **maintenance.yml** - System maintenance automation

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