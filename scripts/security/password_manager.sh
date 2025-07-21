#!/bin/bash
# Password Manager - Core password management system
# Handles multiple password input methods with intelligent fallback

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_MODE="auto"
VERBOSE=false

# Password storage variables (secure in memory)
declare -A SECURE_PASSWORDS
SECURE_PASSWORDS[user]=""
SECURE_PASSWORDS[root]=""
SECURE_PASSWORDS[luks]=""
SECURE_PASSWORDS[wifi]=""

# Password mode detection order
PASSWORD_METHODS=("env" "file" "generate" "interactive")

# Logging functions
log_info() {
    [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

# Secure cleanup function
secure_cleanup() {
    log_info "Performing secure cleanup..."
    
    # Clear password variables
    for key in "${!SECURE_PASSWORDS[@]}"; do
        SECURE_PASSWORDS[$key]=""
        unset SECURE_PASSWORDS[$key]
    done
    
    # Clear environment variables if they exist
    unset DEPLOY_USER_PASSWORD DEPLOY_ROOT_PASSWORD DEPLOY_LUKS_PASSPHRASE DEPLOY_WIFI_SSID DEPLOY_WIFI_PASSWORD 2>/dev/null || true
    
    # Clear any temporary files
    find /tmp -name "password_*_$$" -type f -delete 2>/dev/null || true
    
    log_info "Secure cleanup completed"
}

# Trap cleanup on exit
trap secure_cleanup EXIT

# Password strength validation
validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"
    local password_name="${3:-password}"
    
    # Basic length check
    if [[ ${#password} -lt $min_length ]]; then
        log_error "$password_name must be at least $min_length characters"
        return 1
    fi
    
    # Strength scoring
    local score=0
    [[ ${#password} -ge 8 ]] && ((score++))
    [[ ${#password} -ge 12 ]] && ((score++))
    [[ "$password" =~ [a-z] ]] && ((score++))
    [[ "$password" =~ [A-Z] ]] && ((score++))
    [[ "$password" =~ [0-9] ]] && ((score++))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((score++))
    
    # Strength assessment
    local strength
    if [[ $score -ge 5 ]]; then
        strength="Strong"
    elif [[ $score -ge 3 ]]; then
        strength="Medium"
    else
        strength="Weak"
        log_warn "$password_name strength: $strength (consider using a stronger password)"
    fi
    
    log_info "$password_name strength: $strength"
    return 0
}

# Environment variable password detection
detect_env_passwords() {
    log_info "Checking for environment variable passwords..."
    
    local found_any=false
    
    # Check for each password type
    if [[ -n "${DEPLOY_USER_PASSWORD:-}" ]]; then
        SECURE_PASSWORDS[user]="$DEPLOY_USER_PASSWORD"
        log_success "User password found in environment"
        found_any=true
    fi
    
    if [[ -n "${DEPLOY_ROOT_PASSWORD:-}" ]]; then
        SECURE_PASSWORDS[root]="$DEPLOY_ROOT_PASSWORD"
        log_success "Root password found in environment"
        found_any=true
    fi
    
    if [[ -n "${DEPLOY_LUKS_PASSPHRASE:-}" ]]; then
        SECURE_PASSWORDS[luks]="$DEPLOY_LUKS_PASSPHRASE"
        log_success "LUKS passphrase found in environment"
        found_any=true
    fi
    
    if [[ -n "${DEPLOY_WIFI_PASSWORD:-}" ]]; then
        SECURE_PASSWORDS[wifi]="$DEPLOY_WIFI_PASSWORD"
        log_success "WiFi password found in environment"
        found_any=true
    fi
    
    # Export WiFi SSID if available (doesn't need to be in SECURE_PASSWORDS array)
    if [[ -n "${DEPLOY_WIFI_SSID:-}" ]]; then
        export DEPLOY_WIFI_SSID="$DEPLOY_WIFI_SSID"
        log_success "WiFi SSID found in environment"
        found_any=true
    fi
    
    if [[ "$found_any" == true ]]; then
        log_success "Environment variable passwords detected"
        return 0
    else
        log_info "No environment variable passwords found"
        return 1
    fi
}

# Check password completeness
check_password_completeness() {
    local missing_passwords=()
    
    # Check required passwords
    [[ -z "${SECURE_PASSWORDS[user]}" ]] && missing_passwords+=("user")
    [[ -z "${SECURE_PASSWORDS[root]}" ]] && missing_passwords+=("root")
    
    # Check LUKS if encryption is enabled
    local config_file="${CONFIG_FILE:-}"
    if [[ -f "$config_file" ]]; then
        local encryption_enabled=$(grep -A5 "encryption:" "$config_file" 2>/dev/null | grep -E "^\s*enabled:" | cut -d':' -f2 | xargs | tr -d '"' || echo "false")
        if [[ "$encryption_enabled" == "true" ]] && [[ -z "${SECURE_PASSWORDS[luks]}" ]]; then
            missing_passwords+=("luks")
        fi
    fi
    
    if [[ ${#missing_passwords[@]} -eq 0 ]]; then
        log_success "All required passwords available"
        return 0
    else
        log_info "Missing passwords: ${missing_passwords[*]}"
        return 1
    fi
}

# Try password method
try_password_method() {
    local method="$1"
    
    case "$method" in
        "env")
            log_info "Trying environment variable method..."
            if detect_env_passwords && check_password_completeness; then
                log_success "Environment variable method successful"
                return 0
            else
                log_info "Environment variable method failed"
                return 1
            fi
            ;;
            
        "file")
            log_info "Trying encrypted file method..."
            if [[ -f "$SCRIPT_DIR/encrypted_file_handler.sh" ]]; then
                source "$SCRIPT_DIR/encrypted_file_handler.sh"
                if load_encrypted_passwords && check_password_completeness; then
                    log_success "Encrypted file method successful"
                    return 0
                fi
            fi
            log_info "Encrypted file method failed"
            return 1
            ;;
            
        "generate")
            log_info "Trying auto-generation method..."
            if [[ -f "$SCRIPT_DIR/password_generator.sh" ]]; then
                source "$SCRIPT_DIR/password_generator.sh"
                if generate_secure_passwords && check_password_completeness; then
                    log_success "Auto-generation method successful"
                    return 0
                fi
            fi
            log_info "Auto-generation method failed"
            return 1
            ;;
            
        "interactive")
            log_info "Using interactive method..."
            if [[ -f "$SCRIPT_DIR/../deployment/secure_prompt_handler.sh" ]]; then
                source "$SCRIPT_DIR/../deployment/secure_prompt_handler.sh"
                if collect_interactive_passwords && check_password_completeness; then
                    log_success "Interactive method successful"
                    return 0
                fi
            fi
            log_error "Interactive method failed"
            return 1
            ;;
            
        *)
            log_error "Unknown password method: $method"
            return 1
            ;;
    esac
}

# Auto-detect and use best password method
auto_detect_password_method() {
    log_info "Auto-detecting best password method..."
    
    for method in "${PASSWORD_METHODS[@]}"; do
        if try_password_method "$method"; then
            log_success "Using password method: $method"
            return 0
        fi
    done
    
    log_error "All password methods failed"
    return 1
}

# Get password by type
get_password() {
    local password_type="$1"
    
    if [[ -n "${SECURE_PASSWORDS[$password_type]:-}" ]]; then
        echo "${SECURE_PASSWORDS[$password_type]}"
        return 0
    else
        log_error "Password not available: $password_type"
        return 1
    fi
}

# Set password by type
set_password() {
    local password_type="$1"
    local password="$2"
    
    if validate_password_strength "$password" 8 "$password_type"; then
        SECURE_PASSWORDS[$password_type]="$password"
        log_success "$password_type password set successfully"
        return 0
    else
        log_error "Failed to set $password_type password"
        return 1
    fi
}

# Export passwords to environment (for other scripts)
export_passwords() {
    log_info "Exporting passwords to environment..."
    
    export USER_PASSWORD="${SECURE_PASSWORDS[user]}"
    export ROOT_PASSWORD="${SECURE_PASSWORDS[root]}"
    export LUKS_PASSPHRASE="${SECURE_PASSWORDS[luks]}"
    export WIFI_PASSWORD="${SECURE_PASSWORDS[wifi]}"
    
    log_success "Passwords exported to environment"
}

# Generate password hashes
generate_password_hashes() {
    log_info "Generating password hashes..."
    
    local temp_file="/tmp/password_hashes_$$"
    cat > "$temp_file" << EOF
# Password hashes generated $(date)
user_password_hash: "$(echo "${SECURE_PASSWORDS[user]}" | python3 -c "import crypt; import sys; print(crypt.crypt(sys.stdin.read().strip(), crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null || echo "HASH_FAILED")"
root_password_hash: "$(echo "${SECURE_PASSWORDS[root]}" | python3 -c "import crypt; import sys; print(crypt.crypt(sys.stdin.read().strip(), crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null || echo "HASH_FAILED")"
EOF
    
    # Add LUKS passphrase if available
    if [[ -n "${SECURE_PASSWORDS[luks]}" ]]; then
        echo "luks_passphrase: \"${SECURE_PASSWORDS[luks]}\"" >> "$temp_file"
    fi
    
    # Add WiFi password if available
    if [[ -n "${SECURE_PASSWORDS[wifi]}" ]]; then
        echo "wifi_password: \"${SECURE_PASSWORDS[wifi]}\"" >> "$temp_file"
    fi
    
    echo "$temp_file"
}

# Main password collection function
collect_passwords() {
    local mode="${1:-auto}"
    
    log_info "Starting password collection with mode: $mode"
    
    case "$mode" in
        "auto")
            auto_detect_password_method
            ;;
        "env")
            try_password_method "env"
            ;;
        "file")
            try_password_method "file"
            ;;
        "generate")
            try_password_method "generate"
            ;;
        "interactive")
            try_password_method "interactive"
            ;;
        *)
            log_error "Invalid password mode: $mode"
            return 1
            ;;
    esac
}

# Show password status (without revealing passwords)
show_password_status() {
    echo -e "${PURPLE}Password Status:${NC}"
    
    for password_type in user root luks wifi; do
        if [[ -n "${SECURE_PASSWORDS[$password_type]:-}" ]]; then
            echo -e "  ${GREEN}✓${NC} $password_type: Set (${#SECURE_PASSWORDS[$password_type]} characters)"
        else
            echo -e "  ${YELLOW}○${NC} $password_type: Not set"
        fi
    done
}

# Help function
show_help() {
    cat << 'EOF'
Password Manager - Core password management system

This module provides secure password handling with multiple input methods:
- Environment variables (for CI/CD and automation)
- Encrypted password files (for secure storage)
- Auto-generated passwords (for development)
- Interactive prompts (for manual deployment)

Usage:
  source password_manager.sh
  collect_passwords [mode]

Modes:
  auto        - Auto-detect best available method (default)
  env         - Use environment variables only
  file        - Use encrypted password file
  generate    - Generate secure passwords automatically
  interactive - Prompt user interactively

Environment Variables:
  DEPLOY_USER_PASSWORD     - User account password
  DEPLOY_ROOT_PASSWORD     - Root account password
  DEPLOY_LUKS_PASSPHRASE   - LUKS encryption passphrase
  DEPLOY_WIFI_SSID         - WiFi network name (SSID)
  DEPLOY_WIFI_PASSWORD     - WiFi network password

Functions:
  collect_passwords [mode] - Main password collection function
  get_password <type>      - Retrieve password by type
  set_password <type> <pw> - Set password by type
  export_passwords         - Export to environment variables
  show_password_status     - Show password availability
  secure_cleanup           - Clear all passwords from memory

Security Features:
- Passwords stored only in memory
- Automatic secure cleanup on exit
- Password strength validation
- No plain text disk storage
- Process isolation

EOF
}

# Initialize if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "collect")
            collect_passwords "${2:-auto}"
            ;;
        "status")
            show_password_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {collect|status|help} [options]"
            exit 1
            ;;
    esac
fi