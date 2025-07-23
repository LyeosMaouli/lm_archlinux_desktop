#!/bin/bash
# Password File Creation Utility
# Creates encrypted password files for automated deployment

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Script configuration
SECURITY_DIR="$SCRIPT_DIR/../security"
OUTPUT_FILE=""
ENCRYPT_OUTPUT=true
INTERACTIVE_MODE=true


# Print banner
print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║            [PASSWORD] Password File Creation Utility               ║
║                                                              ║
║        Create encrypted password files for deployment       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check for encrypted file handler
    local encrypted_handler="$SECURITY_DIR/encrypted_file_handler.sh"
    if [[ ! -f "$encrypted_handler" ]]; then
        log_error "Encrypted file handler not found: $encrypted_handler"
        return 1
    fi
    
    # Check for OpenSSL
    if ! command -v openssl >/dev/null 2>&1; then
        log_error "OpenSSL not found. Please install OpenSSL."
        return 1
    fi
    
    log_success "All dependencies available"
    return 0
}

# Load encrypted file handler
load_file_handler() {
    local encrypted_handler="$SECURITY_DIR/encrypted_file_handler.sh"
    source "$encrypted_handler"
    log_info "Encrypted file handler loaded"
}

# Interactive password collection
collect_passwords_interactive() {
    echo -e "${BLUE}[CONFIG] Interactive Password Collection${NC}"
    echo "Please enter the passwords you want to store in the encrypted file."
    echo "Press Enter to skip optional passwords."
    echo
    
    # User password (required)
    local user_password
    while true; do
        echo -e "${BLUE}User account password (required):${NC}"
        read -s user_password
        echo
        
        if [[ ${#user_password} -ge 8 ]]; then
            echo -e "${BLUE}Confirm user password:${NC}"
            local user_password_confirm
            read -s user_password_confirm
            echo
            
            if [[ "$user_password" == "$user_password_confirm" ]]; then
                break
            else
                echo -e "${RED}[ERROR] Passwords don't match, try again${NC}"
            fi
        else
            echo -e "${RED}[ERROR] Password must be at least 8 characters${NC}"
        fi
    done
    
    # Root password (required)
    local root_password
    while true; do
        echo -e "${BLUE}Root account password (required):${NC}"
        read -s root_password
        echo
        
        if [[ ${#root_password} -ge 8 ]]; then
            echo -e "${BLUE}Confirm root password:${NC}"
            local root_password_confirm
            read -s root_password_confirm
            echo
            
            if [[ "$root_password" == "$root_password_confirm" ]]; then
                break
            else
                echo -e "${RED}[ERROR] Passwords don't match, try again${NC}"
            fi
        else
            echo -e "${RED}[ERROR] Password must be at least 8 characters${NC}"
        fi
    done
    
    # LUKS passphrase (optional)
    echo -e "${BLUE}LUKS encryption passphrase (optional, press Enter to skip):${NC}"
    local luks_passphrase
    read -s luks_passphrase
    echo
    
    # WiFi password (optional)
    echo -e "${BLUE}WiFi password (optional, press Enter to skip):${NC}"
    local wifi_password
    read -s wifi_password
    echo
    
    # Store in variables for later use
    export COLLECTED_USER_PASSWORD="$user_password"
    export COLLECTED_ROOT_PASSWORD="$root_password"
    export COLLECTED_LUKS_PASSPHRASE="$luks_passphrase"
    export COLLECTED_WIFI_PASSWORD="$wifi_password"
    
    log_success "Password collection completed"
}

# Command line password collection
collect_passwords_cmdline() {
    local user_password="$1"
    local root_password="$2"
    local luks_passphrase="${3:-}"
    local wifi_password="${4:-}"
    
    # Validate required passwords
    if [[ -z "${user_password:-}" ]] || [[ -z "${root_password:-}" ]]; then
        log_error "User and root passwords are required"
        return 1
    fi
    
    if [[ ${#user_password} -lt 8 ]] || [[ ${#root_password} -lt 8 ]]; then
        log_error "Passwords must be at least 8 characters"
        return 1
    fi
    
    # Store in variables
    export COLLECTED_USER_PASSWORD="$user_password"
    export COLLECTED_ROOT_PASSWORD="$root_password"
    export COLLECTED_LUKS_PASSPHRASE="$luks_passphrase"
    export COLLECTED_WIFI_PASSWORD="$wifi_password"
    
    log_success "Command line passwords validated"
}

# Get file encryption passphrase
get_encryption_passphrase() {
    local passphrase
    
    while true; do
        echo -e "${BLUE}Enter passphrase to encrypt the password file:${NC}"
        echo "(You'll need this passphrase to decrypt the file later)"
        read -s passphrase
        echo
        
        if [[ ${#passphrase} -ge 12 ]]; then
            echo -e "${BLUE}Confirm encryption passphrase:${NC}"
            local passphrase_confirm
            read -s passphrase_confirm
            echo
            
            if [[ "$passphrase" == "$passphrase_confirm" ]]; then
                echo "$passphrase"
                return 0
            else
                echo -e "${RED}[ERROR] Passphrases don't match, try again${NC}"
            fi
        else
            echo -e "${RED}[ERROR] Passphrase must be at least 12 characters${NC}"
        fi
    done
}

# Create password file
create_password_file() {
    local output_file="$1"
    local encryption_passphrase="$2"
    
    log_info "Creating password file: $output_file"
    
    # Load encrypted file handler
    load_file_handler
    
    # Create password file using the handler
    if create_password_file_from_data \
        "$output_file" \
        "$encryption_passphrase" \
        "$COLLECTED_USER_PASSWORD" \
        "$COLLECTED_ROOT_PASSWORD" \
        "$COLLECTED_LUKS_PASSPHRASE" \
        "$COLLECTED_WIFI_PASSWORD"; then
        
        log_success "Encrypted password file created successfully"
        return 0
    else
        log_error "Failed to create encrypted password file"
        return 1
    fi
}

# Verify created file
verify_password_file() {
    local password_file="$1"
    local encryption_passphrase="$2"
    
    log_info "Verifying password file integrity..."
    
    # Load encrypted file handler
    load_file_handler
    
    if verify_encrypted_file "$password_file" "$encryption_passphrase"; then
        log_success "Password file verification successful"
        
        # Show file information
        echo
        show_encrypted_file_info "$password_file"
        
        return 0
    else
        log_error "Password file verification failed"
        return 1
    fi
}

# Generate example configuration
generate_example_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
# Example Deployment Configuration
# Use this with your encrypted password file

system:
  hostname: "my-archlinux"
  timezone: "UTC"
  locale: "en_US.UTF-8"
  keymap: "us"

user:
  username: "myuser"
  password: ""  # Will be loaded from encrypted file
  shell: "/bin/bash"

network:
  ethernet:
    enabled: true
    dhcp: true
  wifi:
    enabled: true
    ssid: ""      # Will be loaded from encrypted file if provided
    password: ""  # Will be loaded from encrypted file if provided

disk:
  device: "/dev/sda"
  encryption:
    enabled: true
    passphrase: ""  # Will be loaded from encrypted file

automation:
  skip_confirmations: true
  auto_reboot: false

# Usage:
# 1. Create encrypted password file: ./create_password_file.sh
# 2. Edit this config file as needed
# 3. Deploy: ./scripts/deploy.sh full --password file --password-file passwords.enc
EOF
    
    log_success "Example configuration created: $config_file"
}

# Show usage examples
show_usage_examples() {
    cat << 'EOF'

[LIST] Usage Examples:

1. Create encrypted password file interactively:
   ./create_password_file.sh

2. Create encrypted password file with specific output:
   ./create_password_file.sh --output my_passwords.enc

3. Create from command line (non-interactive):
   ./create_password_file.sh --user-password "secure123" --root-password "secure456" --output passwords.enc

4. Create with all passwords:
   ./create_password_file.sh \
     --user-password "user_pass" \
     --root-password "root_pass" \
     --luks-passphrase "luks_passphrase" \
     --wifi-password "wifi_pass" \
     --output complete_passwords.enc

5. Use created file with deployment:
   ./scripts/deploy.sh full --password file --password-file passwords.enc

6. Verify existing password file:
   ./create_password_file.sh --verify passwords.enc

7. Generate example configuration:
   ./create_password_file.sh --example-config deployment.yml

EOF
}

# Parse command line arguments
parse_arguments() {
    local user_password=""
    local root_password=""
    local luks_passphrase=""
    local wifi_password=""
    local verify_file=""
    local example_config=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output|-o)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --user-password)
                user_password="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --root-password)
                root_password="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --luks-passphrase)
                luks_passphrase="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --wifi-password)
                wifi_password="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --no-encrypt)
                ENCRYPT_OUTPUT=false
                shift
                ;;
            --verify)
                verify_file="$2"
                shift 2
                ;;
            --example-config)
                example_config="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Handle special modes
    if [[ -n "${verify_file:-}" ]]; then
        verify_existing_file "$verify_file"
        exit $?
    fi
    
    if [[ -n "${example_config:-}" ]]; then
        generate_example_config "$example_config"
        exit 0
    fi
    
    # Collect passwords based on mode
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        collect_passwords_interactive
    else
        collect_passwords_cmdline "$user_password" "$root_password" "$luks_passphrase" "$wifi_password"
    fi
}

# Verify existing file
verify_existing_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    echo -e "${BLUE}Enter passphrase for encrypted file:${NC}"
    local passphrase
    read -s passphrase
    echo
    
    load_file_handler
    verify_encrypted_file "$file_path" "$passphrase"
}

# Show help information
show_help() {
    cat << 'EOF'
Password File Creation Utility

Creates encrypted password files for automated Arch Linux deployment.

Usage: create_password_file.sh [OPTIONS]

Options:
  --output FILE, -o FILE       Output file path (default: passwords_YYYYMMDD_HHMMSS.enc)
  --user-password PASSWORD     User account password (non-interactive mode)
  --root-password PASSWORD     Root account password (non-interactive mode)
  --luks-passphrase PHRASE     LUKS encryption passphrase (optional)
  --wifi-password PASSWORD     WiFi network password (optional)
  --no-encrypt                 Save as plain text (NOT recommended)
  --verify FILE                Verify existing encrypted password file
  --example-config FILE        Generate example deployment configuration
  --help, -h                   Show this help message

Interactive Mode (default):
  Run without password options to enter passwords securely.

Non-Interactive Mode:
  Provide --user-password and --root-password to skip prompts.

Security Features:
  - AES-256 encryption
  - Secure password prompts (no echo)
  - Password strength validation
  - File integrity verification
  - Secure file permissions (600)

File Format:
  The encrypted file contains password data in YAML-like format:
  - user_password: User account password
  - root_password: Root account password  
  - luks_passphrase: LUKS encryption passphrase (optional)
  - wifi_password: WiFi network password (optional)

EOF
    show_usage_examples
}

# Main execution
main() {
    print_banner
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Parse arguments
    parse_arguments "$@"
    
    # Set default output file if not specified
    if [[ -z "${OUTPUT_FILE:-}" ]]; then
        OUTPUT_FILE="passwords_$(date +%Y%m%d_%H%M%S).enc"
    fi
    
    # Get encryption passphrase
    local encryption_passphrase
    if [[ "$ENCRYPT_OUTPUT" == "true" ]]; then
        encryption_passphrase=$(get_encryption_passphrase)
    else
        log_warn "Creating unencrypted password file - NOT recommended for production!"
        encryption_passphrase=""
    fi
    
    # Create password file
    if [[ "$ENCRYPT_OUTPUT" == "true" ]]; then
        if create_password_file "$OUTPUT_FILE" "$encryption_passphrase"; then
            echo
            verify_password_file "$OUTPUT_FILE" "$encryption_passphrase"
        fi
    else
        # Create plain text file (not recommended)
        cat > "$OUTPUT_FILE" << EOF
# Plain Text Password File - NOT RECOMMENDED FOR PRODUCTION
# Created: $(date -Iseconds)

user_password: "$COLLECTED_USER_PASSWORD"
root_password: "$COLLECTED_ROOT_PASSWORD"
EOF
        
        if [[ -n "${COLLECTED_LUKS_PASSPHRASE:-}" ]]; then
            echo "luks_passphrase: \"$COLLECTED_LUKS_PASSPHRASE\"" >> "$OUTPUT_FILE"
        fi
        
        if [[ -n "${COLLECTED_WIFI_PASSWORD:-}" ]]; then
            echo "wifi_password: \"$COLLECTED_WIFI_PASSWORD\"" >> "$OUTPUT_FILE"
        fi
        
        chmod 600 "$OUTPUT_FILE"
        log_warn "Plain text password file created: $OUTPUT_FILE"
    fi
    
    # Show completion information
    echo
    echo -e "${GREEN}[COMPLETE] Password file creation completed!${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Keep the password file secure: ${YELLOW}$OUTPUT_FILE${NC}"
    echo "2. Remember your encryption passphrase"
    echo "3. Use with deployment:"
    echo "   ${YELLOW}./zero_touch_deploy.sh --password-mode file --password-file $OUTPUT_FILE${NC}"
    echo
    echo -e "${YELLOW}[WARNING]  Security Reminder:${NC}"
    echo "- Store the password file securely"
    echo "- Don't commit it to version control"
    echo "- Delete it after deployment if no longer needed"
    echo "- Keep backups of important passphrases"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi