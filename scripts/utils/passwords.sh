#!/bin/bash
#
# passwords.sh - Unified Password Management System
# 
# Consolidates all password management functionality from the original 4 scripts:
# - password_manager.sh (orchestration)
# - encrypted_file_handler.sh (file encryption)
# - env_password_handler.sh (environment variables)
# - password_generator.sh (auto-generation)
#
# Usage:
#   source passwords.sh
#   collect_passwords [mode]
#   get_password [type]
#
# Modes: env, file, generate, interactive, auto
# Types: user, root, luks
#

# Load common functions
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=../internal/common.sh  
source "$SCRIPT_DIR/../internal/common.sh"

# Password management configuration
readonly PASSWORD_MIN_LENGTH=8
readonly PASSWORD_SECURE_LENGTH=20
readonly PBKDF2_ITERATIONS=100000
readonly AES_CIPHER="aes-256-cbc"

# Password storage (secure in-memory)
declare -A SECURE_PASSWORDS
SECURE_PASSWORDS["user"]=""
SECURE_PASSWORDS["root"]=""
SECURE_PASSWORDS["luks"]=""

# Configuration
PASSWORD_MODE="${PASSWORD_MODE:-auto}"
PASSWORD_FILE="${PASSWORD_FILE:-}"
FILE_PASSPHRASE="${FILE_PASSPHRASE:-}"

# Available methods in fallback order
readonly PASSWORD_METHODS=("env" "file" "generate" "interactive")

#
# Core Password Management API
#

# Get password for specific type
get_password() {
    local password_type="$1"
    
    if [[ -v SECURE_PASSWORDS[$password_type] ]]; then
        echo "${SECURE_PASSWORDS[$password_type]}"
    else
        log_error "Unknown password type: $password_type"
        return 1
    fi
}

# Set password for specific type
set_password() {
    local password_type="$1"
    local password="$2"
    
    if [[ -v SECURE_PASSWORDS ]]; then
        SECURE_PASSWORDS[$password_type]="$password"
        log_debug "Password set for type: $password_type"
    else
        log_error "Password storage not initialized"
        return 1
    fi
}

# Export passwords to environment variables
export_passwords() {
    if [[ -n "${SECURE_PASSWORDS[user]}" ]]; then
        export DEPLOY_USER_PASSWORD="${SECURE_PASSWORDS[user]}"
    fi
    if [[ -n "${SECURE_PASSWORDS[root]}" ]]; then
        export DEPLOY_ROOT_PASSWORD="${SECURE_PASSWORDS[root]}"
    fi
    if [[ -n "${SECURE_PASSWORDS[luks]}" ]]; then
        export DEPLOY_LUKS_PASSPHRASE="${SECURE_PASSWORDS[luks]}"
    fi
    log_debug "Passwords exported to environment"
}

# Show password availability status
show_password_status() {
    local types=("user" "root" "luks")
    
    log_info "Password Status:"
    for type in "${types[@]}"; do
        if [[ -n "${SECURE_PASSWORDS[$type]}" ]]; then
            log_info "  $type: Available"
        else
            log_warn "  $type: Not set"
        fi
    done
}

# Secure cleanup function
secure_cleanup() {
    log_debug "Performing secure password cleanup..."
    
    # Clear password variables safely
    for key in "${!SECURE_PASSWORDS[@]}"; do
        SECURE_PASSWORDS[$key]=""
    done
    
    # Reinitialize required keys
    SECURE_PASSWORDS["user"]=""
    SECURE_PASSWORDS["root"]=""
    SECURE_PASSWORDS["luks"]=""
    
    # Clear environment variables
    unset DEPLOY_USER_PASSWORD DEPLOY_ROOT_PASSWORD DEPLOY_LUKS_PASSPHRASE 2>/dev/null || true
    unset DEPLOY_WIFI_SSID DEPLOY_WIFI_PASSWORD 2>/dev/null || true
    
    # Clear temporary files
    find /tmp -name "password_*_$$" -type f -delete 2>/dev/null || true
    find /tmp -name "arch_deploy_*" -type f -delete 2>/dev/null || true
    
    log_debug "Secure password cleanup completed"
}

# Set up cleanup on exit
trap secure_cleanup EXIT

#
# Password Validation
#

# Validate password strength (returns score 0-6)
validate_password_strength() {
    local password="$1"
    local min_length="${2:-$PASSWORD_MIN_LENGTH}"
    local password_name="${3:-password}"
    local score=0
    
    # Check minimum length
    if [[ ${#password} -lt $min_length ]]; then
        log_error "$password_name must be at least $min_length characters long"
        return 1
    fi
    
    # Score password complexity
    [[ ${#password} -ge 8 ]] && ((score++))       # Length >= 8
    [[ ${#password} -ge 12 ]] && ((score++))      # Length >= 12
    [[ "$password" =~ [a-z] ]] && ((score++))     # Lowercase
    [[ "$password" =~ [A-Z] ]] && ((score++))     # Uppercase
    [[ "$password" =~ [0-9] ]] && ((score++))     # Numbers
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((score++)) # Special chars
    
    log_debug "$password_name strength score: $score/6"
    
    # Minimum acceptable score
    if [[ $score -lt 3 ]]; then
        log_warn "$password_name is weak (score: $score/6)"
        return 2
    fi
    
    return 0
}

# Check for common weak passwords
is_weak_password() {
    local password="$1"
    local weak_passwords=(
        "password" "123456" "123456789" "qwerty" "abc123"
        "password123" "admin" "root" "user" "test"
        "welcome" "letmein" "monkey" "dragon" "master"
    )
    
    local lower_password
    lower_password=$(echo "$password" | tr '[:upper:]' '[:lower:]')
    
    for weak in "${weak_passwords[@]}"; do
        if [[ "$lower_password" == "$weak" ]]; then
            return 0  # Is weak
        fi
    done
    
    return 1  # Not weak
}

#
# Environment Variable Method
#

# Detect CI/CD environment
detect_ci_environment() {
    if [[ -n "${CI:-}" ]] || [[ -n "${CONTINUOUS_INTEGRATION:-}" ]]; then
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "github-actions"
        elif [[ -n "${GITLAB_CI:-}" ]]; then
            echo "gitlab-ci" 
        elif [[ -n "${JENKINS_URL:-}" ]]; then
            echo "jenkins"
        elif [[ -n "${TRAVIS:-}" ]]; then
            echo "travis-ci"
        else
            echo "generic-ci"
        fi
    else
        echo "local"
    fi
}

# Load passwords from environment variables
load_env_passwords() {
    log_info "Loading passwords from environment variables..."
    
    local ci_env
    ci_env=$(detect_ci_environment)
    if [[ "$ci_env" != "local" ]]; then
        log_info "Detected CI environment: $ci_env"
    fi
    
    local loaded_count=0
    
    # User password (with fallback names)
    for var in "DEPLOY_USER_PASSWORD" "USER_PASSWORD" "ARCH_USER_PASSWORD"; do
        if [[ -n "${!var:-}" ]]; then
            if validate_env_password "${!var}" "user password"; then
                set_password "user" "${!var}"
                ((loaded_count++))
                break
            fi
        fi
    done
    
    # Root password (with fallback names)
    for var in "DEPLOY_ROOT_PASSWORD" "ROOT_PASSWORD" "ARCH_ROOT_PASSWORD"; do
        if [[ -n "${!var:-}" ]]; then
            if validate_env_password "${!var}" "root password"; then
                set_password "root" "${!var}"
                ((loaded_count++))
                break
            fi
        fi
    done
    
    # LUKS passphrase (with fallback names)
    for var in "DEPLOY_LUKS_PASSPHRASE" "LUKS_PASSPHRASE" "ENCRYPTION_PASSPHRASE"; do
        if [[ -n "${!var:-}" ]]; then
            if validate_env_password "${!var}" "LUKS passphrase"; then
                set_password "luks" "${!var}"
                ((loaded_count++))
                break
            fi
        fi
    done
    
    if [[ $loaded_count -gt 0 ]]; then
        log_info "Loaded $loaded_count passwords from environment"
        return 0
    else
        log_warn "No valid passwords found in environment variables"
        return 1
    fi
}

# Validate environment password
validate_env_password() {
    local password="$1"
    local password_name="$2"
    local min_length="${3:-$PASSWORD_MIN_LENGTH}"
    
    # Check for weak passwords
    if is_weak_password "$password"; then
        log_error "$password_name is a commonly used weak password"
        return 1
    fi
    
    # Validate strength
    if ! validate_password_strength "$password" "$min_length" "$password_name"; then
        return 1
    fi
    
    return 0
}

#
# File Encryption Method
#

# Verify encrypted file format
verify_encrypted_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "Password file not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Password file is not readable: $file"
        return 1
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [[ "$file_size" -eq 0 ]]; then
        log_error "Password file is empty: $file"
        return 1
    fi
    
    # Check for our metadata header
    if ! grep -q "^# ENCRYPTED PASSWORD FILE" "$file"; then
        log_error "Invalid password file format (missing header)"
        return 1
    fi
    
    log_debug "Password file verified: $file (size: $file_size bytes)"
    return 0
}

# Extract metadata from encrypted file
extract_file_metadata() {
    local file="$1"
    
    local version=""
    local cipher=""
    local iterations=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ VERSION:\ (.+)$ ]]; then
            version="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#\ CIPHER:\ (.+)$ ]]; then
            cipher="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#\ ITERATIONS:\ ([0-9]+)$ ]]; then
            iterations="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^#\ DATA:$ ]]; then
            break
        fi
    done < "$file"
    
    log_debug "File metadata - Version: $version, Cipher: $cipher, Iterations: $iterations"
    
    # Return metadata via echo for capture
    echo "$version|$cipher|$iterations"
}

# Decrypt password file
decrypt_password_file() {
    local file="$1"
    local passphrase="$2"
    
    if ! verify_encrypted_file "$file"; then
        return 1
    fi
    
    # Extract encrypted data (skip metadata lines)
    local encrypted_data
    encrypted_data=$(grep -v '^#' "$file" | tr -d '\n')
    
    if [[ -z "${encrypted_data:-}" ]]; then
        log_error "No encrypted data found in file"
        return 1
    fi
    
    # Extract metadata for decryption parameters
    local metadata
    metadata=$(extract_file_metadata "$file")
    local cipher
    cipher=$(echo "$metadata" | cut -d'|' -f2)
    local iterations
    iterations=$(echo "$metadata" | cut -d'|' -f3)
    
    # Use metadata or defaults
    cipher="${cipher:-$AES_CIPHER}"
    iterations="${iterations:-$PBKDF2_ITERATIONS}"
    
    # Decrypt the data
    local temp_file="/tmp/password_decrypt_$$"
    trap 'shred -f "$temp_file" 2>/dev/null || rm -f "$temp_file"' RETURN
    
    if echo "$encrypted_data" | base64 -d | \
       openssl enc -d "-$cipher" -pbkdf2 -iter "$iterations" -pass pass:"$passphrase" \
       > "$temp_file" 2>/dev/null; then
        
        # Return decrypted content
        cat "$temp_file"
        return 0
    else
        log_error "Failed to decrypt password file (wrong passphrase?)"
        return 1
    fi
}

# Load passwords from encrypted file
load_file_passwords() {
    log_info "Loading passwords from encrypted file..."
    
    # Determine file path
    local password_file="$PASSWORD_FILE"
    if [[ -z "${password_file:-}" ]]; then
        # Try common locations
        for candidate in "$PROJECT_ROOT/config/passwords.enc" "$PROJECT_ROOT/passwords.enc" "./passwords.enc"; do
            if [[ -f "$candidate" ]]; then
                password_file="$candidate"
                break
            fi
        done
    fi
    
    if [[ -z "${password_file:-}" ]]; then
        log_error "No password file specified and none found in default locations"
        return 1
    fi
    
    # Get file passphrase
    local passphrase="$FILE_PASSPHRASE"
    if [[ -z "${passphrase:-}" ]]; then
        passphrase="${DEPLOY_FILE_PASSPHRASE:-}"
    fi
    
    if [[ -z "${passphrase:-}" ]]; then
        passphrase=$(prompt_user "Enter passphrase for password file" true)
        if [[ -z "${passphrase:-}" ]]; then
            log_error "No passphrase provided for encrypted password file"
            return 1
        fi
    fi
    
    # Decrypt and parse file
    local decrypted_content
    if ! decrypted_content=$(decrypt_password_file "$password_file" "$passphrase"); then
        return 1
    fi
    
    local loaded_count=0
    
    # Parse decrypted content
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "${key:-}" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # Clean up key and value
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        case "$key" in
            "user_password"|"USER_PASSWORD")
                if validate_env_password "$value" "user password"; then
                    set_password "user" "$value"
                    ((loaded_count++))
                fi
                ;;
            "root_password"|"ROOT_PASSWORD")
                if validate_env_password "$value" "root password"; then
                    set_password "root" "$value"
                    ((loaded_count++))
                fi
                ;;
            "luks_passphrase"|"LUKS_PASSPHRASE")
                if validate_env_password "$value" "LUKS passphrase"; then
                    set_password "luks" "$value"
                    ((loaded_count++))
                fi
                ;;
        esac
    done <<< "$decrypted_content"
    
    if [[ $loaded_count -gt 0 ]]; then
        log_info "Loaded $loaded_count passwords from encrypted file"
        return 0
    else
        log_error "No valid passwords found in encrypted file"
        return 1
    fi
}

# Create encrypted password file
create_password_file() {
    local output_file="$1"
    local passphrase="$2"
    local user_pass="$3"
    local root_pass="$4"
    local luks_pass="$5"
    
    # Create temporary file with password data
    local temp_file="/tmp/password_create_$$"
    trap 'shred -f "$temp_file" 2>/dev/null || rm -f "$temp_file"' RETURN
    
    cat > "$temp_file" << EOF
# Encrypted Password File for Arch Linux Deployment
user_password=$user_pass
root_password=$root_pass
luks_passphrase=$luks_pass
EOF
    
    # Encrypt the file
    local encrypted_temp="/tmp/password_encrypted_$$"
    trap 'shred -f "$encrypted_temp" 2>/dev/null || rm -f "$encrypted_temp"' RETURN
    
    if openssl enc "-$AES_CIPHER" -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
       -pass pass:"$passphrase" -base64 < "$temp_file" > "$encrypted_temp"; then
        
        # Create final file with metadata
        cat > "$output_file" << EOF
# ENCRYPTED PASSWORD FILE
# VERSION: 2.0
# CIPHER: $AES_CIPHER
# ITERATIONS: $PBKDF2_ITERATIONS
# CREATED: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
# DATA:
EOF
        cat "$encrypted_temp" >> "$output_file"
        
        # Set secure permissions
        chmod 600 "$output_file"
        
        log_info "Encrypted password file created: $output_file"
        return 0
    else
        log_error "Failed to encrypt password file"
        return 1
    fi
}

#
# Password Generation Method
#

# Generate cryptographically secure password
generate_secure_password() {
    local length="${1:-$PASSWORD_SECURE_LENGTH}"
    local include_special="${2:-true}"
    local exclude_ambiguous="${3:-true}"
    
    local charset=""
    
    # Build character set
    charset+="abcdefghijklmnopqrstuvwxyz"      # lowercase
    charset+="ABCDEFGHIJKLMNOPQRSTUVWXYZ"      # uppercase
    charset+="0123456789"                       # numbers
    
    if [[ "$include_special" == "true" ]]; then
        charset+="!@#\$%^&*()_+-=[]{}|;:,.<>?"  # special characters
    fi
    
    # Exclude ambiguous characters if requested
    if [[ "$exclude_ambiguous" == "true" ]]; then
        charset=$(echo "$charset" | tr -d '0O1lI')
    fi
    
    local password=""
    local charset_length=${#charset}
    
    # Generate password using /dev/urandom
    if [[ -r /dev/urandom ]]; then
        for ((i=0; i<length; i++)); do
            local random_index
            random_index=$(($(od -An -N1 -tu1 < /dev/urandom) % charset_length))
            password+="${charset:$random_index:1}"
        done
    else
        # Fallback to OpenSSL random
        log_warn "Using OpenSSL random fallback"
        password=$(openssl rand -base64 $((length * 3/4)) | tr -cd "$charset" | cut -c1-"$length")
        
        # Ensure we have the full length
        while [[ ${#password} -lt $length ]]; do
            password+="${charset:$((RANDOM % charset_length)):1}"
        done
    fi
    
    # Ensure password meets complexity requirements
    local has_lower has_upper has_digit has_special=false
    
    [[ "$password" =~ [a-z] ]] && has_lower=true
    [[ "$password" =~ [A-Z] ]] && has_upper=true
    [[ "$password" =~ [0-9] ]] && has_digit=true
    [[ "$password" =~ [^a-zA-Z0-9] ]] && has_special=true
    
    # If missing required character types, regenerate
    local required_types=3
    [[ "$include_special" == "true" ]] && required_types=4
    
    local actual_types=0
    [[ "$has_lower" == "true" ]] && ((actual_types++))
    [[ "$has_upper" == "true" ]] && ((actual_types++))
    [[ "$has_digit" == "true" ]] && ((actual_types++))
    [[ "$has_special" == "true" ]] && ((actual_types++))
    
    if [[ $actual_types -lt $required_types ]]; then
        # Recursively try again (max 5 attempts to avoid infinite loop)
        if [[ "${4:-0}" -lt 5 ]]; then
            generate_secure_password "$length" "$include_special" "$exclude_ambiguous" $(( ${4:-0} + 1 ))
            return
        fi
    fi
    
    echo "$password"
}

# Generate all required passwords
generate_all_passwords() {
    log_info "Generating secure passwords..."
    
    # Generate passwords with different requirements
    local user_password
    local root_password
    local luks_passphrase
    
    user_password=$(generate_secure_password 16 true true)
    root_password=$(generate_secure_password 20 true true)
    luks_passphrase=$(generate_secure_password 24 true false)  # Include all chars for LUKS
    
    # Validate generated passwords
    if validate_password_strength "$user_password" "$PASSWORD_MIN_LENGTH" "generated user password" && \
       validate_password_strength "$root_password" "$PASSWORD_MIN_LENGTH" "generated root password" && \
       validate_password_strength "$luks_passphrase" "$PASSWORD_MIN_LENGTH" "generated LUKS passphrase"; then
        
        set_password "user" "$user_password"
        set_password "root" "$root_password"
        set_password "luks" "$luks_passphrase"
        
        log_info "Generated 3 secure passwords successfully"
        return 0
    else
        log_error "Generated password validation failed"
        return 1
    fi
}

#
# Interactive Method
#

# Interactive password collection
collect_interactive_passwords() {
    log_info "Collecting passwords interactively..."
    
    local types=("user" "root" "luks")
    local descriptions=(
        "primary user account"
        "root administrator account"  
        "disk encryption (LUKS)"
    )
    
    for i in "${!types[@]}"; do
        local type="${types[$i]}"
        local description="${descriptions[$i]}"
        
        while true; do
            local password
            password=$(prompt_user "Enter password for $description" true)
            
            if [[ -z "${password:-}" ]]; then
                log_warn "Password cannot be empty"
                continue
            fi
            
            if validate_password_strength "$password" "$PASSWORD_MIN_LENGTH" "$description password"; then
                # Confirm password
                local confirm_password
                confirm_password=$(prompt_user "Confirm password for $description" true)
                
                if [[ "$password" == "$confirm_password" ]]; then
                    set_password "$type" "$password"
                    break
                else
                    log_error "Passwords do not match"
                fi
            fi
        done
    done
    
    log_info "Collected 3 passwords interactively"
    return 0
}

#
# Main Collection Function
#

# Main password collection function with intelligent fallback
collect_passwords() {
    local mode="${1:-$PASSWORD_MODE}"
    
    log_info "Collecting passwords using mode: $mode"
    
    # Handle auto mode - try methods in order
    if [[ "$mode" == "auto" ]]; then
        for method in "${PASSWORD_METHODS[@]}"; do
            log_debug "Trying password method: $method"
            
            case "$method" in
                env)
                    if load_env_passwords; then
                        log_info "Successfully loaded passwords from environment"
                        export_passwords
                        return 0
                    fi
                    ;;
                file)
                    if [[ -n "${PASSWORD_FILE:-}" ]] && load_file_passwords; then
                        log_info "Successfully loaded passwords from file"
                        export_passwords
                        return 0
                    fi
                    ;;
                generate)
                    if generate_all_passwords; then
                        log_info "Successfully generated passwords"
                        export_passwords
                        return 0
                    fi
                    ;;
                interactive)
                    if collect_interactive_passwords; then
                        log_info "Successfully collected passwords interactively"
                        export_passwords
                        return 0
                    fi
                    ;;
            esac
        done
        
        log_error "All password collection methods failed"
        return 1
    fi
    
    # Handle specific mode
    case "$mode" in
        env)
            load_env_passwords && export_passwords
            ;;
        file)
            load_file_passwords && export_passwords
            ;;
        generate)
            generate_all_passwords && export_passwords
            ;;
        interactive)
            collect_interactive_passwords && export_passwords
            ;;
        *)
            log_error "Unknown password mode: $mode"
            return 1
            ;;
    esac
}

#
# Utility Functions
#

# Display passwords securely (masked)
display_passwords() {
    local show_passwords="${1:-false}"
    
    echo "Password Status:"
    for type in user root luks; do
        local password="${SECURE_PASSWORDS[$type]}"
        if [[ -n "${password:-}" ]]; then
            if [[ "$show_passwords" == "true" ]]; then
                echo "  $type: $password"
            else
                echo "  $type: [SET - ${#password} characters]"
            fi
        else
            echo "  $type: [NOT SET]"
        fi
    done
}

# Generate password hashes for system installation
generate_password_hashes() {
    local user_password="${SECURE_PASSWORDS[user]}"
    local root_password="${SECURE_PASSWORDS[root]}"
    
    if [[ -n "${user_password:-}" ]]; then
        echo "user_hash=$(openssl passwd -6 "$user_password")"
    fi
    
    if [[ -n "${root_password:-}" ]]; then
        echo "root_hash=$(openssl passwd -6 "$root_password")"
    fi
}

#
# Command Line Interface
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    
    case "${1:-help}" in
        collect)
            collect_passwords "${2:-auto}"
            ;;
        generate)
            generate_all_passwords
            display_passwords false
            ;;
        create-file)
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 create-file <output_file> <passphrase> <user_pass> <root_pass> [luks_pass]"
                exit 1
            fi
            create_password_file "$2" "$3" "$4" "$5" "${6:-$5}"
            ;;
        display)
            display_passwords "${2:-false}"
            ;;
        status)
            show_password_status
            ;;
        help|*)
            cat << EOF
Password Management Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  collect [MODE]           Collect passwords using specified mode
  generate                 Generate secure passwords  
  create-file FILE PASS U R [L]  Create encrypted password file
  display [true|false]     Display password status
  status                   Show password availability
  help                     Show this help

Modes:
  auto                     Try all methods in order (default)
  env                      Load from environment variables
  file                     Load from encrypted file
  generate                 Generate secure passwords
  interactive              Prompt user for passwords

Examples:
  $0 collect generate      # Generate passwords
  $0 collect env           # Load from environment
  $0 display true          # Show actual passwords
  $0 create-file passwords.enc mypass user123 root456 luks789

EOF
            ;;
    esac
fi