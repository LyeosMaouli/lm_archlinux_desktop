# lm_archlinux_desktop - TODO List

## 🔴 CRITICAL PRIORITY (Do First)

### Project Structure & Foundation
- [ ] **Reorganize directory structure** to follow Ansible Galaxy standards
- [ ] **Create proper ansible.cfg** with ansible-pull optimizations (connection caching, fact caching)
- [ ] **Fix inventory structure** - convert to proper localhost.yml format
- [ ] **Create requirements.yml** with all necessary collections
- [ ] **Implement proper variable hierarchy** (defaults → group_vars → host_vars)

### Core Security Implementation
- [ ] **Implement LUKS encryption automation** using `community.crypto.luks_device`
- [ ] **Create UFW firewall role** with restrictive default policies
- [ ] **Add fail2ban configuration** for SSH and system services
- [ ] **Implement SSH key management** with automated rotation
- [ ] **Set up Ansible Vault** for secrets management

### Base System Role
- [ ] **Create comprehensive pacman configuration** (parallel downloads, hooks)
- [ ] **Implement AUR helper setup** (yay/paru with proper permissions)
- [ ] **Add system update automation** with safety checks
- [ ] **Configure system services** (NetworkManager, bluetooth, audio)
- [ ] **Set up systemd-boot** with proper kernel parameters

## 🟡 HIGH PRIORITY (Do Next)

### Hyprland Desktop Environment
- [ ] **Install complete Hyprland ecosystem** (compositor + supporting tools)
- [ ] **Configure Waybar** with system integration modules
- [ ] **Set up wofi/rofi** application launcher
- [ ] **Implement mako** notification system
- [ ] **Add hyprpaper** wallpaper management
- [ ] **Configure hypridle** power management
- [ ] **Set up hyprlock** screen locking

### Desktop Integration
- [ ] **Install XDG portals** (xdg-desktop-portal-hyprland)
- [ ] **Configure polkit** authentication agent
- [ ] **Set up PipeWire** audio system
- [ ] **Implement multi-monitor support** with kanshi
- [ ] **Add clipboard management** (wl-clipboard)
- [ ] **Configure file manager** (thunar with proper integration)

### Hardware & Power Management
- [ ] **Implement TLP configuration** for laptop power management
- [ ] **Add brightness control** (brightnessctl integration)
- [ ] **Configure GPU drivers** (Intel/AMD/NVIDIA detection)
- [ ] **Set up thermal management** and CPU scaling
- [ ] **Add Bluetooth automation** (bluez with device management)

## 🟢 MEDIUM PRIORITY (Improvements)

### Code Quality & Structure
- [ ] **Add comprehensive error handling** (block/rescue/always patterns)
- [ ] **Implement proper handlers** for service management
- [ ] **Add input validation** for all variables
- [ ] **Create custom modules** for complex operations
- [ ] **Optimize templates** with conditional logic

### Application Management
- [ ] **Create application installation role** (firefox, vscode, etc.)
- [ ] **Add development tools setup** (git, editors, compilers)
- [ ] **Implement dotfiles management** structure
- [ ] **Add multimedia packages** (VLC with codecs)
- [ ] **Configure printing** (CUPS setup)

### Security Hardening
- [ ] **Implement kernel hardening** (sysctl parameters)
- [ ] **Add audit logging** configuration
- [ ] **Set up intrusion detection** (AIDE, rkhunter)
- [ ] **Configure SSH hardening** beyond key management
- [ ] **Add AppArmor/SELinux** profiles

### Performance & Optimization
- [ ] **Add fact caching** for ansible-pull performance
- [ ] **Implement parallel execution** where possible
- [ ] **Optimize boot time** with systemd analysis
- [ ] **Add memory management** optimization
- [ ] **Configure I/O scheduling** for SSDs

## 🔵 LOW PRIORITY (Nice to Have)

### Advanced Features
- [ ] **Add backup automation** for user data and configs
- [ ] **Implement system monitoring** (metrics collection)
- [ ] **Create update scheduling** with automatic rollback
- [ ] **Add container runtime** (Docker/Podman)
- [ ] **Implement VPN automation** (WireGuard/OpenVPN)

### User Experience
- [ ] **Add interactive configuration** options
- [ ] **Create GUI for common tasks** (optional)
- [ ] **Implement theme management** system
- [ ] **Add accessibility features** configuration
- [ ] **Create system restore points** automation

### Testing & CI/CD
- [ ] **Set up Molecule testing** framework
- [ ] **Create GitHub Actions** CI pipeline
- [ ] **Add integration tests** for all roles
- [ ] **Implement linting** with ansible-lint
- [ ] **Create automated releases** with semantic versioning

### Documentation
- [ ] **Write comprehensive role documentation**
- [ ] **Create troubleshooting guide**
- [ ] **Add architecture decision records** (ADRs)
- [ ] **Create video tutorials** for setup
- [ ] **Add contributing guidelines**

## 🛠️ CURRENT ISSUES TO FIX

### Repository Structure Problems
- [ ] **Fix empty bootstrap.yml** and vault.yml files
- [ ] **Reorganize scattered configuration** files
- [ ] **Merge duplicate role functionality** (system_base vs boot_config)
- [ ] **Fix inconsistent variable naming** across roles
- [ ] **Remove unused/incomplete** role templates

### Template & Configuration Issues
- [ ] **Fix hardcoded values** in templates (replace with variables)
- [ ] **Add missing template variables** validation
- [ ] **Implement proper Jinja2** escaping
- [ ] **Fix keyboard layout** configuration (fr vs us inconsistency)
- [ ] **Add missing handlers** for configuration changes

### Security Vulnerabilities
- [ ] **Remove plaintext SSH keys** from repository
- [ ] **Implement proper secrets** management
- [ ] **Fix file permissions** on sensitive files
- [ ] **Add encryption for** sensitive variables
- [ ] **Implement key rotation** mechanisms

## 📋 IMMEDIATE NEXT STEPS

1. **Start with project restructure** - create proper directory layout
2. **Implement base security** - UFW, fail2ban, SSH hardening
3. **Get basic Hyprland working** - compositor + essential tools
4. **Add comprehensive testing** - ensure changes don't break system
5. **Create documentation** - README with setup instructions

## 🎯 SUCCESS CRITERIA

- [ ] **System boots** into Hyprland desktop environment
- [ ] **All security measures** are active and configured
- [ ] **Package management** works reliably (pacman + AUR)
- [ ] **Power management** optimized for laptop usage
- [ ] **All services** start correctly and are properly configured
- [ ] **Documentation** is comprehensive and up-to-date
- [ ] **Code quality** passes all linting and testing
- [ ] **Secrets management** is secure and automated

---

## 📚 References & Resources

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Hyprland Wiki](https://wiki.hypr.land/)
- [Arch Linux Security](https://wiki.archlinux.org/title/Security)
- [Ansible-Pull Documentation](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html)

**Priority Legend:**
- 🔴 **CRITICAL** - Must be done first, blocks other work
- 🟡 **HIGH** - Important for core functionality
- 🟢 **MEDIUM** - Improves quality and maintainability  
- 🔵 **LOW** - Nice to have, can be deferred