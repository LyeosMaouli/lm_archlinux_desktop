# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚀 **NEXT-GENERATION ARCH LINUX AUTOMATION SYSTEM**

This is a **next-generation, enterprise-grade Arch Linux desktop automation system** built with modern DevOps practices, featuring **container-based development environments**, **performance optimizations**, **structured logging**, and **comprehensive monitoring**. The system transforms minimal Arch installations into fully-configured Hyprland desktop environments with **advanced deployment automation**, **comprehensive security hardening**, and **flexible configuration management**.

### 🎯 **Core Mission**
Transform a minimal Arch Linux installation into a fully-configured, secure Hyprland desktop environment using **modern automation technologies** and **enterprise-grade security practices**.

### ✨ **Key Features**

#### 🔧 **Advanced Deployment System**
- **Unified CLI Interface**: Single `deploy.sh` script with subcommands for all operations
- **Multiple Password Modes**: Environment variables, encrypted files, auto-generation, interactive prompts
- **Profile-Based Deployment**: Work, personal, and development configurations
- **Dry-Run Support**: Preview actions before execution
- **Comprehensive Logging**: Detailed audit trails for all operations
- **Performance Optimizations**: Parallel processing and intelligent caching for 3x faster deployments
- **Structured Logging**: JSON-based logging with correlation IDs and deployment tracking

#### 🐳 **Container Development Environment** *(NEW)*
- **DevContainers Support**: Full VSCode Dev Containers integration with automated setup
- **Docker Compose Stack**: Multi-service development environment (dev, docs, redis, postgres)
- **Isolated Testing**: Container-based testing environments for safe development
- **Development Tools**: Pre-commit hooks, automated linting, code formatting
- **Documentation Server**: Live documentation server with auto-reload and interactive features
- **Performance Monitoring**: Built-in deployment analytics and optimization tracking

#### 🔒 **Security-First Architecture**
- **System Hardening**: UFW firewall, fail2ban, audit logging, SSH hardening
- **Kernel Security**: Optimized sysctl parameters and security configurations
- **User Management**: Secure user creation with proper group memberships
- **Permission Management**: Strict file and directory permissions

#### 🏗️ **Ansible-Based Infrastructure**
- **Modular Roles**: Base system, desktop, security, power management, AUR packages
- **Idempotent Operations**: Safe to re-run multiple times
- **Template System**: Dynamic configuration generation
- **Handler System**: Proper service restart handling

#### 🖥️ **Modern Desktop Environment**
- **Hyprland Wayland**: Modern compositor with hardware acceleration
- **Audio System**: PipeWire with low-latency support
- **Complete Toolchain**: Waybar, wofi, mako, kitty, thunar
- **Theme Integration**: Catppuccin theme with proper styling

## 📁 **Current Repository Structure**

