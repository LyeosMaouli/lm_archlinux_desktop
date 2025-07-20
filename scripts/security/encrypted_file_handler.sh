#!/bin/bash
# Encrypted File Password Handler
# Handles password storage and retrieval using encrypted files

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Default configuration
DEFAULT_ENCRYPTION_ALGO="aes-256-cbc"
DEFAULT_KEY_DERIVATION="pbkdf2"
DEFAULT_ITERATIONS=100000
PASSWORD_FILE=""
FILE_PASSPHRASE=""

# Logging functions
log_info() {
    echo -e "${BLUE}[FILE]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[FILE-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[FILE-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[FILE-SUCCESS]${NC} $1" >&2
}

# Check if OpenSSL is available
check_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        log_error "OpenSSL not found. Please install OpenSSL for encrypted file support."
        return 1
    fi
    
    # Check for required cipher
    if ! openssl list -cipher-algorithms | grep -qi "$DEFAULT_ENCRYPTION_ALGO"; then
        log_error "Cipher $DEFAULT_ENCRYPTION_ALGO not available in OpenSSL"
        return 1
    fi
    
    return 0
}

# Generate salt for key derivation
generate_salt() {
    openssl rand -hex 16
}

# Derive key from passphrase and salt
derive_key() {
    local passphrase="$1"
    local salt="$2"
    local iterations="${3:-$DEFAULT_ITERATIONS}"
    
    echo -n "$passphrase" | openssl dgst -sha256 -binary | \
    openssl dgst -sha256 -binary -hmac "$salt" | \
    hexdump -ve '1/1 "%.2x"'
}

