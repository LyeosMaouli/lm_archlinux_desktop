# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚀 **REVOLUTIONARY PROJECT OVERVIEW**

This is a **revolutionary enterprise-grade Arch Linux automation system** that has evolved far beyond basic desktop automation. It features **advanced password management**, **USB deployment system**, and **zero-touch deployment** capabilities that eliminate common deployment challenges.

### 🎯 **Core Mission**
Transform a minimal Arch Linux installation into a fully-configured Hyprland desktop environment using **cutting-edge automation technologies** and **enterprise-grade security**.

### ✨ **Revolutionary Features**

#### 🔒 **Advanced Hybrid Password Management System**
- **4 Secure Methods**: Environment variables, AES-256 encrypted files, auto-generation, interactive
- **PBKDF2 Encryption**: Military-grade security for password files
- **Enterprise CI/CD Integration**: GitHub Actions workflows with secure password storage
- **Multiple Delivery Options**: Email, QR codes, secure file storage

#### 📱 **USB Deployment System** *(GAME CHANGER)*
- **Zero Console Typing**: Edit config on main PC, deploy with no typing errors
- **Pre-configured Scripts**: All settings configured before deployment
- **Error-Free Deployment**: Eliminates human error in manual command entry
- **Universal Compatibility**: Works with any USB stick and target computer

#### 🌟 **Zero-Touch Deployment**
- **3-Question Setup**: Username, hostname, encryption preference
- **Auto-Detection**: Timezone, keyboard, hardware, best mirrors
- **Smart Networking**: Ethernet auto-connect, WiFi setup if needed
- **Complete Automation**: From ISO to desktop in 30-60 minutes

#### 🤖 **Enterprise CI/CD Integration**
- **GitHub Actions Workflows**: Complete automation pipeline
- **Secure Password Storage**: GitHub Secrets integration
- **Remote Deployment**: Deploy to multiple targets from repository
- **Audit Trail**: Complete deployment logging and validation

## 📁 **Current Repository Structure**

```
lm_archlinux_desktop/
├── 📄 README.md                     # Revolutionary project overview
├── 📄 CLAUDE.md                     # This file - Claude guidance
├── 📄 SECURITY.md                   # Security policies and guidelines
├── 📄 local.yml                     # Main Ansible playbook (ansible-pull entry point)
├── 📄 Makefile                      # Build automation and shortcuts
│
├── 📂 docs/                         # 📚 Comprehensive Documentation
│   ├── 📄 installation-guide.md     # Complete installation methods
│   ├── 📄 password-management.md    # Advanced password system guide
│   ├── 📄 github-password-storage.md # GitHub Secrets integration
│   ├── 📄 target-computer-deployment.md # Target deployment workflow
│   ├── 📄 project-structure.md      # Complete project overview
│   └── 📄 virtualbox-testing-guide.md # VM testing environment
│
├── 📂 configs/ansible/              # 🔧 Ansible Automation Framework
│   ├── 📂 roles/                    # Core automation roles
│   │   ├── 📂 base_system/          # Core system configuration
│   │   ├── 📂 users_security/       # User management & SSH hardening
│   │   ├── 📂 hyprland_desktop/     # Wayland desktop environment
│   │   ├── 📂 aur_packages/         # AUR package management
│   │   ├── 📂 system_hardening/     # Security hardening
│   │   └── 📂 power_management/     # Laptop power optimization
│   └── 📂 playbooks/               # Deployment orchestration
│
├── 📂 scripts/                      # 🚀 Revolutionary Automation Scripts
│   ├── 📂 deployment/              # Main deployment systems
│   │   ├── 📄 auto_install.sh       # Base system installation
│   │   ├── 📄 auto_network_setup.sh # Network configuration
│   │   └── 📄 profile_manager.sh    # Profile management utility
│   ├── 📂 security/                 # System security hardening
│   │   ├── 📄 firewall_setup.sh     # UFW firewall configuration
│   │   ├── 📄 fail2ban_setup.sh     # Intrusion prevention system
│   │   └── 📄 system_hardening.sh   # Comprehensive security hardening
│   ├── 📂 testing/                  # Testing & validation
│   ├── 📂 maintenance/              # System maintenance
│   └── 📂 utilities/                # System utilities
│
├── 📂 usb-deployment/               # 📱 Revolutionary USB Deployment System
│   ├── 📄 usb-deploy.sh             # Main USB deployment script
│   └── 📂 examples/                 # Configuration examples
│
├── 📂 tools/                        # 🔧 System Management Tools
├── 📂 templates/                    # 📝 Jinja2 Configuration Templates
├── 📂 files/                        # 📄 Static Files and Assets
├── 📂 examples/                     # 📖 CI/CD and Configuration Examples
└── 📂 profiles/                     # 📋 Deployment Profiles (work/personal/dev)
```

## 🎯 **Key Architecture Decisions**

### Target System Configuration
- **Hardware**: Work laptop with Intel GPU (optimized for business use)
- **Bootloader**: systemd-boot (modern UEFI, NOT GRUB)
- **Filesystem**: ext4 with LUKS encryption (security + performance)
- **Swap**: zram + hibernation swapfile hybrid (memory optimization)
- **Desktop**: Hyprland Wayland compositor (modern, efficient, NOT KDE/Plasma)
- **Audio**: PipeWire (low-latency, professional audio)
- **Network**: NetworkManager (enterprise-grade networking)

### Localization Standards
- **Region**: Auto-detected fastest package mirrors
- **Locale**: English (en_US.UTF-8)
- **Keyboard**: AZERTY layout (fr keymap)
- **Timezone**: Europe/Paris
- **Default System**: Hostname "phoenix", user "lyeosmaouli"

## 📦 **Critical Package Requirements**

### Core Hyprland Ecosystem (NOT KDE/Plasma)
- **Desktop Components**: `hyprland`, `waybar`, `wofi`, `mako`, `kitty`, `thunar`
- **Wayland Support**: `xdg-desktop-portal-hyprland`, `qt5-wayland`, `qt6-wayland`
- **Graphics**: `mesa`, `intel-media-driver`, `vulkan-intel`
- **Audio**: `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`

### Essential Applications
- **AUR Packages**: `visual-studio-code-bin`, `discord`, `zoom`, `hyprpaper`
- **Development**: Git, Python, Node.js, Docker support
- **Security**: UFW, fail2ban, audit tools

## 🛠️ **Revolutionary Development Workflows**

### Primary Deployment Methods

#### 1. USB Deployment (RECOMMENDED)
```bash
# Edit usb-deployment/usb-deploy.sh configuration
# Copy to USB stick, boot target computer from Arch ISO
mount /dev/sdX1 /mnt/usb && cd /mnt/usb
./usb-deploy.sh
```

#### 2. Zero-Touch Installation
```bash
# Single command deployment
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git && cd lm_archlinux_desktop && ./scripts/deploy.sh full
```

#### 3. Enterprise CI/CD
```bash
# Using GitHub Secrets
export DEPLOY_USER_PASSWORD="secure_password"
./scripts/deploy.sh full --password env
```

### Password Management Commands
```bash
# Create encrypted password file
./scripts/utils/passwords.sh create-file passwords.enc

# Deploy with different password modes
./scripts/deploy.sh full --password file --password-file passwords.enc
./scripts/deploy.sh full --password generate
./scripts/deploy.sh full --password interactive
```

### Testing and Validation
```bash
# Run comprehensive validation
./scripts/testing/test_installation.sh
./scripts/testing/test_desktop.sh
./scripts/testing/test_security.sh

# VirtualBox automated testing
./scripts/testing/auto_vm_test.sh

# System health monitoring
./scripts/maintenance/health_check.sh
```

### Traditional Ansible (Advanced Users)
```bash
# Full system deployment
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/site.yml

# Specific components
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/desktop.yml
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/security.yml
```

## 🔒 **Security Framework**

### Multi-Layered Security Implementation
- **LUKS Full Disk Encryption**: Military-grade data protection
- **UFW Firewall**: Restrictive defaults with intelligent rules
- **fail2ban**: Advanced intrusion prevention system
- **System Hardening**: Kernel parameters and sysctl optimization
- **SSH Hardening**: Secure remote access configuration
- **Audit Logging**: Comprehensive security event tracking
- **Password Encryption**: AES-256 with PBKDF2 key derivation

### Password Security Standards
- **Environment Variables**: Secure for CI/CD environments
- **Encrypted Files**: AES-256 encryption with secure key derivation
- **Auto-Generation**: Cryptographically secure password generation
- **Interactive Mode**: Secure prompting with no storage

## 🎨 **Template System**

### Dynamic Configuration Management
- **Systemd Templates**: `templates/systemd/` - Service and timer files
- **Network Templates**: `templates/network/` - WiFi and network configuration
- **Security Templates**: `templates/security/` - Firewall and audit rules
- **Desktop Templates**: `templates/desktop/` - Hyprland and Waybar configuration
- **Role Templates**: Template files in each role directory for application configs
- **Hardware Detection**: Dynamic configuration based on detected hardware

## 🔄 **Development Guidelines**

### Code Quality Standards
- **Idempotency**: All roles must be safe to re-run multiple times
- **Error Handling**: Comprehensive error handling in all scripts
- **Ansible Handlers**: Proper service restart handling
- **Variable Parameterization**: All templates parameterized via variables
- **Meaningful Tags**: Include tags for selective execution
- **Directory Structure**: Follow established patterns when adding components
- **Testing Required**: Test all changes with provided validation scripts

### Security Requirements
- **No Hardcoded Secrets**: Use password management system
- **Secure Defaults**: All configurations use security-first approach
- **File Permissions**: Proper permissions on all created files
- **Audit Trail**: Log all security-relevant operations

## 🎯 **Interactive Features**

### Automated Prompting System
- **LUKS Encryption**: Secure passphrase prompting
- **User Passwords**: Secure password configuration
- **Root Password**: Administrative access setup
- **WiFi Credentials**: Network configuration if needed
- **Confirmation Dialogs**: Critical operation verification

## 📋 **Profile Management System**

### Available Profiles
- **work/**: Work laptop configuration with business applications
- **personal/**: Personal system setup with multimedia focus
- **development/**: Development environment with full toolchain

### Profile Components
- **archinstall.json**: Profile-specific installation configuration
- **ansible-vars.yml**: Environment-specific variables
- **packages.yml**: Profile-specific package lists

## 🔧 **System Tools & Utilities**

### Management Tools
- **system_info.sh**: Comprehensive system information display
- **package_manager.sh**: Unified pacman/AUR package management
- **hardware_checker.sh**: Hardware compatibility validation
- **backup_manager.sh**: Complete backup and restore system

### Maintenance Scripts
- **health_check.sh**: System health monitoring
- **update_system.sh**: Automated system updates
- **cleanup_system.sh**: System cleanup and optimization
- **analyze_logs.sh**: Log analysis and error extraction

## 🚀 **Automation Philosophy**

### Core Principles
- **Minimal User Interaction**: Everything should be automated
- **Error Prevention**: Eliminate human error through automation
- **Security First**: All automation includes security considerations
- **Enterprise Ready**: Suitable for business and enterprise deployment
- **Flexibility**: Multiple deployment methods for different scenarios

### Implementation Standards
- **Zero-Touch Deployment**: Answer minimal questions, automate everything else
- **Password Management**: Secure, flexible password handling
- **Hardware Detection**: Automatic hardware optimization
- **Network Intelligence**: Smart network configuration
- **Validation**: Comprehensive post-deployment verification

## 📚 **Documentation Standards**

### Current Documentation
- **installation-guide.md**: Complete deployment methods including USB system
- **password-management.md**: Advanced password system documentation
- **github-password-storage.md**: Enterprise CI/CD setup guide
- **target-computer-deployment.md**: Target deployment workflows
- **project-structure.md**: Complete codebase overview
- **virtualbox-testing-guide.md**: VM testing environment setup

### Documentation Requirements
- **Keep Updated**: Always reflect current project capabilities
- **Revolutionary Features**: Prominently feature cutting-edge capabilities
- **Enterprise Focus**: Emphasize business and enterprise use cases
- **Security Emphasis**: Highlight security features and best practices

## ⚡ **Performance & Power Management**

### Laptop Optimization
- **TLP Integration**: Advanced power management
- **Intel GPU Optimization**: Hardware-specific tuning
- **Thermal Management**: Temperature monitoring and control
- **CPU Frequency Scaling**: Performance and efficiency balance

## 🔍 **Troubleshooting Guidelines**

### Common Issues
- **Network Configuration**: Auto-detection and fallback mechanisms
- **Hardware Compatibility**: Validation scripts for compatibility checking
- **Password Management**: Multiple secure methods for different scenarios
- **VM Testing**: Safe testing environment for validation

### Support Resources
- **VirtualBox Testing**: Complete VM testing framework
- **Log Analysis**: Automated log analysis and error extraction
- **Hardware Validation**: Comprehensive compatibility checking
- **Documentation**: Complete troubleshooting guides

## 🎯 **Current Project Status**

### Implementation Status: **100% COMPLETE**
- ✅ **Core Infrastructure**: All critical components implemented
- ✅ **Revolutionary Features**: All advanced features operational
- ✅ **Documentation**: Comprehensive and up-to-date
- ✅ **Testing Framework**: Complete validation system
- ✅ **Security Implementation**: Enterprise-grade security active
- ✅ **Power Management**: Advanced laptop optimization
- ✅ **Enterprise Integration**: GitHub CI/CD workflows ready

### Ready For
- ✅ **Production Deployment**: Enterprise-grade reliability
- ✅ **Enterprise Use**: Business environment deployment
- ✅ **Educational Use**: Learning and demonstration
- ✅ **Development**: Further feature development

This project represents a **revolutionary advancement** in Linux automation, combining cutting-edge deployment technologies with enterprise-grade security and user experience innovations.