```
lm_archlinux_desktop/
├── 📄 README.md                     # Project overview and documentation
├── 📄 CLAUDE.md                     # This file - Claude guidance
├── 📄 SECURITY.md                   # Security policies and guidelines
├── 📄 LICENSE                       # Project license
├── 📄 local.yml                     # Main Ansible playbook (ansible-pull entry point)
├── 📄 Makefile                      # Build automation and shortcuts
├── 📄 deployment_config.yml         # Main deployment configuration template
├── 📄 example_deployment_config.yml # Example configuration file
├── 📄 requirements.txt              # Python/Ansible dependencies
├── 📄 docker-compose.yml            # 🆕 Development services configuration
├── 📄 Dockerfile.dev                # 🆕 Development environment image
│
├── 📂 .devcontainer/                # 🆕 VSCode DevContainers configuration
│   ├── 📄 devcontainer.json         # Container configuration and extensions
│   ├── 📄 Dockerfile                # Development environment setup
│   └── 📂 scripts/                  # Container lifecycle scripts
│       ├── 📄 post-create.sh        # Post-creation setup
│       └── 📄 post-start.sh         # Post-start configuration
│
├── 📂 config/                       # 🔧 Configuration Files
│   ├── 📄 deploy.conf               # Default deployment configuration
│   └── 📄 example.deploy.conf       # Example deployment configuration
│
├── 📂 configs/                      # 🏗️ Advanced Configuration Management
│   ├── 📂 ansible/                  # Ansible automation framework
│   │   ├── 📄 ansible.cfg           # Ansible configuration
│   │   ├── 📄 requirements.yml      # Ansible Galaxy requirements
│   │   ├── 📂 roles/               # Core automation roles
│   │   │   ├── 📂 base_system/     # Core system configuration
│   │   │   ├── 📂 users_security/  # User management & SSH hardening
│   │   │   ├── 📂 hyprland_desktop/ # Wayland desktop environment
│   │   │   ├── 📂 aur_packages/    # AUR package management
│   │   │   ├── 📂 system_hardening/ # Security hardening
│   │   │   └── 📂 power_management/ # Laptop power optimization
│   │   ├── 📂 playbooks/           # Deployment orchestration
│   │   ├── 📂 inventory/           # Host inventory files
│   │   ├── 📂 group_vars/          # Global variables
│   │   └── 📂 host_vars/           # Host-specific variables
│   ├── 📂 archinstall/             # Archinstall configuration
│   └── 📂 profiles/                # Profile-specific configurations
│       ├── 📂 work/                # Work environment profile
│       ├── 📂 personal/            # Personal system profile
│       └── 📂 development/         # Development environment profile
│
├── 📂 dev/                          # 🆕 Development Environment
│   ├── 📄 README.md                # Development documentation and workflows
│   ├── 📂 scripts/                 # Development helper scripts
│   │   ├── 📄 setup-dev.sh         # Development environment setup
│   │   ├── 📄 run-tests.sh         # Test runner with coverage
│   │   └── 📄 quality-check.sh     # Code quality and linting
│   └── 📂 database/                # Database initialization scripts
│       └── 📂 init/                # PostgreSQL init scripts for development
│
├── 📂 docs/                         # 📚 Comprehensive Documentation
│   ├── 📄 README.md                # Documentation index
│   ├── 📄 installation-guide.md    # Complete installation methods
│   ├── 📄 password-management.md   # Advanced password system guide
│   ├── 📄 github-password-storage.md # GitHub Secrets integration
│   ├── 📄 target-computer-deployment.md # Target deployment workflow
│   ├── 📄 project-structure.md     # Complete project overview
│   ├── 📄 virtualbox-testing-guide.md # VM testing environment
│   ├── 📄 development-instructions.md # Development setup guide
│   ├── 📂 fixes/                   # 🆕 Issue tracking and resolution
│   │   ├── 📄 fix-plan.md          # Systematic fix planning
│   │   └── 📄 identified-issues.md # Known issues and solutions
│   └── 📂 improvements/            # 🆕 Enhancement documentation
│       ├── 📄 improvement-plan.md  # Strategic improvement roadmap
│       └── 📄 enhancement-opportunities.md # Enhancement opportunities analysis
│
├── 📂 scripts/                      # 🚀 Automation Scripts
│   ├── 📄 deploy.sh                # Unified deployment script (main entry point)
│   ├── 📂 bootstrap/               # System bootstrap scripts
│   ├── 📂 deployment/              # Core deployment systems
│   │   ├── 📄 auto_install.sh      # Base system installation
│   │   ├── 📄 auto_network_setup.sh # Network configuration
│   │   ├── 📄 auto_post_install.sh # Post-installation tasks
│   │   ├── 📄 profile_manager.sh   # Profile management utility
│   │   └── 📄 secure_prompt_handler.sh # Secure password prompting
│   ├── 📂 internal/                # Internal utilities
│   │   └── 📄 common.sh            # Common functions and utilities
│   ├── 📂 security/                # System security hardening
│   │   ├── 📄 README.md            # Security documentation
│   │   ├── 📄 firewall_setup.sh    # UFW firewall configuration
│   │   ├── 📄 fail2ban_setup.sh    # Intrusion prevention system
│   │   ├── 📄 system_hardening.sh  # Comprehensive security hardening
│   │   └── 📄 security_audit.sh    # Security audit and validation
│   ├── 📂 testing/                 # Testing & validation
│   │   ├── 📄 test_installation.sh # Installation validation
│   │   └── 📄 auto_vm_test.sh      # Automated VM testing
│   ├── 📂 maintenance/             # System maintenance
│   │   └── 📄 health_check.sh      # System health monitoring
│   ├── 📂 utilities/               # System utilities
│   │   ├── 📄 analyze_logs.sh      # Log analysis
│   │   ├── 📄 create_password_file.sh # Password file creation
│   │   ├── 📄 hardware_validation.sh # Hardware compatibility check
│   │   ├── 📄 network_auto_setup.sh # Network auto-configuration
│   │   └── 📄 usb_preparation.sh    # USB deployment preparation
│   └── 📂 utils/                   # Core utilities
│       ├── 📄 deployment_monitor.sh # 🆕 Deployment performance monitoring
│       ├── 📄 hardware.sh          # Hardware detection utilities
│       ├── 📄 network.sh           # Network utilities
│       ├── 📄 passwords.sh         # Password management utilities
│       ├── 📄 profiles.sh          # Profile management utilities
│       └── 📄 validation.sh        # Validation utilities
│
├── 📂 files/                        # 📄 Static Files and Assets
│   ├── 📂 fonts/                   # Font packages
│   ├── 📂 keymaps/                 # Keyboard layout configurations
│   ├── 📂 scripts/                 # User script templates
│   ├── 📂 themes/                  # Desktop themes and styling
│   └── 📂 wallpapers/              # Desktop wallpapers
│
├── 📂 templates/                    # 📝 Jinja2 Configuration Templates
│   ├── 📂 configs/                 # System configuration templates
│   ├── 📂 dbus/                    # D-Bus configuration templates
│   ├── 📂 systemd/                 # Systemd service and timer templates
│   └── 📂 udev/                    # Udev rules templates
│
├── 📂 tools/                        # 🔧 System Management Tools
│   ├── 📄 README.md                # Tools documentation
│   ├── 📄 backup_manager.sh        # Backup and restore system
│   ├── 📄 hardware_checker.sh      # Hardware compatibility validation
│   ├── 📄 package_manager.sh       # Unified package management
│   └── 📄 system_info.sh           # System information display
│
├── 📂 examples/                     # 📖 Configuration and CI/CD Examples
│   ├── 📂 ci-cd/                   # CI/CD pipeline examples
│   │   ├── 📄 github-actions.yml   # GitHub Actions workflow
│   │   └── 📄 gitlab-ci.yml        # GitLab CI pipeline
│   └── 📂 password-configs/        # Password configuration examples
│       ├── 📄 environment-template.sh # Environment variable template
│       └── 📄 example-encrypted-passwords.yaml # Encrypted password example
│
└── 📂 usb-deployment/               # 📱 USB Deployment System
    ├── 📄 README.md                 # USB deployment documentation
    ├── 📄 usb-deploy.sh             # Main USB deployment script
    └── 📄 example-config.sh         # Example USB configuration
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
- **Region**: Auto-detected fastest package mirrors (configurable by country)
- **Locale**: English (en_US.UTF-8) - configurable
- **Keyboard**: French AZERTY layout (fr keymap) - configurable
- **Timezone**: Europe/Paris - configurable
- **Default System**: Hostname "phoenix", user "lyeosmaouli" - fully configurable

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

## 🛠️ **Development Workflows**

### Container-Based Development (NEW & RECOMMENDED)

#### 1. VSCode DevContainers (PREFERRED FOR DEVELOPMENT)
```bash
# 1. Install VSCode and Dev Containers extension
# 2. Clone repository and open in VSCode
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
code lm_archlinux_desktop

