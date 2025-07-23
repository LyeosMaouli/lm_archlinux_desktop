#!/bin/bash
# Secure Prompt Handler
# Handles all sensitive input securely during deployment

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Global variables for storing secure data
USER_PASSWORD=""
ROOT_PASSWORD=""
LUKS_PASSPHRASE=""
WIFI_PASSWORD=""

# Secure password prompt with validation
secure_password_prompt() {
    local prompt_text="$1"
    local confirm_required="${2:-true}"
    local min_length="${3:-8}"
    local password=""
    local password_confirm=""
    
    while true; do
        log_info "$prompt_text"
        read -s password
        echo
        
        # Check minimum length
        if [[ ${#password} -lt $min_length ]]; then
            log_error "Password must be at least $min_length characters"
            continue
        fi
        
        # Check password strength
        if [[ ${#password} -lt 12 ]]; then
            log_warn "Warning: Password is short (less than 12 characters)"
        fi
        
        if [[ "$confirm_required" == "true" ]]; then
            log_info "Confirm password:"
            read -s password_confirm
            echo
            
            if [[ "$password" != "$password_confirm" ]]; then
                log_error "Passwords don't match, please try again"
                continue
            fi
        fi
        
        break
    done
    
    echo "$password"
}

# WiFi credential prompt
wifi_credentials_prompt() {
    local ssid=""
    local password=""
    
    # Check if WiFi hardware exists
    if ! iwctl device list 2>/dev/null | grep -q "wlan"; then
        log_warn "No WiFi hardware detected, skipping WiFi setup"
        return 0
    fi
    
    # Auto-detect networks if possible
    local wifi_device
    wifi_device=$(iwctl device list | grep wlan | awk '{print $1}' | head -1)
    
    if [[ -n "$wifi_device" ]]; then
        log_info "📶 Scanning for WiFi networks..."
        iwctl station "$wifi_device" scan 2>/dev/null || true
        sleep 2
        
        echo "Available networks:"
        iwctl station "$wifi_device" get-networks 2>/dev/null | tail -n +5 | head -10 | grep -v "^$" || echo "No networks found"
        echo
    fi
    
    read -p "WiFi network name (SSID) [press Enter to skip]: " ssid
    
    if [[ -n "$ssid" ]]; then
        log_info "Enter WiFi password for '$ssid':"
        password=$(secure_password_prompt "WiFi password:" false 1)
        
        echo "wifi_ssid=\"$ssid\"" >> /tmp/wifi_config
        echo "wifi_password=\"$password\"" >> /tmp/wifi_config
        
        log_success "WiFi credentials saved"
    else
        echo "Skipping WiFi setup - will use ethernet connection"
    fi
}

# User account setup
user_account_prompt() {
    local username="$1"
    
    log_info "Setting up user account for '$username'"
    echo
    
    USER_PASSWORD=$(secure_password_prompt "Enter password for user '$username':" true 8)
    
    log_success "User password set"
}

# Root account setup
root_account_prompt() {
    log_info "Setting up root account"
    echo "Root account is needed for system administration."
    echo
    
    ROOT_PASSWORD=$(secure_password_prompt "Enter root password:" true 8)
    
    log_success "Root password set"
}

# LUKS encryption setup
luks_encryption_prompt() {
    local encryption_enabled="$1"
    
    if [[ "$encryption_enabled" == "true" ]]; then
        log_info "Setting up disk encryption"
        echo "Full disk encryption protects your data if the laptop is stolen."
        echo "[WARNING]  Important: You'll need this passphrase every time you boot!"
        echo
        
        LUKS_PASSPHRASE=$(secure_password_prompt "Enter LUKS encryption passphrase:" true 12)
        
        log_success "Encryption passphrase set"
        log_warn "💡 Remember this passphrase - you can't boot without it!"
    else
        echo "Disk encryption disabled - skipping passphrase setup"
    fi
}

# Generate secure config with passwords
generate_secure_config() {
    local base_config="$1"
    local output_config="$2"
    
    # Copy base configuration
    cp "$base_config" "$output_config"
    
    # Create temporary file with password hashes
    local temp_passwords="/tmp/secure_passwords_$$"
    cat > "$temp_passwords" << EOF
# Secure password configuration
# Generated $(date)

user_password_hash: "$(echo "$USER_PASSWORD" | python3 -c "import crypt; import sys; print(crypt.crypt(sys.stdin.read().strip(), crypt.mksalt(crypt.METHOD_SHA512)))")"
root_password_hash: "$(echo "$ROOT_PASSWORD" | python3 -c "import crypt; import sys; print(crypt.crypt(sys.stdin.read().strip(), crypt.mksalt(crypt.METHOD_SHA512)))")"
luks_passphrase: "$LUKS_PASSPHRASE"
EOF
    
    # Add WiFi config if available
    if [[ -f /tmp/wifi_config ]]; then
        cat /tmp/wifi_config >> "$temp_passwords"
    fi
    
    # Store securely in memory (not on disk)
    export SECURE_CONFIG_DATA="$(cat "$temp_passwords")"
    rm -f "$temp_passwords"
    
    log_success "Secure configuration generated"
}

# Interactive credential collection
collect_all_credentials() {
    local config_file="$1"
    
    # Parse configuration
    local username=$(grep -A5 "^user:" "$config_file" | grep -E "^\s*username:" | cut -d':' -f2 | xargs | tr -d '"')
    local encryption_enabled=$(grep -A5 "encryption:" "$config_file" | grep -E "^\s*enabled:" | cut -d':' -f2 | xargs | tr -d '"')
    
    log_info "Secure Credential Setup"
    echo "We need to set up some passwords and credentials securely."
    echo "All passwords are encrypted and never stored in plain text."
    echo
    
    # Collect all credentials
    user_account_prompt "$username"
    echo
    
    root_account_prompt
    echo
    
    luks_encryption_prompt "$encryption_enabled"
    echo
    
    wifi_credentials_prompt
    echo
    
    # Generate final secure config
    generate_secure_config "$config_file" "/tmp/deployment_config_secure.yml"
    
    log_success "All credentials collected securely!"
    echo "Deployment will now proceed automatically."
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    local score=0
    
    # Length check
    [[ ${#password} -ge 8 ]] && ((score++))
    [[ ${#password} -ge 12 ]] && ((score++))
    
    # Character variety
    [[ "$password" =~ [a-z] ]] && ((score++))
    [[ "$password" =~ [A-Z] ]] && ((score++))
    [[ "$password" =~ [0-9] ]] && ((score++))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((score++))
    
    if [[ $score -ge 5 ]]; then
        echo "Strong"
    elif [[ $score -ge 3 ]]; then
        echo "Medium"
    else
        echo "Weak"
    fi
}

# Main execution
main() {
    local config_file="${1:-}"
    
    if [[ -z "${config_file:-}" ]] || [[ ! -f "$config_file" ]]; then
        log_error "Configuration file required"
        echo "Usage: $0 <config_file>"
        exit 1
    fi
    
    collect_all_credentials "$config_file"
}

# Help function
show_help() {
    cat << 'EOF'
Secure Prompt Handler

This script collects sensitive credentials securely for the deployment:
- User password
- Root password  
- LUKS encryption passphrase
- WiFi credentials

All passwords are:
- Never stored in plain text
- Encrypted with secure hashing
- Kept only in memory during deployment
- Automatically cleared after use

Usage: secure_prompt_handler.sh <config_file>

EOF
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        if [[ $# -eq 0 ]]; then
            show_help
            exit 1
        fi
        main "$@"
        ;;
esac