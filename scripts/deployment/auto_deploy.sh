#!/bin/bash
# Automated Deployment Script for Arch Linux Hyprland Automation
# This script automates the deployment of the complete desktop environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
CONFIG_FILE="${CONFIG_FILE:-$HOME/deployment_config.yml}"
LOG_FILE="/var/log/auto_deploy.log"
INSTALL_DIR="$HOME/lm_archlinux_desktop"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
    log "INFO: $1"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log "WARNING: $1"
}

# Parse YAML configuration
parse_config() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E "^\s*${key}:" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^ *//; s/ *$//' | tr -d '"'
    else
        echo ""
    fi
}

# Parse nested YAML values
parse_nested_config() {
    local section="$1"
    local key="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        awk "/^${section}:/{flag=1; next} /^[a-zA-Z]/{flag=0} flag && /${key}:/{print}" "$CONFIG_FILE" | cut -d':' -f2- | sed 's/^ *//; s/ *$//' | tr -d '"'
    else
        echo ""
    fi
}

# Check network connectivity
check_connectivity() {
    info "Checking network connectivity..."
    
    # Setup network from config if needed
    local wifi_enabled=$(parse_nested_config "network" "enabled")
    local wifi_ssid=$(parse_nested_config "network" "ssid")
    local wifi_password=$(parse_nested_config "network" "password")
    
    # Connect to WiFi if configured and not connected
    if [[ "$wifi_enabled" == "true" ]] && [[ -n "$wifi_ssid" ]] && [[ -n "$wifi_password" ]]; then
        if ! ping -c 1 google.com >/dev/null 2>&1; then
            info "Connecting to WiFi network: $wifi_ssid"
            sudo nmcli device wifi connect "$wifi_ssid" password "$wifi_password" || warn "WiFi connection failed"
        fi
    fi
    
    # Test connectivity
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        info "Internet connectivity confirmed"
    else
        error "No internet connectivity. Please check network configuration."
    fi
}

# Install prerequisites
install_prerequisites() {
    info "Installing prerequisites..."
    
    # Update package database
    sudo pacman -Sy --noconfirm
    
    # Install required packages
    sudo pacman -S --noconfirm --needed python python-pip git
    
    info "Prerequisites installed successfully"
}

# Clone repository
clone_repository() {
    info "Cloning automation repository..."
    
    # Remove existing directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Existing installation directory found, backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Clone repository
    git clone "$REPO_URL" "$INSTALL_DIR" || error "Failed to clone repository"
    
    cd "$INSTALL_DIR"
    info "Repository cloned successfully"
}

# Setup SSH keys
setup_ssh_keys() {
    info "Setting up SSH keys..."
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Generate new SSH keys (no repository keys for security)
    local generate_keys=$(parse_nested_config "development" "generate")
    local key_type=$(parse_nested_config "development" "type")
    local git_username=$(parse_nested_config "development" "username")
    local git_email=$(parse_nested_config "development" "email")
    
    # Default to generating keys if not specified
    if [[ -z "$generate_keys" ]]; then
        generate_keys="true"
    fi
    
    if [[ "$generate_keys" == "true" ]]; then
        if [[ -z "$key_type" ]]; then
            key_type="ed25519"
        fi
        
        # Create comment for key
        local key_comment="$(whoami)@$(hostname)"
        if [[ -n "$git_email" ]]; then
            key_comment="$git_email"
        fi
        
        info "Generating new SSH key pair (type: $key_type)..."
        ssh-keygen -t "$key_type" -C "$key_comment" -f ~/.ssh/id_${key_type} -N ""
        
        # Create symlinks for default key names
        ln -sf ~/.ssh/id_${key_type} ~/.ssh/id_rsa
        ln -sf ~/.ssh/id_${key_type}.pub ~/.ssh/id_rsa.pub
        
        # Set proper permissions
        chmod 600 ~/.ssh/id_${key_type}
        chmod 644 ~/.ssh/id_${key_type}.pub
        chmod 600 ~/.ssh/id_rsa
        chmod 644 ~/.ssh/id_rsa.pub
        
        info "SSH keys generated successfully"
        info "Public key: $(cat ~/.ssh/id_rsa.pub)"
        
        # Configure Git if credentials provided
        if [[ -n "$git_username" ]] && [[ -n "$git_email" ]]; then
            git config --global user.name "$git_username"
            git config --global user.email "$git_email"
            info "Git configured with provided credentials"
        fi
        
        # Create SSH config for GitHub
        cat > ~/.ssh/config << EOF
# GitHub configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_${key_type}
    IdentitiesOnly yes

# Default configuration
Host *
    IdentityFile ~/.ssh/id_${key_type}
    AddKeysToAgent yes
EOF
        chmod 600 ~/.ssh/config
        
        info "SSH configuration created"
        warn "Add your public key to GitHub: https://github.com/settings/keys"
        warn "Public key location: ~/.ssh/id_rsa.pub"
    else
        info "SSH key generation disabled in configuration"
    fi
}

# Install Ansible and dependencies
install_ansible() {
    info "Installing Ansible and dependencies..."
    
    cd "$INSTALL_DIR"
    
    # Install Python dependencies
    pip install --user -r requirements.txt || error "Failed to install Python dependencies"
    
    # Add pip binaries to PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Update shell profile
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    # Verify Ansible installation
    if command -v ansible >/dev/null 2>&1; then
        info "Ansible version: $(ansible --version | head -n1)"
    else
        error "Ansible installation failed"
    fi
    
    # Install Ansible collections
    info "Installing Ansible collections..."
    ansible-galaxy install -r configs/ansible/requirements.yml || warn "Some collections may have failed to install"
    
    info "Ansible installation complete"
}

# Configure automation settings
configure_automation() {
    info "Configuring automation settings..."
    
    cd "$INSTALL_DIR"
    
    # Copy deployment configuration if it exists
    if [[ -f "$CONFIG_FILE" ]] && [[ "$CONFIG_FILE" != "$INSTALL_DIR/deployment_config.yml" ]]; then
        cp "$CONFIG_FILE" "$INSTALL_DIR/deployment_config.yml"
        info "Deployment configuration copied"
    fi
    
    # Create environment file for automation
    cat > "$INSTALL_DIR/.env" << EOF
# Automation Environment Configuration
ANSIBLE_HOST_KEY_CHECKING=False
ANSIBLE_STDOUT_CALLBACK=yaml
ANSIBLE_LOG_PATH=/var/log/ansible.log
CONFIG_FILE=$INSTALL_DIR/deployment_config.yml
EOF
    
    info "Automation configuration complete"
}

# Run deployment based on configuration
run_deployment() {
    info "Starting automated deployment..."
    
    cd "$INSTALL_DIR"
    
    # Source environment
    source .env
    
    local skip_confirmations=$(parse_nested_config "automation" "skip_confirmations")
    local log_level=$(parse_nested_config "automation" "log_level")
    
    # Set verbosity based on log level
    local verbosity=""
    case "$log_level" in
        "debug") verbosity="-vvv" ;;
        "info") verbosity="-v" ;;
        *) verbosity="" ;;
    esac
    
    # Prepare ansible command arguments
    local ansible_args="$verbosity -i configs/ansible/inventory/localhost.yml"
    
    # Add extra vars for automated deployment
    local extra_vars="automated_deployment=true"
    
    if [[ "$skip_confirmations" == "true" ]]; then
        extra_vars="$extra_vars skip_confirmations=true"
    fi
    
    # Check which components to deploy
    local deploy_bootstrap=$(parse_nested_config "automation" "deploy_bootstrap")
    local deploy_desktop=$(parse_nested_config "automation" "deploy_desktop")
    local deploy_security=$(parse_nested_config "automation" "deploy_security")
    
    if [[ -z "$deploy_bootstrap" ]]; then deploy_bootstrap="true"; fi
    if [[ -z "$deploy_desktop" ]]; then deploy_desktop="true"; fi
    if [[ -z "$deploy_security" ]]; then deploy_security="true"; fi
    
    # Run deployment phases
    if [[ "$deploy_bootstrap" == "true" ]]; then
        info "Running bootstrap phase..."
        ansible-playbook $ansible_args configs/ansible/playbooks/bootstrap.yml --extra-vars "$extra_vars" || error "Bootstrap phase failed"
        info "Bootstrap phase completed successfully"
    fi
    
    if [[ "$deploy_desktop" == "true" ]]; then
        info "Running desktop installation phase..."
        ansible-playbook $ansible_args configs/ansible/playbooks/desktop.yml --extra-vars "$extra_vars" || error "Desktop phase failed"
        info "Desktop phase completed successfully"
    fi
    
    if [[ "$deploy_security" == "true" ]]; then
        info "Running security hardening phase..."
        ansible-playbook $ansible_args configs/ansible/playbooks/security.yml --extra-vars "$extra_vars" || error "Security phase failed"
        info "Security phase completed successfully"
    fi
    
    info "All deployment phases completed successfully!"
}

# Post-deployment configuration
post_deployment() {
    info "Running post-deployment configuration..."
    
    # Enable and start essential services
    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now sshd
    
    # Setup automatic login if configured
    local auto_login=$(parse_nested_config "desktop" "auto_login")
    local username=$(parse_nested_config "user" "username")
    
    if [[ "$auto_login" == "true" ]] && [[ -n "$username" ]]; then
        info "Configuring automatic login for user: $username"
        sudo mkdir -p /etc/sddm.conf.d
        sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$username
Session=hyprland
EOF
    fi
    
    # Create desktop shortcuts and favorites
    create_desktop_shortcuts
    
    # Run initial system health check
    run_health_check
    
    info "Post-deployment configuration complete"
}

# Create desktop shortcuts
create_desktop_shortcuts() {
    local username=$(parse_nested_config "user" "username")
    local user_home="/home/$username"
    
    info "Creating desktop shortcuts..."
    
    # Create applications directory
    sudo -u "$username" mkdir -p "$user_home/.local/share/applications"
    
    # Create system information shortcut
    sudo -u "$username" tee "$user_home/.local/share/applications/system-info.desktop" > /dev/null << EOF
[Desktop Entry]
Name=System Information
Comment=View system configuration and status
Exec=kitty -e bash -c 'echo "Arch Linux Hyprland System"; echo "========================"; hostnamectl; echo; free -h; echo; df -h; echo "Press any key to continue..."; read'
Icon=computer
Type=Application
Categories=System;
EOF
    
    info "Desktop shortcuts created"
}

# Run health check
run_health_check() {
    info "Running system health check..."
    
    # Check essential services
    local services=("NetworkManager" "sshd")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            info "Service $service: ✓ Running"
        else
            warn "Service $service: ✗ Not running"
        fi
    done
    
    # Check disk space
    local root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$root_usage" -lt 80 ]]; then
        info "Disk usage: ✓ ${root_usage}% (healthy)"
    else
        warn "Disk usage: ⚠ ${root_usage}% (high)"
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    info "Memory usage: ${mem_usage}%"
    
    info "Health check complete"
}

# Main deployment function
main() {
    info "Starting automated deployment process..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo access."
    fi
    
    # Check for configuration file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Configuration file not found at $CONFIG_FILE"
        if [[ -f "$PWD/deployment_config.yml" ]]; then
            CONFIG_FILE="$PWD/deployment_config.yml"
            info "Using configuration file: $CONFIG_FILE"
        else
            warn "No configuration file found, using defaults"
        fi
    fi
    
    # Deployment steps
    check_connectivity
    install_prerequisites
    clone_repository
    setup_ssh_keys
    install_ansible
    configure_automation
    run_deployment
    post_deployment
    
    info "Automated deployment completed successfully!"
    info "System is ready for use. You may want to reboot to ensure all changes take effect."
    
    # Auto-reboot if configured
    local auto_reboot=$(parse_nested_config "automation" "auto_reboot")
    if [[ "$auto_reboot" == "true" ]]; then
        info "Auto-reboot enabled, rebooting in 10 seconds..."
        countdown "Rebooting" 10
        sudo reboot
    else
        info "Please reboot the system to complete the setup: sudo reboot"
    fi
}

# Countdown function
countdown() {
    local message="$1"
    local seconds="$2"
    
    while [[ $seconds -gt 0 ]]; do
        echo -ne "\r$message in $seconds seconds... "
        sleep 1
        ((seconds--))
    done
    echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi