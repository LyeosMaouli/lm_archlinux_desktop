#!/bin/bash
# Profile Manager Script for Arch Linux Hyprland Automation
# Manages deployment profiles and switches between configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILES_DIR="$PROJECT_ROOT/configs/profiles"
CURRENT_PROFILE_FILE="/etc/arch-hyprland-profile"

# Available profiles
AVAILABLE_PROFILES=("work" "personal" "development" "minimal")

# Logging functions
info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [PROFILE]

Profile management for Arch Linux Hyprland automation.

COMMANDS:
    list                List available profiles
    current             Show current active profile
    info PROFILE        Show detailed profile information
    switch PROFILE      Switch to a different profile
    apply PROFILE       Apply profile configuration
    validate PROFILE    Validate profile configuration
    backup              Backup current configuration
    restore PROFILE     Restore from profile backup

PROFILES:
    work               Work laptop (security focused)
    personal           Personal use (multimedia focused)
    development        Development environment
    minimal            Minimal installation

EXAMPLES:
    $0 list
    $0 current
    $0 info work
    $0 switch personal
    $0 apply development

EOF
}

# List available profiles
list_profiles() {
    info "Available Profiles:"
    echo ""
    
    for profile in "${AVAILABLE_PROFILES[@]}"; do
        local profile_dir="$PROFILES_DIR/$profile"
        local profile_vars="$profile_dir/ansible/vars.yml"
        
        if [[ -f "$profile_vars" ]]; then
            local profile_type
            profile_type=$(grep "profile_type:" "$profile_vars" | cut -d'"' -f2 2>/dev/null || echo "Unknown")
            echo -e "  ${CYAN}$profile${NC} - $profile_type"
            
            # Show brief description
            case $profile in
                work)
                    echo "    Security-focused laptop configuration for professional use"
                    ;;
                personal)
                    echo "    Multimedia-focused configuration for personal use"
                    ;;
                development)
                    echo "    Developer-focused configuration with comprehensive tooling"
                    ;;
                minimal)
                    echo "    Minimal installation for testing and basic use"
                    ;;
            esac
        else
            echo -e "  ${YELLOW}$profile${NC} - Configuration missing"
        fi
        echo ""
    done
}

# Show current profile
show_current() {
    if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
        local current
        current=$(cat "$CURRENT_PROFILE_FILE")
        success "Current profile: $current"
        
        # Show when it was applied
        local timestamp
        timestamp=$(stat -c %y "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "Unknown")
        echo "Applied: $timestamp"
    else
        warn "No active profile found"
        echo "Use '$0 apply PROFILE' to set a profile"
    fi
}

# Show profile information
show_profile_info() {
    local profile="$1"
    local profile_dir="$PROFILES_DIR/$profile"
    local profile_vars="$profile_dir/ansible/vars.yml"
    
    if [[ ! -f "$profile_vars" ]]; then
        error "Profile configuration not found: $profile"
    fi
    
    info "Profile Information: $profile"
    echo ""
    
    # Extract key information from profile
    local hostname
    hostname=$(grep "hostname:" "$profile_vars" | cut -d'"' -f2 2>/dev/null || echo "Unknown")
    
    local theme
    theme=$(grep "theme:" "$profile_vars" | cut -d'"' -f2 2>/dev/null || echo "Unknown")
    
    local auto_login
    auto_login=$(grep "auto_login:" "$profile_vars" | awk '{print $2}' 2>/dev/null || echo "Unknown")
    
    echo "Hostname: $hostname"
    echo "Theme: $theme"
    echo "Auto Login: $auto_login"
    echo ""
    
    # Show security settings
    echo "Security Configuration:"
    if grep -q "firewall:" "$profile_vars"; then
        local firewall_enabled
        firewall_enabled=$(awk '/firewall:/,/enabled:/{if(/enabled:/){print $2; exit}}' "$profile_vars" | tr -d '[:space:]')
        echo "  Firewall: $firewall_enabled"
    fi
    
    if grep -q "fail2ban:" "$profile_vars"; then
        local fail2ban_enabled
        fail2ban_enabled=$(awk '/fail2ban:/,/enabled:/{if(/enabled:/){print $2; exit}}' "$profile_vars" | tr -d '[:space:]')
        echo "  Fail2ban: $fail2ban_enabled"
    fi
    echo ""
    
    # Show applications
    echo "Key Applications:"
    if grep -q "aur:" "$profile_vars"; then
        local apps
        apps=$(awk '/aur:/,/packages:/{if(/- /){print "  " $2}}' "$profile_vars" | head -5)
        if [[ -n "$apps" ]]; then
            echo "$apps"
            local app_count
            app_count=$(awk '/aur:/,/packages:/{if(/- /){count++}} END{print count+0}' "$profile_vars")
            if [[ $app_count -gt 5 ]]; then
                echo "  ... and $((app_count - 5)) more"
            fi
        fi
    fi
}

# Validate profile configuration
validate_profile() {
    local profile="$1"
    local profile_dir="$PROFILES_DIR/$profile"
    local profile_vars="$profile_dir/ansible/vars.yml"
    
    info "Validating profile: $profile"
    
    # Check if profile exists
    if [[ ! -d "$profile_dir" ]]; then
        error "Profile directory not found: $profile_dir"
    fi
    
    # Check if vars file exists
    if [[ ! -f "$profile_vars" ]]; then
        error "Profile configuration not found: $profile_vars"
    fi
    
    # Validate YAML syntax
    if command -v python3 >/dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$profile_vars'))" 2>/dev/null; then
            error "Invalid YAML syntax in profile configuration"
        fi
        success "YAML syntax valid"
    else
        warn "Python3 not available, skipping YAML validation"
    fi
    
    # Check required fields
    local required_fields=("profile_name" "system" "user" "desktop")
    for field in "${required_fields[@]}"; do
        if grep -q "^$field:" "$profile_vars"; then
            success "Required field present: $field"
        else
            error "Missing required field: $field"
        fi
    done
    
    success "Profile validation completed: $profile"
}

# Switch profile
switch_profile() {
    local profile="$1"
    
    validate_profile "$profile"
    
    info "Switching to profile: $profile"
    
    # Backup current configuration if it exists
    if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
        local current
        current=$(cat "$CURRENT_PROFILE_FILE")
        info "Creating backup of current profile: $current"
        backup_profile "$current"
    fi
    
    # Apply new profile
    apply_profile "$profile"
    
    success "Profile switched to: $profile"
    info "Reboot recommended to ensure all changes take effect"
}

# Apply profile configuration
apply_profile() {
    local profile="$1"
    
    validate_profile "$profile"
    
    info "Applying profile: $profile"
    
    # Set current profile
    echo "$profile" | sudo tee "$CURRENT_PROFILE_FILE" >/dev/null
    
    # Run Ansible with profile variables
    local profile_vars="$PROFILES_DIR/$profile/ansible/vars.yml"
    
    cd "$PROJECT_ROOT"
    
    if command -v ansible-playbook >/dev/null; then
        ansible-playbook \
            -i "configs/ansible/inventory/localhost.yml" \
            --extra-vars "@$profile_vars" \
            --extra-vars "deployment_profile=$profile" \
            "configs/ansible/playbooks/site.yml"
    else
        warn "Ansible not found, profile set but not applied"
        info "Run the following to apply manually:"
        info "cd $PROJECT_ROOT"
        info "ansible-playbook -i configs/ansible/inventory/localhost.yml --extra-vars @$profile_vars configs/ansible/playbooks/site.yml"
    fi
    
    success "Profile applied: $profile"
}

# Backup current profile
backup_profile() {
    local profile="${1:-$(cat "$CURRENT_PROFILE_FILE" 2>/dev/null || echo "unknown")}"
    local backup_dir="/backup/profile-$profile-$(date +%Y%m%d-%H%M%S)"
    
    info "Creating profile backup: $backup_dir"
    
    sudo mkdir -p "$backup_dir"
    
    # Backup key configuration directories
    local backup_paths=(
        "/etc"
        "/home/$USER/.config"
        "/usr/local/bin"
    )
    
    for path in "${backup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            sudo cp -r "$path" "$backup_dir/" 2>/dev/null || warn "Could not backup: $path"
        fi
    done
    
    # Save current profile info
    echo "Profile: $profile" | sudo tee "$backup_dir/profile_info.txt" >/dev/null
    echo "Created: $(date)" | sudo tee -a "$backup_dir/profile_info.txt" >/dev/null
    
    success "Backup created: $backup_dir"
}

# Restore from backup
restore_profile() {
    local profile="$1"
    
    info "Looking for backups of profile: $profile"
    
    local backup_pattern="/backup/profile-$profile-*"
    local backups
    backups=($(ls -d $backup_pattern 2>/dev/null || true))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        error "No backups found for profile: $profile"
    fi
    
    info "Available backups:"
    for i in "${!backups[@]}"; do
        local backup_info="${backups["$i"]}/profile_info.txt"
        local created="Unknown"
        if [[ -f "$backup_info" ]]; then
            created=$(grep "Created:" "$backup_info" | cut -d' ' -f2- || echo "Unknown")
        fi
        echo "  $((i+1)). $(basename "${backups["$i"]}") - $created"
    done
    
    echo -n "Select backup to restore [1-${#backups[@]}]: "
    read -r selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#backups[@]} ]]; then
        error "Invalid selection"
    fi
    
    local selected_backup="${backups["$((selection-1))"]}"
    
    warn "This will overwrite current configuration!"
    echo -n "Are you sure? [y/N]: "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Restore cancelled"
        exit 0
    fi
    
    info "Restoring from: $selected_backup"
    
    # Restore configuration
    if [[ -d "$selected_backup/etc" ]]; then
        sudo cp -r "$selected_backup/etc/"* /etc/ || warn "Could not restore /etc"
    fi
    
    if [[ -d "$selected_backup/home" ]] && [[ -d "/home/$USER" ]]; then
        cp -r "$selected_backup/home/"* "/home/$USER/" 2>/dev/null || warn "Could not restore home directory"
    fi
    
    # Set profile
    echo "$profile" | sudo tee "$CURRENT_PROFILE_FILE" >/dev/null
    
    success "Profile restored: $profile"
    info "Reboot recommended to ensure all changes take effect"
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi
    
    local command="$1"
    
    case "$command" in
        list)
            list_profiles
            ;;
        current)
            show_current
            ;;
        info)
            if [[ $# -lt 2 ]]; then
                error "Profile name required for info command"
            fi
            show_profile_info "$2"
            ;;
        switch)
            if [[ $# -lt 2 ]]; then
                error "Profile name required for switch command"
            fi
            switch_profile "$2"
            ;;
        apply)
            if [[ $# -lt 2 ]]; then
                error "Profile name required for apply command"
            fi
            apply_profile "$2"
            ;;
        validate)
            if [[ $# -lt 2 ]]; then
                error "Profile name required for validate command"
            fi
            validate_profile "$2"
            ;;
        backup)
            backup_profile
            ;;
        restore)
            if [[ $# -lt 2 ]]; then
                error "Profile name required for restore command"
            fi
            restore_profile "$2"
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown command: $command. Use --help for usage information."
            ;;
    esac
}

# Run main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi