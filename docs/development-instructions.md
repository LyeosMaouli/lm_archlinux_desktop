# Create a Complete Ansible Pull Automation System for Arch Linux Hyprland Desktop

I need you to create a comprehensive Ansible automation system for managing an Arch Linux desktop with Hyprland. This will use a two-stage approach following infrastructure automation best practices.

## Repository Structure

- **GitHub repo**: https://github.com/LyeosMaouli/lm_archlinux_desktop.git
- **SSH key authentication required**
- **All Ansible files located under**: `/lm_archlinux_desktop/ansible/`

## Architecture Approach

- **Stage 1**: Use archinstall for base system installation (bootable system with SSH access)
- **Stage 2**: Ansible-pull for complete desktop configuration and package management

## System Requirements

### Target Configuration

- **Target Hardware**: Work laptop with Intel GPU
- **Bootloader**: systemd-boot (not GRUB)
- **Filesystem**: ext4 with LUKS encryption
- **Swap**: zram + hibernation swapfile hybrid approach
- **Desktop**: Hyprland (Wayland compositor)
- **Audio**: PipeWire
- **Network**: NetworkManager
- **Kernels**: Both linux and linux-lts

### Localization

- **Region**: UK package mirrors
- **Locale**: English (en_US.UTF-8)
- **Keyboard**: AZERTY layout (fr keymap)
- **Timezone**: Europe/Paris

### System Identity

- **Hostname**: phoenix
- **User**: lyeosmaouli (with sudo access)

## Package Requirements (Corrected List)

### Base System

- base-devel, linux-firmware, networkmanager, sudo, openssh, git, reflector

### Essential CLI Tools

- neovim, tmux, htop, zsh, curl, wget, tree, zip, unzip, trash-cli

### Hyprland Ecosystem (NOT KDE/Plasma)

- hyprland, waybar, wofi, mako, kitty, thunar, grim, slurp, wl-clipboard
- xdg-desktop-portal-hyprland, polkit-gnome, qt5-wayland, qt6-wayland

### Graphics & Audio

- mesa, intel-media-driver, vulkan-intel, pipewire, pipewire-pulse, pipewire-alsa, wireplumber

### Bluetooth

- bluez, bluez-utils, blueman

### Applications

- firefox, thunderbird, libreoffice-still, vlc, okular, cups

### Development

- visual-studio-code-bin (AUR)

### Security & Power Management

- ufw, fail2ban, tlp, acpi

### AUR Packages

- discord, zoom, hyprpaper, bibata-cursor-theme

## Security Configuration

- LUKS full disk encryption with user-prompted passphrase
- UFW firewall with restrictive defaults
- fail2ban for intrusion prevention
- Multi-layered security approach

## Deliverables Required

### 1. Complete Directory Structure

Create the full directory structure under `/ansible/` including all roles, playbooks, and configuration files

### 2. Main Playbook

Create `local.yml` that works with ansible-pull and includes interactive prompts for:

- LUKS encryption passphrase
- User password
- Root password
- Confirmation dialogs for critical operations

### 3. Modular Roles

Create comprehensive roles for:

- **Base system configuration**: Core system setup and optimization
- **User management and security**: User creation, sudo configuration, security hardening
- **Hyprland installation and configuration**: Complete Wayland desktop environment setup
- **Package management**: Both pacman and AUR package installation
- **Network and Bluetooth setup**: Connectivity configuration
- **Power management**: Laptop-specific optimizations
- **Dotfiles management**: Prepare structure for future dotfiles integration

### 4. Template Files

Create Jinja2 templates for:

- Hyprland configuration with dynamic settings
- Waybar configuration for status bar
- SDDM configuration for display manager
- systemd services for automation
- Environment variables for Wayland applications

### 5. Inventory and Variable Files

Organize configuration with proper variable hierarchy for different environments and use cases

### 6. Comprehensive Documentation

Include detailed documentation covering:

- **Installation instructions**: Step-by-step setup guide
- **ansible-pull usage examples**: Practical command examples
- **Role descriptions and customization guide**: How to modify and extend roles
- **Troubleshooting guide**: Common issues and solutions

### 7. SSH Key Integration

Implement secure repository access with SSH key authentication

### 8. Error Handling and Validation

Build robust error handling and validation throughout all roles

## Key Technical Requirements

### Ansible Architecture

- Use ansible-pull architecture for self-bootstrapping capabilities
- Implement idempotent operations that are safe to re-run multiple times
- Build comprehensive error handling and rollback capabilities
- Design modular architecture for easy customization and maintenance
- Create future-proof structure that scales with growing needs
- Ensure clear separation of concerns between different roles
- Include extensive commenting and documentation throughout
- Support both development and production deployment scenarios

### Implementation Standards

- Follow Ansible best practices for role organization and structure
- Include proper handlers for service restarts and configuration changes
- Use templates for dynamic configuration generation based on variables
- Implement proper variable precedence hierarchy for flexibility
- Include meaningful tags for selective execution of specific components
- Consider different execution scenarios including first-time installation versus ongoing updates

### Quality and Maintainability

- Create production-ready components with proper testing considerations
- Focus on creating maintainable and scalable system architecture
- Follow infrastructure automation best practices throughout
- Ensure each role can be understood and modified by future maintainers
- Build with extensibility in mind for adding new components later

## Expected Outcome

The final deliverable should be a complete, production-ready Ansible automation system that can transform a minimal Arch Linux installation into a fully-configured Hyprland desktop environment. The system should be robust enough for daily use, flexible enough for customization, and well-documented enough for others to understand and contribute to the project.

This automation should serve as a reference implementation of modern infrastructure automation principles applied to personal computing environments, demonstrating how enterprise-grade automation techniques can enhance personal productivity and system reliability.