# Encrypt password file
encrypt_password_file() {
    local input_file="$1"
    local output_file="$2"
    local passphrase="$3"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    # Generate salt
    local salt
    salt=$(generate_salt)
    
    # Create header with metadata
    local header
    header=$(cat << EOF
# Encrypted Password File
# Algorithm: $DEFAULT_ENCRYPTION_ALGO
# Key Derivation: $DEFAULT_KEY_DERIVATION
# Iterations: $DEFAULT_ITERATIONS
# Salt: $salt
# Created: $(date -Iseconds)
---ENCRYPTED-DATA---
EOF
)
    
    # Create temporary file for encryption
    local temp_file="/tmp/encrypt_temp_$$"
    
    # Encrypt the file
    if echo -n "$passphrase" | openssl enc -"$DEFAULT_ENCRYPTION_ALGO" -salt -pbkdf2 -iter "$DEFAULT_ITERATIONS" -in "$input_file" -out "$temp_file" -pass stdin 2>/dev/null; then
        # Combine header and encrypted data
        {
            echo "$header"
            base64 -w 0 < "$temp_file"
        } > "$output_file"
        
        # Secure cleanup
        shred -vfz -n 3 "$temp_file" 2>/dev/null || rm -f "$temp_file"
        
        # Set secure permissions
        chmod 600 "$output_file"
        
        log_success "Password file encrypted: $output_file"
        return 0
    else
        log_error "Failed to encrypt password file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Decrypt password file
decrypt_password_file() {
    local encrypted_file="$1"
    local passphrase="$2"
    
    if [[ ! -f "$encrypted_file" ]]; then
        log_error "Encrypted file not found: $encrypted_file"
        return 1
    fi
    
    # Extract metadata from header
    local metadata_section
    metadata_section=$(sed '/^---ENCRYPTED-DATA---$/q' "$encrypted_file" | head -n -1)
    
    # Extract encrypted data
    local encrypted_data
    encrypted_data=$(sed -n '/^---ENCRYPTED-DATA---$/,$p' "$encrypted_file" | tail -n +2)
    
    if [[ -z "$encrypted_data" ]]; then
        log_error "No encrypted data found in file"
        return 1
    fi
    
    # Create temporary files
    local temp_encrypted="/tmp/decrypt_enc_$$"
    local temp_decrypted="/tmp/decrypt_dec_$$"
    
    # Decode base64 data
    if ! echo "$encrypted_data" | base64 -d > "$temp_encrypted" 2>/dev/null; then
        log_error "Failed to decode encrypted data"
        rm -f "$temp_encrypted" 2>/dev/null
        return 1
    fi
    
    # Decrypt the file
    if echo -n "$passphrase" | openssl enc -d -"$DEFAULT_ENCRYPTION_ALGO" -salt -pbkdf2 -iter "$DEFAULT_ITERATIONS" -in "$temp_encrypted" -out "$temp_decrypted" -pass stdin 2>/dev/null; then
        # Output decrypted content
        cat "$temp_decrypted"
        
        # Secure cleanup
        shred -vfz -n 3 "$temp_encrypted" "$temp_decrypted" 2>/dev/null || {
            rm -f "$temp_encrypted" "$temp_decrypted" 2>/dev/null
        }
        
        return 0
    else
        log_error "Failed to decrypt password file (wrong passphrase?)"
        rm -f "$temp_encrypted" "$temp_decrypted" 2>/dev/null
        return 1
    fi
}

# Load passwords from encrypted file
load_encrypted_passwords() {
    local file_path="${PASSWORD_FILE:-}"
    local file_passphrase="${FILE_PASSPHRASE:-}"
    
    # Check for file path in environment or arguments
    if [[ -z "$file_path" ]]; then
        file_path="${DEPLOY_PASSWORD_FILE:-}"
    fi
    
    if [[ -z "$file_passphrase" ]]; then
        file_passphrase="${DEPLOY_FILE_PASSPHRASE:-}"
    fi
    
    if [[ -z "$file_path" ]]; then
        log_info "No password file specified"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Password file not found: $file_path"
        return 1
    fi
    
    # Prompt for passphrase if not provided
    if [[ -z "$file_passphrase" ]]; then
        log_info "Enter passphrase for encrypted password file:"
        read -s file_passphrase
        echo
    fi
    
    log_info "Decrypting password file: $file_path"
    
    # Decrypt and parse password file
    local decrypted_content
    if decrypted_content=$(decrypt_password_file "$file_path" "$file_passphrase"); then
        # Parse password data
        local user_password root_password luks_passphrase wifi_password
        
        user_password=$(echo "$decrypted_content" | grep -E "^user_password:" | cut -d':' -f2- | xargs | tr -d '"' || echo "")
        root_password=$(echo "$decrypted_content" | grep -E "^root_password:" | cut -d':' -f2- | xargs | tr -d '"' || echo "")
        luks_passphrase=$(echo "$decrypted_content" | grep -E "^luks_passphrase:" | cut -d':' -f2- | xargs | tr -d '"' || echo "")
        wifi_password=$(echo "$decrypted_content" | grep -E "^wifi_password:" | cut -d':' -f2- | xargs | tr -d '"' || echo "")
        
        # Export passwords
        local passwords_loaded=0
        
        if [[ -n "$user_password" ]]; then
            export USER_PASSWORD="$user_password"
            log_success "User password loaded from encrypted file"
            ((passwords_loaded++))
        fi
        
        if [[ -n "$root_password" ]]; then
            export ROOT_PASSWORD="$root_password"
            log_success "Root password loaded from encrypted file"
            ((passwords_loaded++))
        fi
        
        if [[ -n "$luks_passphrase" ]]; then
            export LUKS_PASSPHRASE="$luks_passphrase"
            log_success "LUKS passphrase loaded from encrypted file"
            ((passwords_loaded++))
        fi
        
        if [[ -n "$wifi_password" ]]; then
            export WIFI_PASSWORD="$wifi_password"
            log_success "WiFi password loaded from encrypted file"
            ((passwords_loaded++))
        fi
        
        log_info "Loaded $passwords_loaded passwords from encrypted file"
        
        if [[ $passwords_loaded -gt 0 ]]; then
            return 0
        else
            log_error "No valid passwords found in encrypted file"
            return 1
        fi
    else
        log_error "Failed to decrypt password file"
        return 1
    fi
}

# Create password file from interactive input
create_password_file_interactive() {
    local output_file="$1"
    local encryption_passphrase="$2"
    
    log_info "Creating encrypted password file interactively..."
    
    # Create temporary file for password data
    local temp_passwords="/tmp/passwords_plain_$$"
    
    echo "# Password configuration file" > "$temp_passwords"
    echo "# Created: $(date -Iseconds)" >> "$temp_passwords"
    echo "" >> "$temp_passwords"
    
    # Collect passwords interactively
    echo -e "${BLUE}Enter passwords for encrypted storage:${NC}"
    echo
    
    # User password
    echo -e "${BLUE}User account password:${NC}"
    local user_password
    read -s user_password
    echo "user_password: \"$user_password\"" >> "$temp_passwords"
    echo
    
    # Root password
    echo -e "${BLUE}Root account password:${NC}"
    local root_password
    read -s root_password
    echo "root_password: \"$root_password\"" >> "$temp_passwords"
    echo
    
    # LUKS passphrase (optional)
    echo -e "${BLUE}LUKS encryption passphrase (optional, press Enter to skip):${NC}"
    local luks_passphrase
    read -s luks_passphrase
    if [[ -n "$luks_passphrase" ]]; then
        echo "luks_passphrase: \"$luks_passphrase\"" >> "$temp_passwords"
    fi
    echo
    
    # WiFi password (optional)
    echo -e "${BLUE}WiFi password (optional, press Enter to skip):${NC}"
    local wifi_password
    read -s wifi_password
    if [[ -n "$wifi_password" ]]; then
        echo "wifi_password: \"$wifi_password\"" >> "$temp_passwords"
    fi
    echo
    
    # Encrypt the password file
    if encrypt_password_file "$temp_passwords" "$output_file" "$encryption_passphrase"; then
        log_success "Encrypted password file created: $output_file"
        
        # Secure cleanup
        shred -vfz -n 3 "$temp_passwords" 2>/dev/null || rm -f "$temp_passwords"
        
        return 0
    else
        log_error "Failed to create encrypted password file"
        shred -vfz -n 3 "$temp_passwords" 2>/dev/null || rm -f "$temp_passwords"
        return 1
    fi
}

# Create password file from existing data
create_password_file_from_data() {
    local output_file="$1"
    local encryption_passphrase="$2"
    local user_password="$3"
    local root_password="$4"
    local luks_passphrase="${5:-}"
    local wifi_password="${6:-}"
    
    # Create temporary file for password data
    local temp_passwords="/tmp/passwords_data_$$"
    
    cat > "$temp_passwords" << EOF
# Password configuration file
# Created: $(date -Iseconds)

user_password: "$user_password"
root_password: "$root_password"
EOF
    
    # Add optional passwords
    if [[ -n "$luks_passphrase" ]]; then
        echo "luks_passphrase: \"$luks_passphrase\"" >> "$temp_passwords"
    fi
    
    if [[ -n "$wifi_password" ]]; then
        echo "wifi_password: \"$wifi_password\"" >> "$temp_passwords"
    fi
    
    # Encrypt the password file
    if encrypt_password_file "$temp_passwords" "$output_file" "$encryption_passphrase"; then
        log_success "Encrypted password file created from data: $output_file"
        
        # Secure cleanup
        shred -vfz -n 3 "$temp_passwords" 2>/dev/null || rm -f "$temp_passwords"
        
        return 0
    else
        log_error "Failed to create encrypted password file from data"
        shred -vfz -n 3 "$temp_passwords" 2>/dev/null || rm -f "$temp_passwords"
        return 1
    fi
}

# Verify encrypted file integrity
verify_encrypted_file() {
    local encrypted_file="$1"
    local passphrase="$2"
    
    log_info "Verifying encrypted file integrity..."
    
    # Try to decrypt and check structure
    local decrypted_content
    if decrypted_content=$(decrypt_password_file "$encrypted_file" "$passphrase"); then
        # Check for required fields
        local valid_structure=true
        
        if ! echo "$decrypted_content" | grep -q "^user_password:"; then
            log_warn "Missing user_password in encrypted file"
            valid_structure=false
        fi
        
        if ! echo "$decrypted_content" | grep -q "^root_password:"; then
            log_warn "Missing root_password in encrypted file"
            valid_structure=false
        fi
        
        if [[ "$valid_structure" == true ]]; then
            log_success "Encrypted file structure is valid"
            return 0
        else
            log_error "Encrypted file has invalid structure"
            return 1
        fi
    else
        log_error "Failed to decrypt file for verification"
        return 1
    fi
}

# Show encrypted file info
show_encrypted_file_info() {
    local encrypted_file="$1"
    
    if [[ ! -f "$encrypted_file" ]]; then
        log_error "File not found: $encrypted_file"
        return 1
    fi
    
    echo -e "${PURPLE}Encrypted Password File Information:${NC}"
    echo "File: $encrypted_file"
    echo "Size: $(stat -f%z "$encrypted_file" 2>/dev/null || stat -c%s "$encrypted_file" 2>/dev/null || echo "unknown") bytes"
    echo "Permissions: $(stat -f%A "$encrypted_file" 2>/dev/null || stat -c%a "$encrypted_file" 2>/dev/null || echo "unknown")"
    echo
    
    # Extract metadata from header
    echo -e "${BLUE}Metadata:${NC}"
    sed '/^---ENCRYPTED-DATA---$/q' "$encrypted_file" | head -n -1 | grep -E "^#" | sed 's/^# /  /'
}

# Help function
show_help() {
    cat << 'EOF'
Encrypted File Password Handler

This module handles password storage and retrieval using AES-256 encrypted files.

Functions:
  load_encrypted_passwords        - Load passwords from encrypted file
  create_password_file_interactive - Create encrypted file interactively
  create_password_file_from_data  - Create encrypted file from provided data
  verify_encrypted_file           - Verify file integrity and structure
  show_encrypted_file_info        - Show file information and metadata

Environment Variables:
  DEPLOY_PASSWORD_FILE       - Path to encrypted password file
  DEPLOY_FILE_PASSPHRASE     - Passphrase for encrypted file

Usage Examples:

1. Create encrypted password file:
   ./encrypted_file_handler.sh create passwords.enc

2. Load passwords from encrypted file:
   export DEPLOY_PASSWORD_FILE="passwords.enc"
   export DEPLOY_FILE_PASSPHRASE="file_passphrase"
   source encrypted_file_handler.sh
   load_encrypted_passwords

3. Verify encrypted file:
   ./encrypted_file_handler.sh verify passwords.enc

Security Features:
- AES-256-CBC encryption
- PBKDF2 key derivation with 100,000 iterations
- Secure file permissions (600)
- Base64 encoding for safe storage
- Secure memory cleanup
- File integrity verification

File Format:
The encrypted file contains a metadata header followed by base64-encoded encrypted data.
The decrypted content is in YAML-like format with password fields.

EOF
}

# Main execution
main() {
    # Check prerequisites
    if ! check_openssl; then
        exit 1
    fi
    
    case "${1:-help}" in
        "create")
            local output_file="${2:-passwords.enc}"
            echo -e "${BLUE}Enter passphrase for encrypting the password file:${NC}"
            local encryption_passphrase
            read -s encryption_passphrase
            echo
            create_password_file_interactive "$output_file" "$encryption_passphrase"
            ;;
        "load")
            PASSWORD_FILE="${2:-}"
            FILE_PASSPHRASE="${3:-}"
            load_encrypted_passwords
            ;;
        "verify")
            local file_path="${2:-}"
            if [[ -z "$file_path" ]]; then
                log_error "File path required for verification"
                exit 1
            fi
            echo -e "${BLUE}Enter passphrase for encrypted file:${NC}"
            local verify_passphrase
            read -s verify_passphrase
            echo
            verify_encrypted_file "$file_path" "$verify_passphrase"
            ;;
        "info")
            local file_path="${2:-}"
            if [[ -z "$file_path" ]]; then
                log_error "File path required for info"
                exit 1
            fi
            show_encrypted_file_info "$file_path"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {create|load|verify|info|help} [options]"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi