#!/bin/bash
# Bootstrap Script for Arch Linux Hyprland Automation
# Prepares a fresh Arch Linux installation for automated deployment

set -euo pipefail

# Load common functions if available, otherwise use basic logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../internal/common.sh" ]]; then
    source "$SCRIPT_DIR/../internal/common.sh"
else
    # Basic logging fallback
    if [[ -z "$RED" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        NC='\033[0m' # No Color
    fi
    
    if [[ -z "$LOG_DIR" ]]; then
        LOG_DIR="./logs"
    fi
    mkdir -p "$LOG_DIR"
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d_%H%M%S).log"
    fi
    
    log_info() { echo -e "${GREEN}INFO: $*${NC}" | tee -a "$LOG_FILE"; }
    log_warn() { echo -e "${YELLOW}WARNING: $*${NC}" | tee -a "$LOG_FILE"; }
    log_error() { echo -e "${RED}ERROR: $*${NC}" >&2; echo "ERROR: $*" >> "$LOG_FILE"; exit 1; }
    log_success() { echo -e "${GREEN}[OK] $*${NC}" | tee -a "$LOG_FILE"; }
fi

# Configuration
REPO_URL="https://github.com/LyeosMaouli/lm_archlinux_desktop.git"
INSTALL_DIR="$HOME/lm_archlinux_desktop"
REQUIRED_PACKAGES=("git" "ansible" "python" "python-pip" "base-devel")

# Default values
SKIP_CONFIRMATION=false
VERBOSE=false
PROFILE="work"
SETUP_AUR=true
UPDATE_SYSTEM=true

# Additional logging function for compatibility
debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}DEBUG: $*${NC}" | tee -a "$LOG_FILE"
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap script for Arch Linux Hyprland automation system.
Prepares a fresh Arch Linux installation for automated deployment.

OPTIONS:
    -p, --profile PROFILE      Target deployment profile (work/personal/development/minimal)
    -y, --yes                  Skip confirmation prompts
    -v, --verbose              Enable verbose output
    --no-aur                   Skip AUR helper installation
    --no-update                Skip system update
    -h, --help                 Show this help message

EXAMPLES:
    $0                         # Interactive bootstrap with default settings
    $0 --profile personal -y   # Automated bootstrap for personal profile
    $0 --verbose --no-update   # Verbose bootstrap without system update

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-aur)
                SETUP_AUR=false
                shift
                ;;
            --no-update)
                UPDATE_SYSTEM=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux only"
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "Testing sudo access (you may be prompted for password)..."
        if ! sudo true; then
            log_error "Sudo access required for system operations"
        fi
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_error "Internet connectivity required for package installation"
    fi
    
    log_success "Prerequisites check passed"
}

# Display system information
show_system_info() {
    log_info "System Information:"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Hostname: $(hostnamectl --static)"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  User: $USER"
    echo "  Home: $HOME"
    echo ""
}

# Update system packages
update_system() {
    if [[ "$UPDATE_SYSTEM" == false ]]; then
        log_info "Skipping system update"
        return 0
    fi
    
    log_info "Updating system packages..."
    
    # Update package database
    sudo pacman -Sy --noconfirm
    
    # Upgrade system packages
    if [[ "$SKIP_CONFIRMATION" == true ]]; then
        sudo pacman -Su --noconfirm
    else
        echo -n "Upgrade system packages? [Y/n]: "
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            sudo pacman -Su --noconfirm
        fi
    fi
    
    log_success "System packages updated"
}

# Install required packages
install_required_packages() {
    log_info "Installing required packages..."
    
    local missing_packages=()
    
    # Check which packages are missing
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! pacman -Q "$package" >/dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "All required packages are already installed"
        return 0
    fi
    
    log_info "Installing missing packages: ${missing_packages[*]}"
    
    sudo pacman -S --noconfirm "${missing_packages[@]}"
    
    log_success "Required packages installed"
}

# Setup AUR helper (yay)
setup_aur_helper() {
    if [[ "$SETUP_AUR" == false ]]; then
        log_info "Skipping AUR helper installation"
        return 0
    fi
    
    log_info "Setting up AUR helper (yay)..."
    
    # Check if yay is already installed
    if command -v yay >/dev/null 2>&1; then
        log_success "yay is already installed"
        return 0
    fi
    
    # Clone and build yay
    local yay_dir="/tmp/yay-git"
    
    if [[ -d "$yay_dir" ]]; then
        rm -rf "$yay_dir"
    fi
    
    git clone https://aur.archlinux.org/yay-git.git "$yay_dir"
    cd "$yay_dir"
    makepkg -si --noconfirm
    cd - >/dev/null
    
    # Cleanup
    rm -rf "$yay_dir"
    
    log_success "AUR helper (yay) installed"
}

# Clone automation repository
clone_repository() {
    log_info "Cloning automation repository..."
    
    # Remove existing directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warn "Existing installation directory found: $INSTALL_DIR"
        if [[ "$SKIP_CONFIRMATION" == false ]]; then
            echo -n "Remove existing directory and continue? [y/N]: "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_error "Installation cancelled by user"
            fi
        fi
        rm -rf "$INSTALL_DIR"
    fi
    
    # Clone repository
    git clone "$REPO_URL" "$INSTALL_DIR"
    
    # Make scripts executable
    find "$INSTALL_DIR/scripts" -name "*.sh" -type f -exec chmod +x {} \;
    
    log_success "Repository cloned to: $INSTALL_DIR"
}

# Setup Python virtual environment
setup_python_environment() {
    log_info "Setting up Python environment..."
    
    local venv_dir="$INSTALL_DIR/.venv"
    
    # Create virtual environment
    python -m venv "$venv_dir"
    
    # Activate virtual environment
    source "$venv_dir/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python requirements if they exist
    if [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
        pip install -r "$INSTALL_DIR/requirements.txt"
    fi
    
    # Install Ansible collections
    if [[ -f "$INSTALL_DIR/configs/ansible/requirements.yml" ]]; then
        ansible-galaxy install -r "$INSTALL_DIR/configs/ansible/requirements.yml"
        ansible-galaxy collection install -r "$INSTALL_DIR/configs/ansible/requirements.yml"
    fi
    
    log_success "Python environment configured"
}

# Configure Ansible
configure_ansible() {
    log_info "Configuring Ansible..."
    
    local ansible_cfg="$INSTALL_DIR/configs/ansible/ansible.cfg"
    
    # Verify Ansible configuration exists
    if [[ ! -f "$ansible_cfg" ]]; then
        log_warn "Ansible configuration not found, creating basic configuration"
        
        mkdir -p "$(dirname "$ansible_cfg")"
        cat > "$ansible_cfg" << EOF
[defaults]
inventory = inventory/localhost.yml
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
bin_ansible_callbacks = True

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
    fi
    
    # Test Ansible connectivity
    cd "$INSTALL_DIR"
    if ansible localhost -m ping >/dev/null 2>&1; then
        log_success "Ansible configured and connectivity tested"
    else
        log_warn "Ansible configuration test failed, but continuing..."
    fi
    
    cd - >/dev/null
}

# Setup profile configuration
setup_profile() {
    log_info "Setting up profile configuration: $PROFILE"
    
    local profiles_dir="$INSTALL_DIR/profiles"
    local profile_dir="$profiles_dir/$PROFILE"
    
    # Create profiles directory if it doesn't exist
    mkdir -p "$profiles_dir"
    
    # Create profile directory and configuration if it doesn't exist
    if [[ ! -d "$profile_dir" ]]; then
        mkdir -p "$profile_dir"
        
        # Create basic profile configuration
        cat > "$profile_dir/config.yml" << EOF
---
# Profile Configuration: $PROFILE
# Generated by bootstrap script

profile_name: "$PROFILE"
profile_type: "$(echo "$PROFILE" | tr '[:lower:]' '[:upper:]')"

# System Configuration
system:
  hostname: "phoenix-$PROFILE"
  timezone: "Europe/Paris"
  locale: "en_US.UTF-8"
  keymap: "fr"

# User Configuration
user:
  username: "$USER"
  shell: "/bin/bash"
  groups:
    - wheel
    - audio
    - video
    - network
    - storage

# Desktop Configuration
desktop:
  environment: "hyprland"
  theme: "catppuccin-mocha"
  auto_login: true

# Package Configuration
packages:
  mirrors:
    protocol: "https"
    age: 12
  aur:
    helper: "yay"

# Security Configuration
security:
  firewall:
    enabled: true
  fail2ban:
    enabled: true
  ssh:
    password_auth: false
    root_login: false

# Automation Configuration
automation:
  skip_confirmations: false
  auto_reboot: false
  backup_configs: true
  log_level: "info"
EOF
        
        log_success "Profile configuration created: $profile_dir/config.yml"
    else
        log_success "Profile configuration already exists: $profile_dir"
    fi
}

# Create convenience scripts
create_convenience_scripts() {
    log_info "Creating convenience scripts..."
    
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    # Deploy script
    cat > "$bin_dir/arch-deploy" << EOF
#!/bin/bash
# Convenience script for running the master deployment
cd "$INSTALL_DIR"
exec ./scripts/deploy.sh full "\$@"
EOF
    
    # Maintenance script
    cat > "$bin_dir/arch-maintain" << EOF
#!/bin/bash
# Convenience script for running maintenance
cd "$INSTALL_DIR"
exec ./scripts/deploy.sh security "\$@"
EOF
    
    # Make scripts executable
    chmod +x "$bin_dir/arch-deploy"
    chmod +x "$bin_dir/arch-maintain"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        echo "export PATH=\"\$PATH:$bin_dir\"" >> "$HOME/.bashrc"
        log_info "Added $bin_dir to PATH in .bashrc"
    fi
    
    log_success "Convenience scripts created in $bin_dir"
}

# Display next steps
show_next_steps() {
    echo ""
    echo -e "${BLUE}Bootstrap completed successfully!${NC}"
    echo "======================================"
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Review the profile configuration:"
    echo "   $INSTALL_DIR/profiles/$PROFILE/config.yml"
    echo ""
    echo "2. Run the full deployment:"
    echo "   cd $INSTALL_DIR"
    echo "   ./scripts/deploy.sh full --profile $PROFILE"
    echo ""
    echo "3. Or use the convenience script (after sourcing .bashrc):"
    echo "   source ~/.bashrc"
    echo "   arch-deploy --profile $PROFILE"
    echo ""
    echo -e "${YELLOW}Available deployment modes:${NC}"
    echo "  - full: Complete system setup"
    echo "  - desktop: Desktop environment only"
    echo "  - security: Security hardening only"
    echo "  - maintenance: System maintenance"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo "  - Installation guide: $INSTALL_DIR/docs/installation-guide.md"
    echo "  - Project structure: $INSTALL_DIR/docs/project-structure.md"
    echo "  - Bootstrap log: $LOG_FILE"
    echo ""
}

# Main function
main() {
    echo -e "${BLUE}Arch Linux Hyprland Bootstrap Script${NC}"
    echo "====================================="
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Show system info
    show_system_info
    
    # Confirmation prompt
    if [[ "$SKIP_CONFIRMATION" == false ]]; then
        echo -n "Proceed with bootstrap? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Bootstrap cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    # Start bootstrap process
    log_info "Starting bootstrap process..."
    
    # Update system
    update_system
    
    # Install required packages
    install_required_packages
    
    # Setup AUR helper
    setup_aur_helper
    
    # Clone repository
    clone_repository
    
    # Setup Python environment
    setup_python_environment
    
    # Configure Ansible
    configure_ansible
    
    # Setup profile
    setup_profile
    
    # Create convenience scripts
    create_convenience_scripts
    
    # Show next steps
    show_next_steps
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi