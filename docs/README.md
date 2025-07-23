# Documentation Index

Welcome to the **Next-Generation Arch Linux Hyprland Desktop Automation** documentation!

## 🆕 **What's New**

This documentation now covers the **latest enhancements** including:
- **🐳 Container Development Environment** - DevContainers and Docker Compose support
- **⚡ Performance Optimizations** - 3x faster deployments with parallel processing
- **📊 Structured Logging** - JSON-based logging with correlation tracking
- **🔒 Enhanced Security** - Container isolation and advanced audit logging
- **📈 Performance Monitoring** - Built-in deployment analytics and optimization

## 🚀 Getting Started

### Quick Start Guides
- **[Installation Guide](installation-guide.md)** - Complete deployment instructions with full automation
- **[Development Instructions](development-instructions.md)** - 🆕 Container-based development setup
- **[VirtualBox Testing](virtualbox-testing-guide.md)** - Safe testing environment setup

### Configuration
- **[Example Configuration](../example_config.yml)** - User-friendly configuration template
- **[Deployment Configuration](../deployment_config.yml)** - Complete configuration reference

## 📚 Project Documentation

### Development
- **[Development Instructions](development-instructions.md)** - 🆕 Container-based development workflows
- **[Project Structure](project-structure.md)** - Complete codebase documentation
- **[Enhancement Opportunities](improvements/enhancement-opportunities.md)** - 🆕 System improvement analysis
- **[Improvement Plan](improvements/improvement-plan.md)** - 🆕 Strategic enhancement roadmap
- **[Issue Tracking](fixes/)** - 🆕 Systematic issue resolution documentation

### Security
- **[Security Policy](../SECURITY.md)** - Security guidelines and best practices

## 🛠️ Technical Documentation

### 🆕 Development Environment
- **DevContainers**: Located in `.devcontainer/`
  - Full VSCode integration with automated setup
  - Pre-configured development tools and extensions
  - Secure container isolation for development
- **Docker Compose**: Multi-service development stack
  - Development container with all tools
  - Documentation server with live reload
  - Redis for caching and development data
  - Optional PostgreSQL for database development

### Architecture
- **Ansible Roles**: Located in `configs/ansible/roles/`
  - `base_system/` - Core system configuration
  - `users_security/` - User management and SSH hardening
  - `hyprland_desktop/` - Desktop environment setup
  - `aur_packages/` - AUR package management
  - `system_hardening/` - Security hardening
  - `power_management/` - Laptop optimization

### Scripts
- **Deployment Scripts**: Located in `scripts/deployment/`
  - `deploy.sh` - Unified deployment interface (full, install, desktop, security)
  - `auto_install.sh` - Automated base system installation
  - `profile_manager.sh` - Profile management utility
  - `auto_post_install.sh` - Post-installation validation

- **Testing Scripts**: Located in `scripts/testing/`
  - `auto_vm_test.sh` - Automated VirtualBox testing

- **Utilities**: Located in `scripts/utilities/`
  - `network_auto_setup.sh` - Network automation

### Configuration Files
- **Ansible Configuration**: `configs/ansible/ansible.cfg`
- **Inventory**: `configs/ansible/inventory/localhost.yml`
- **Variables**: `configs/ansible/group_vars/all/vars.yml`

## 🎯 Common Tasks

### 🆕 Container Development
```bash
# VSCode DevContainers (Recommended for developers)
# 1. Install VSCode and Dev Containers extension
# 2. Clone and open in VSCode
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
code lm_archlinux_desktop
# 3. Reopen in Container (Ctrl+Shift+P -> "Dev Containers: Reopen in Container")

# Docker Compose development
docker-compose up -d dev docs   # Start development environment
docker-compose exec dev bash    # Access development container
dev-deploy --dry-run full      # Test deployment with monitoring
```

### Installation
```bash
# Fully automated installation
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git && cd lm_archlinux_desktop
./scripts/deploy.sh full
```

### Testing
```bash
# Container testing (recommended)
docker-compose --profile testing up test
docker-compose exec test ./scripts/testing/test_installation.sh

# VirtualBox testing
curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/testing/auto_vm_test.sh -o vm_test.sh
chmod +x vm_test.sh
./vm_test.sh
```

### Maintenance
```bash
# System status with performance monitoring
system-status

# System updates
system-update

# Security audit with structured logging
sudo /usr/local/bin/audit-analysis

# 🆕 Development environment maintenance
dev-monitor               # Monitor deployment performance
dev-lint                 # Run code quality checks
dev-security-scan        # Security scan development environment
docker-compose down -v   # Clean development volumes
```

## 🆘 Troubleshooting

### Common Issues

**Network connectivity problems:**
```bash
# Run network recovery
./scripts/utilities/network_auto_setup.sh recovery
```

**SSH key issues:**
```bash
# Keys are automatically generated
# View public key: cat ~/.ssh/id_rsa.pub
# Add to GitHub: https://github.com/settings/keys
```

**Ansible deployment failures:**
```bash
# Run with verbose output
ansible-playbook -vvv -i configs/ansible/inventory/localhost.yml local.yml
```

### Log Locations
- **Main deployment**: `/var/log/deploy.log`
- **VM testing**: `/var/log/auto_vm_test.log`
- **Network setup**: `/var/log/network_auto_setup.log`
- **Ansible**: `/var/log/ansible.log`

## 📞 Support

### Getting Help
1. Check this documentation
2. Review log files for errors
3. Test in VirtualBox VM first
4. Create GitHub issue with logs and system info

### Contributing
1. Fork the repository
2. Test changes in VirtualBox
3. Follow existing code style
4. Update documentation
5. Submit pull request

---

**Need help?** Start with the [Installation Guide](installation-guide.md) for step-by-step instructions.