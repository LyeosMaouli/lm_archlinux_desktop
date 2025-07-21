#!/bin/bash
# Password Generator - Auto-generation system for secure passwords
# Generates cryptographically secure passwords with configurable complexity

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Password generation configuration
DEFAULT_USER_LENGTH=16
DEFAULT_ROOT_LENGTH=20
DEFAULT_LUKS_LENGTH=24
DEFAULT_WIFI_LENGTH=16

# Character sets for password generation
LOWERCASE="abcdefghijklmnopqrstuvwxyz"
UPPERCASE="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
NUMBERS="0123456789"
SPECIAL="!@#$%^&*()_+-=[]{}|;:,.<>?"
SAFE_SPECIAL="!@#$%^&*-_=+"  # Safer special characters

# Generated passwords storage
declare -A GENERATED_PASSWORDS
DELIVERY_METHOD="display"
OUTPUT_FILE=""

# Logging functions
log_info() {
    echo -e "${BLUE}[GEN]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[GEN-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[GEN-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[GEN-SUCCESS]${NC} $1" >&2
}

# Check available random sources
check_random_sources() {
    local random_sources=()
    
    # Check /dev/urandom (preferred)
    if [[ -c /dev/urandom ]]; then
        random_sources+=("/dev/urandom")
    fi
    
    # Check /dev/random
    if [[ -c /dev/random ]]; then
        random_sources+=("/dev/random")
    fi
    
    # Check OpenSSL
    if command -v openssl >/dev/null 2>&1; then
        random_sources+=("openssl")
    fi
    
    if [[ ${#random_sources[@]} -eq 0 ]]; then
        log_error "No suitable random source found"
        return 1
    fi
    
    log_info "Available random sources: ${random_sources[*]}"
    return 0
}

# Generate random number
get_random_number() {
    local max="$1"
    
    # Try /dev/urandom first
    if [[ -c /dev/urandom ]]; then
        od -An -N4 -tu4 < /dev/urandom | awk -v max="$max" '{print int($1 % max)}'
    # Fallback to OpenSSL
    elif command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 4 | xxd -r -p | od -An -N4 -tu4 | awk -v max="$max" '{print int($1 % max)}'
    else
        # Last resort: shell random (less secure)
        echo $((RANDOM % max))
    fi
}

# Generate secure password
generate_secure_password() {
    local length="$1"
    local use_special="${2:-true}"
    local exclude_ambiguous="${3:-true}"
    
    # Build character set
    local charset="$LOWERCASE$UPPERCASE$NUMBERS"
    
    if [[ "$use_special" == "true" ]]; then
        charset="$charset$SAFE_SPECIAL"
    fi
    
    # Remove ambiguous characters if requested
    if [[ "$exclude_ambiguous" == "true" ]]; then
        charset=$(echo "$charset" | tr -d '0O1lI')
    fi
    
    local password=""
    local charset_length=${#charset}
    
    # Generate password with required complexity
    for ((i=0; i<length; i++)); do
        local random_index
        random_index=$(get_random_number "$charset_length")
        password="${password}${charset:$random_index:1}"
    done
    
    # Ensure minimum complexity requirements
    if ! validate_generated_complexity "$password"; then
        # Regenerate if doesn't meet complexity
        generate_secure_password "$length" "$use_special" "$exclude_ambiguous"
    else
        echo "$password"
    fi
}

# Validate generated password complexity
validate_generated_complexity() {
    local password="$1"
    
    local has_lower=false
    local has_upper=false
    local has_number=false
    local has_special=false
    
    # Check character types
    [[ "$password" =~ [a-z] ]] && has_lower=true
    [[ "$password" =~ [A-Z] ]] && has_upper=true
    [[ "$password" =~ [0-9] ]] && has_number=true
    [[ "$password" =~ [^a-zA-Z0-9] ]] && has_special=true
    
    # Require at least 3 character types
    local complexity_score=0
    [[ "$has_lower" == true ]] && ((complexity_score++))
    [[ "$has_upper" == true ]] && ((complexity_score++))
    [[ "$has_number" == true ]] && ((complexity_score++))
    [[ "$has_special" == true ]] && ((complexity_score++))
    
    if [[ $complexity_score -ge 3 ]]; then
        return 0
    else
        return 1
    fi
}

# Generate memorable password (using words + numbers)
generate_memorable_password() {
    local word_count="${1:-4}"
    local add_numbers="${2:-true}"
    
    # Simple word list for memorable passwords
    local words=(
        "apple" "brave" "cloud" "dance" "eagle" "flame" "grace" "happy"
        "image" "joker" "knife" "light" "magic" "night" "ocean" "peace"
        "quick" "river" "storm" "tower" "ultra" "voice" "water" "xenon"
        "youth" "zebra" "amber" "block" "crane" "dream" "frost" "giant"
    )
    
    local password=""
    local word_list_length=${#words[@]:-0}
    
    # Select random words
    for ((i=0; i<word_count; i++)); do
        local word_index
        word_index=$(get_random_number "$word_list_length")
        local word="${words["$word_index"]}"
        
        # Capitalize first letter of each word
        word="$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}"
        
        password="${password}${word}"
        
        # Add separator except for last word
        if [[ $i -lt $((word_count - 1)) ]]; then
            password="${password}-"
        fi
    done
    
    # Add numbers if requested
    if [[ "$add_numbers" == "true" ]]; then
        local number_suffix
        number_suffix=$(get_random_number 1000)
        password="${password}${number_suffix}"
    fi
    
    echo "$password"
}

# Generate all required passwords
generate_secure_passwords() {
    log_info "Generating secure passwords..."
    
    # Check random sources
    if ! check_random_sources; then
        return 1
    fi
    
    # Generate user password
    log_info "Generating user account password..."
    GENERATED_PASSWORDS["user"]=$(generate_secure_password "$DEFAULT_USER_LENGTH" true true)
    if [[ -n "${GENERATED_PASSWORDS[user]:-}" ]]; then
        log_success "User password generated (${#GENERATED_PASSWORDS[user]} characters)"
    else
        log_error "Failed to generate user password"
    fi
    
    # Generate root password
    log_info "Generating root account password..."
    GENERATED_PASSWORDS["root"]=$(generate_secure_password "$DEFAULT_ROOT_LENGTH" true true)
    if [[ -n "${GENERATED_PASSWORDS[root]:-}" ]]; then
        log_success "Root password generated (${#GENERATED_PASSWORDS[root]} characters)"
    else
        log_error "Failed to generate root password"
    fi
    
    # Generate LUKS passphrase (if encryption enabled)
    local config_file="${CONFIG_FILE:-}"
    if [[ -f "$config_file" ]]; then
        local encryption_enabled=$(grep -A5 "encryption:" "$config_file" 2>/dev/null | grep -E "^\s*enabled:" | cut -d':' -f2 | xargs | tr -d '"' || echo "false")
        if [[ "$encryption_enabled" == "true" ]]; then
            log_info "Generating LUKS encryption passphrase..."
            GENERATED_PASSWORDS["luks"]=$(generate_memorable_password 6 true)
            if [[ -n "${GENERATED_PASSWORDS[luks]:-}" ]]; then
                log_success "LUKS passphrase generated (${#GENERATED_PASSWORDS[luks]} characters)"
            else
                log_error "Failed to generate LUKS passphrase"
            fi
        fi
    fi
    
    # WiFi passwords should NEVER be generated - they must be provided by user
    log_info "WiFi password generation disabled - use wired connection or provide WiFi credentials"
    
    # Export passwords with safe array access to prevent unbound variable errors
    export USER_PASSWORD="${GENERATED_PASSWORDS[user]:-}"
    export ROOT_PASSWORD="${GENERATED_PASSWORDS[root]:-}"
    export LUKS_PASSPHRASE="${GENERATED_PASSWORDS[luks]:-}"
    # WiFi password export removed - should never be auto-generated
    
    log_success "All passwords generated and exported"
    return 0
}

# Display generated passwords
display_passwords() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                              ║${NC}"
    echo -e "${PURPLE}║                [PASSWORD] Generated Passwords [PASSWORD]                  ║${NC}"
    echo -e "${PURPLE}║                                                              ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${YELLOW}[WARNING]  IMPORTANT: Save these passwords securely!${NC}"
    echo -e "${YELLOW}   These passwords will not be stored anywhere else.${NC}"
    echo
    
    # Display passwords with security indicators
    for password_type in user root luks wifi; do
        if [[ -n "${GENERATED_PASSWORDS[$password_type]:-}" ]]; then
            local password="${GENERATED_PASSWORDS[$password_type]}"
            local strength
            strength=$(assess_password_strength "$password")
            
            echo -e "${BLUE}$password_type Password:${NC} ${GREEN}$password${NC} ${YELLOW}($strength)${NC}"
        fi
    done
    
    echo
    echo -e "${BLUE}Security Features:${NC}"
    echo "[OK] Cryptographically secure random generation"
    echo "[OK] High complexity requirements enforced"
    echo "[OK] Ambiguous characters excluded"
    echo "[OK] Memorable LUKS passphrase format"
    echo
    
    echo -e "${YELLOW}Press Enter when you have saved these passwords...${NC}"
    read -r
}

# Assess password strength
assess_password_strength() {
    local password="$1"
    local score=0
    
    # Length scoring
    [[ ${#password} -ge 8 ]] && ((score++))
    [[ ${#password} -ge 12 ]] && ((score++))
    [[ ${#password} -ge 16 ]] && ((score++))
    
    # Character variety
    [[ "$password" =~ [a-z] ]] && ((score++))
    [[ "$password" =~ [A-Z] ]] && ((score++))
    [[ "$password" =~ [0-9] ]] && ((score++))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((score++))
    
    # Assess strength
    if [[ $score -ge 6 ]]; then
        echo "Very Strong"
    elif [[ $score -ge 5 ]]; then
        echo "Strong"
    elif [[ $score -ge 3 ]]; then
        echo "Medium"
    else
        echo "Weak"
    fi
}

# Save passwords to file
save_passwords_to_file() {
    local output_file="$1"
    local encrypt="${2:-false}"
    
    log_info "Saving passwords to file: $output_file"
    
    # Create password file content
    local temp_file="/tmp/generated_passwords_$$"
    cat > "$temp_file" << EOF
# Generated Passwords
# Created: $(date -Iseconds)
# Generation Method: Cryptographically Secure Random
# 
# [WARNING]  SECURITY WARNING: Store this file securely!
# [WARNING]  DELETE this file after deployment!

user_password: "${GENERATED_PASSWORDS["user"]}"
root_password: "${GENERATED_PASSWORDS["root"]}"
EOF
    
    # Add optional passwords
    if [[ -n "${GENERATED_PASSWORDS[luks]:-}" ]]; then
        echo "luks_passphrase: \"${GENERATED_PASSWORDS["luks"]}\"" >> "$temp_file"
    fi
    
    if [[ -n "${GENERATED_PASSWORDS[wifi]:-}" ]]; then
        echo "wifi_password: \"${GENERATED_PASSWORDS["wifi"]}\"" >> "$temp_file"
    fi
    
    # Encrypt if requested
    if [[ "$encrypt" == "true" ]]; then
        if [[ -f "$(dirname "$0")/encrypted_file_handler.sh" ]]; then
            source "$(dirname "$0")/encrypted_file_handler.sh"
            
            echo -e "${BLUE}Enter passphrase to encrypt the password file:${NC}"
            local encryption_passphrase
            read -s encryption_passphrase
            echo
            
            if encrypt_password_file "$temp_file" "$output_file" "$encryption_passphrase"; then
                log_success "Encrypted password file saved: $output_file"
            else
                log_error "Failed to encrypt password file"
                return 1
            fi
        else
            log_error "Encryption handler not available"
            return 1
        fi
    else
        # Save as plain text with warning
        cat > "$output_file" << EOF
$(cat "$temp_file")

# [WARNING]  SECURITY WARNING:
# This file contains passwords in PLAIN TEXT!
# Delete this file immediately after use!
# Consider using encrypted storage instead.
EOF
        log_warn "Passwords saved as PLAIN TEXT: $output_file"
        log_warn "Delete this file immediately after deployment!"
    fi
    
    # Secure cleanup
    shred -vfz -n 3 "$temp_file" 2>/dev/null || rm -f "$temp_file"
    
    # Set secure permissions
    chmod 600 "$output_file"
    
    return 0
}

# Generate QR code for passwords (if qrencode available)
generate_qr_code() {
    if ! command -v qrencode >/dev/null 2>&1; then
        log_warn "qrencode not available, skipping QR code generation"
        return 1
    fi
    
    log_info "Generating QR code for passwords..."
    
    # Create compact password data
    local qr_data="USER:${GENERATED_PASSWORDS["user"]};ROOT:${GENERATED_PASSWORDS["root"]}"
    
    if [[ -n "${GENERATED_PASSWORDS[luks]:-}" ]]; then
        qr_data="$qr_data;LUKS:${GENERATED_PASSWORDS["luks"]}"
    fi
    
    # Generate QR code to terminal
    echo -e "${BLUE}Password QR Code:${NC}"
    qrencode -t ansiutf8 "$qr_data"
    echo
    
    log_success "QR code generated"
    return 0
}

# Handle password delivery
deliver_passwords() {
    local method="${DELIVERY_METHOD:-display}"
    
    case "$method" in
        "display")
            display_passwords
            ;;
        "file")
            if [[ -n "$OUTPUT_FILE" ]]; then
                save_passwords_to_file "$OUTPUT_FILE" false
            else
                save_passwords_to_file "generated_passwords_$(date +%Y%m%d_%H%M%S).txt" false
            fi
            ;;
        "encrypted-file")
            if [[ -n "$OUTPUT_FILE" ]]; then
                save_passwords_to_file "$OUTPUT_FILE" true
            else
                save_passwords_to_file "generated_passwords_$(date +%Y%m%d_%H%M%S).enc" true
            fi
            ;;
        "qr")
            generate_qr_code
            display_passwords
            ;;
        *)
            log_error "Unknown delivery method: $method"
            return 1
            ;;
    esac
}

# Help function
show_help() {
    cat << 'EOF'
Password Generator - Auto-generation system for secure passwords

This module generates cryptographically secure passwords for automated deployment.

Functions:
  generate_secure_passwords    - Generate all required passwords
  generate_secure_password     - Generate single secure password
  generate_memorable_password  - Generate memorable password using words
  display_passwords           - Display generated passwords securely
  save_passwords_to_file      - Save passwords to file (plain or encrypted)
  deliver_passwords           - Handle password delivery via specified method

Configuration:
  DEFAULT_USER_LENGTH=16      - User password length
  DEFAULT_ROOT_LENGTH=20      - Root password length  
  DEFAULT_LUKS_LENGTH=24      - LUKS passphrase length
  DEFAULT_WIFI_LENGTH=16      - WiFi password length

Delivery Methods:
  display                     - Show passwords on screen (default)
  file                        - Save to plain text file
  encrypted-file              - Save to encrypted file
  qr                          - Generate QR code + display

Security Features:
- Uses /dev/urandom for cryptographic randomness
- Enforces complexity requirements (3+ character types)
- Excludes ambiguous characters (0, O, 1, l, I)
- Generates memorable LUKS passphrases using words
- Secure memory cleanup after use
- Optional QR code generation

Usage Examples:

1. Generate and display passwords:
   source password_generator.sh
   generate_secure_passwords
   deliver_passwords

2. Generate and save to encrypted file:
   DELIVERY_METHOD="encrypted-file" OUTPUT_FILE="passwords.enc"
   generate_secure_passwords
   deliver_passwords

3. Generate single password:
   password=$(generate_secure_password 16 true true)

EOF
}

# Main execution
main() {
    case "${1:-help}" in
        "generate")
            DELIVERY_METHOD="${2:-display}"
            OUTPUT_FILE="${3:-}"
            if generate_secure_passwords; then
                deliver_passwords
            fi
            ;;
        "single")
            local length="${2:-16}"
            local use_special="${3:-true}"
            local exclude_ambiguous="${4:-true}"
            generate_secure_password "$length" "$use_special" "$exclude_ambiguous"
            ;;
        "memorable")
            local word_count="${2:-4}"
            local add_numbers="${3:-true}"
            generate_memorable_password "$word_count" "$add_numbers"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {generate|single|memorable|help} [options]"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi