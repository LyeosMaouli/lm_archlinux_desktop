# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Arch Linux desktop automation project that uses Ansible to transform a minimal Arch Linux installation into a fully-configured Hyprland desktop environment. The project follows a two-stage approach:

1. **Stage 1**: archinstall for base system installation (bootable system with SSH access)
2. **Stage 2**: Ansible-pull for complete desktop configuration and package management

## Repository Structure

The project is organized around infrastructure automation best practices:

- `configs/ansible/` - Ansible playbooks, roles, and configuration
- `scripts/` - Automation scripts for deployment, maintenance, and utilities
- `docs/` - Complete project documentation and guides
- `templates/` - Jinja2 templates for system configuration files
- `files/` - Static files (wallpapers, fonts, themes)

## Documentation

- **Main documentation**: See `docs/README.md` for complete index
- **Key guides**: `docs/installation-guide.md`, `docs/project-structure.md`
- **Security**: `SECURITY.md` contains security policies and guidelines

## Key Architecture Decisions

### Target System Configuration
- **Hardware**: Work laptop with Intel GPU
- **Bootloader**: systemd-boot (not GRUB)
- **Filesystem**: ext4 with LUKS encryption
- **Swap**: zram + hibernation swapfile hybrid
- **Desktop**: Hyprland (Wayland compositor, NOT KDE/Plasma)
- **Audio**: PipeWire
- **Network**: NetworkManager

### Localization
- **Region**: UK package mirrors
- **Locale**: English (en_US.UTF-8)
- **Keyboard**: AZERTY layout (fr keymap)
- **Timezone**: Europe/Paris
- **System**: Hostname "phoenix", user "lyeosmaouli"

## Critical Package Requirements

This project specifically targets **Hyprland ecosystem** packages, not KDE/Plasma:
- Core Hyprland: `hyprland`, `waybar`, `wofi`, `mako`, `kitty`, `thunar`
- Wayland support: `xdg-desktop-portal-hyprland`, `qt5-wayland`, `qt6-wayland`
- Graphics: `mesa`, `intel-media-driver`, `vulkan-intel`
- Audio: `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`
- AUR packages: `visual-studio-code-bin`, `discord`, `zoom`, `hyprpaper`

## Ansible Architecture

### Main Playbooks
- `configs/ansible/playbooks/bootstrap.yml` - Initial system setup
- `configs/ansible/playbooks/desktop.yml` - Hyprland desktop installation
- `configs/ansible/playbooks/security.yml` - Security hardening
- `configs/ansible/playbooks/maintenance.yml` - System maintenance tasks

### Key Roles
- `base_system/` - Core system configuration and optimization
- `users_security/` - User management and security hardening
- `hyprland_desktop/` - Complete Wayland desktop environment setup
- `aur_packages/` - AUR package installation with yay
- `system_hardening/` - Security configuration (UFW, fail2ban, etc.)
- `power_management/` - Laptop-specific power optimizations

## Common Development Tasks

### Running Ansible Playbooks
```bash
# Full system deployment
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/site.yml

# Specific components
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/desktop.yml
ansible-playbook -i configs/ansible/inventory/localhost.yml configs/ansible/playbooks/security.yml
```

### Testing and Validation
```bash
# Run validation scripts
./scripts/testing/test_installation.sh
./scripts/testing/test_desktop.sh
./scripts/testing/test_security.sh

# Check system health
./scripts/maintenance/health_check.sh
```

### Deployment Scripts
```bash
# Master deployment script
./scripts/deployment/master_deploy.sh

# Profile-specific deployment
./scripts/deployment/profile_manager.sh work
./scripts/deployment/profile_manager.sh personal
```

## Security Considerations

This project implements multi-layered security:
- LUKS full disk encryption
- UFW firewall with restrictive defaults
- fail2ban for intrusion prevention
- System hardening via kernel parameters and sysctl
- Secure SSH configuration
- Audit logging

## Template System

The project uses Jinja2 templates extensively for dynamic configuration:
- `templates/systemd/` - Systemd service and timer files
- Template files in role directories for application configs
- Dynamic configuration based on hardware detection and user variables

## Development Guidelines

- All roles must be idempotent and safe to re-run
- Use proper Ansible handlers for service restarts
- Template files should be parameterized via variables
- Include meaningful tags for selective execution
- Follow the established directory structure when adding new components
- Test changes with the provided validation scripts

## Interactive Features

The main playbook includes interactive prompts for:
- LUKS encryption passphrase
- User password configuration
- Root password setup
- Confirmation dialogs for critical operations

## Profile Management

The project supports multiple deployment profiles:
- `work/` - Work laptop configuration
- `personal/` - Personal system setup
- `development/` - Development environment

Each profile has its own archinstall and ansible variable configurations.