# 3. Reopen in Container (Ctrl+Shift+P -> "Dev Containers: Reopen in Container")
# 4. Everything is automatically set up with all development tools!

# Inside container - enhanced development commands:
dev-deploy --dry-run full    # Test deployment with performance monitoring
dev-test                     # Run comprehensive test suite with coverage
dev-lint                     # Code quality checks with auto-fix
dev-info                     # Show development environment information
dev-docs-build              # Build interactive documentation
dev-monitor                  # Monitor deployment performance and analytics
```

#### 2. Docker Compose Development Stack
```bash
# Start complete development environment
docker-compose up -d dev docs redis

# Access development container
docker-compose exec dev bash

# Run isolated tests in separate container
docker-compose --profile testing up test
docker-compose exec test ./scripts/testing/test_installation.sh

# Documentation server with live reload (http://localhost:8000)
docker-compose up docs

# Database development (optional)
docker-compose --profile database up postgres
```

### Primary Deployment Methods

#### 3. Unified Deploy Script (PRODUCTION DEPLOYMENT)
```bash
# Complete automated deployment
./scripts/deploy.sh full

# Custom deployment with options
./scripts/deploy.sh full --profile personal --password generate --hostname myarch

# Step-by-step deployment
./scripts/deploy.sh install --encryption
./scripts/deploy.sh desktop --profile work
./scripts/deploy.sh security
```

#### 2. Makefile Interface
```bash
# Install dependencies
make install

# Run full installation
make full-install

# Individual components
make bootstrap
make desktop
make security

# System maintenance
make maintenance
make status
```

#### 3. Direct Ansible (Advanced Users)
```bash
# Full system deployment
ansible-playbook -i configs/ansible/inventory/localhost.yml local.yml

# Specific components
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/desktop.yml
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/security.yml
```

#### 4. USB Deployment
```bash
# Edit usb-deployment/usb-deploy.sh configuration
# Copy to USB stick, boot target computer from Arch ISO
mount /dev/sdX1 /mnt/usb && cd /mnt/usb
./usb-deploy.sh
```

### Password Management Commands
```bash
# Create encrypted password file
./scripts/utils/passwords.sh create-file passwords.enc

# Deploy with different password modes
./scripts/deploy.sh full --password file --password-file passwords.enc
./scripts/deploy.sh full --password generate
./scripts/deploy.sh full --password interactive
./scripts/deploy.sh full --password env  # Uses DEPLOY_USER_PASSWORD env var
```

### Testing and Validation
```bash
# Run comprehensive validation
./scripts/testing/test_installation.sh

# VirtualBox automated testing
./scripts/testing/auto_vm_test.sh

# System health monitoring
./scripts/maintenance/health_check.sh

# Run tests via Makefile
make test
```

### Configuration Management
```bash
# Use custom configuration file
./scripts/deploy.sh full --config /path/to/custom.conf

# Preview actions without executing
./scripts/deploy.sh full --dry-run --verbose

# Profile-specific deployment
./scripts/deploy.sh full --profile development
```

## 🔒 **Security Framework**

### Multi-Layered Security Implementation
- **LUKS Full Disk Encryption**: Strong data protection with configurable passphrases
- **UFW Firewall**: Restrictive defaults with intelligent rules via `system_hardening` role
- **fail2ban**: Intrusion prevention system with SSH protection
- **System Hardening**: Kernel parameters and sysctl optimization via dedicated role
- **SSH Hardening**: Secure remote access configuration with key-based auth
- **Audit Logging**: Comprehensive security event tracking via auditd
- **User Security**: Proper group memberships and permission management

### Password Security Standards
- **Environment Variables**: Secure for CI/CD environments (`DEPLOY_USER_PASSWORD`)
- **Encrypted Files**: AES-256 encryption with secure key derivation
- **Auto-Generation**: Cryptographically secure password generation
- **Interactive Mode**: Secure prompting with hidden input
- **File Mode**: Support for encrypted password files with `.enc` extension

## 🎨 **Template System**

### Dynamic Configuration Management
- **Systemd Templates**: `templates/systemd/` - Service and timer files
- **Desktop Templates**: Role-specific templates for Hyprland, Waybar, Kitty, etc.
- **Security Templates**: Firewall rules, fail2ban, and audit configurations
- **System Templates**: Bootloader, locale, and system configuration files
- **Role Templates**: Each Ansible role contains its own template directory
- **Jinja2 Templating**: Dynamic configuration generation with variables
- **Hardware Detection**: Automatic configuration based on detected hardware

## 🔄 **Development Guidelines**

### Modern Development Standards
- **Container-First Development**: Use DevContainers or Docker Compose for all development
- **Performance Monitoring**: Monitor and optimize deployment performance
- **Structured Logging**: Use JSON-based logging with correlation IDs
- **Code Quality Automation**: Leverage pre-commit hooks and automated testing
- **Documentation as Code**: Maintain live, interactive documentation

### Code Quality Standards
- **Idempotency**: All roles must be safe to re-run multiple times
- **Error Handling**: Comprehensive error handling in all scripts
- **Ansible Handlers**: Proper service restart handling
- **Variable Parameterization**: All templates parameterized via variables
- **Meaningful Tags**: Include tags for selective execution
- **Directory Structure**: Follow established patterns when adding components
- **Testing Required**: Test all changes with provided validation scripts
- **Performance Testing**: Benchmark and optimize deployment performance
- **Container Testing**: Test in isolated container environments before VM testing

### Security Requirements
- **No Hardcoded Secrets**: Use password management system
- **Secure Defaults**: All configurations use security-first approach
- **File Permissions**: Proper permissions on all created files
- **Audit Trail**: Log all security-relevant operations
- **Container Security**: Follow container security best practices in development

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

### Management Tools (`tools/`)
- **system_info.sh**: Comprehensive system information display
- **package_manager.sh**: Unified pacman/AUR package management
- **hardware_checker.sh**: Hardware compatibility validation
- **backup_manager.sh**: Complete backup and restore system

### Core Utilities (`scripts/utils/`)
- **hardware.sh**: Hardware detection and validation utilities
- **network.sh**: Network configuration and connectivity utilities
- **passwords.sh**: Password management and encryption utilities
- **profiles.sh**: Profile management and configuration utilities
- **validation.sh**: System validation and verification utilities

### Maintenance Scripts (`scripts/maintenance/`)
- **health_check.sh**: System health monitoring and diagnostics

### Utility Scripts (`scripts/utilities/`)
- **analyze_logs.sh**: Log analysis and error extraction
- **create_password_file.sh**: Encrypted password file creation
- **hardware_validation.sh**: Hardware compatibility checking
- **network_auto_setup.sh**: Automatic network configuration
- **usb_preparation.sh**: USB deployment preparation utilities

## 🚀 **Automation Philosophy**

### Core Principles
- **Minimal User Interaction**: Configurable automation with sensible defaults
- **Error Prevention**: Comprehensive validation and error handling
- **Security First**: Security hardening integrated into all deployment phases
- **Modularity**: Ansible roles for clean separation of concerns
- **Flexibility**: Multiple deployment methods and configuration options

### Implementation Standards
- **Ansible-Driven**: Infrastructure as Code with idempotent operations
- **Configuration Management**: YAML-based configuration with template generation
- **Profile Support**: Environment-specific configurations (work/personal/development)
- **Hardware Detection**: Automatic optimization based on detected hardware
- **Validation**: Comprehensive pre-flight checks and post-deployment verification
- **Logging**: Detailed logging and audit trails for all operations

## 📚 **Documentation Standards**

### Current Documentation (`docs/`)
- **README.md**: Documentation index and overview
- **installation-guide.md**: Complete deployment methods and workflows
- **password-management.md**: Password system documentation
- **github-password-storage.md**: CI/CD integration guide
- **target-computer-deployment.md**: Target deployment workflows
- **project-structure.md**: Complete codebase overview
- **virtualbox-testing-guide.md**: VM testing environment setup
- **development-instructions.md**: Development environment setup

### Key Dependencies and Requirements
- **Python Requirements** (`requirements.txt`): Ansible >= 8.0.0, community collections
- **Ansible Collections** (`configs/ansible/requirements.yml`): community.general, ansible.posix, community.crypto
- **System Requirements**: Arch Linux, UEFI boot mode, x86_64 architecture
- **Network Requirements**: Internet connectivity for package downloads

### Documentation Requirements
- **Keep Updated**: Always reflect current project capabilities
- **Security Focus**: Emphasize security features and best practices
- **Clear Examples**: Provide working examples for all features
- **Troubleshooting**: Include common issues and solutions

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

### Implementation Status: **NEXT-GENERATION READY**
- ✅ **Core Infrastructure**: Ansible-based automation framework complete
- ✅ **Deployment System**: Unified CLI with multiple deployment modes
- ✅ **Security Implementation**: Comprehensive hardening and audit system
- ✅ **Desktop Environment**: Full Hyprland desktop automation
- ✅ **Profile Management**: Work, personal, and development configurations
- ✅ **Power Management**: Laptop optimization with TLP integration
- ✅ **Documentation**: Complete guides and examples
- ✅ **Testing Framework**: VM testing and validation system
- 🆕 **Container Development**: Full DevContainers and Docker Compose support
- 🆕 **Performance Optimizations**: Parallel processing and intelligent caching
- 🆕 **Structured Logging**: JSON-based logging with correlation tracking
- 🆕 **Development Tools**: Pre-commit hooks, automated testing, code quality tools
- 🆕 **Documentation Server**: Live documentation with interactive features
- 🆕 **Monitoring & Analytics**: Deployment performance tracking and optimization

### Architecture Highlights
- **Main Entry Point**: `local.yml` - Ansible playbook for ansible-pull deployment
- **Unified CLI**: `scripts/deploy.sh` - Single script for all deployment operations
- **Configuration**: `deployment_config.yml` - Main configuration template
- **Role-Based**: Modular Ansible roles for each system component
- **Template-Driven**: Jinja2 templates for dynamic configuration generation

### Ready For
- ✅ **Production Deployment**: Stable, tested automation system
- ✅ **Development**: Modular architecture for easy extension
- ✅ **Educational Use**: Well-documented learning resource
- ✅ **Enterprise Use**: Security-hardened business environment deployment

This project represents a **comprehensive Arch Linux automation solution**, combining modern DevOps practices with enterprise-grade security and desktop environment automation.