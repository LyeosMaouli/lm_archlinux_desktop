#!/bin/bash
# File Password Delivery
# Saves generated passwords to various file formats

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
OUTPUT_FILE=""
OUTPUT_FORMAT="yaml"
ENCRYPT_OUTPUT=false
COMPRESSION=false

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

# Prepare password data for file output
prepare_password_data() {
    local format="$1"
    
    # Get passwords from environment
    local user_password="${USER_PASSWORD:-}"
    local root_password="${ROOT_PASSWORD:-}"
    local luks_passphrase="${LUKS_PASSPHRASE:-}"
    local wifi_password="${WIFI_PASSWORD:-}"
    
    case "$format" in
        "yaml"|"yml")
            cat << EOF
# Generated Passwords for Arch Linux Deployment
# Created: $(date -Iseconds)
# Generator: Arch Linux Hyprland Desktop Automation
#
# SECURITY WARNING: This file contains sensitive password information!
# - Store securely and delete after deployment
# - Do not commit to version control
# - Use encrypted storage when possible

passwords:
  user_password: "$user_password"
  root_password: "$root_password"
  luks_passphrase: "$luks_passphrase"
  wifi_password: "$wifi_password"

# Deployment usage:
# 1. Export environment variables:
#    export DEPLOY_USER_PASSWORD="$user_password"
#    export DEPLOY_ROOT_PASSWORD="$root_password"
#    export DEPLOY_LUKS_PASSPHRASE="$luks_passphrase"
#    export DEPLOY_WIFI_PASSWORD="$wifi_password"
#
# 2. Run deployment:
#    ./zero_touch_deploy.sh --password-mode env

metadata:
  generated_at: "$(date -Iseconds)"
  generator: "arch_linux_automation"
  format_version: "1.0"
EOF
            ;;
            
        "json")
            cat << EOF
{
  "metadata": {
    "generated_at": "$(date -Iseconds)",
    "generator": "arch_linux_automation",
    "format_version": "1.0",
    "warning": "This file contains sensitive password information!"
  },
  "passwords": {
    "user_password": "$user_password",
    "root_password": "$root_password",
    "luks_passphrase": "$luks_passphrase",
    "wifi_password": "$wifi_password"
  },
  "deployment": {
    "environment_variables": {
      "DEPLOY_USER_PASSWORD": "$user_password",
      "DEPLOY_ROOT_PASSWORD": "$root_password",
      "DEPLOY_LUKS_PASSPHRASE": "$luks_passphrase",
      "DEPLOY_WIFI_PASSWORD": "$wifi_password"
    },
    "usage": [
      "Export the environment variables above",
      "Run: ./zero_touch_deploy.sh --password-mode env"
    ]
  }
}
EOF
            ;;
            
        "env"|"bash")
            cat << EOF
#!/bin/bash
# Generated Environment Variables for Arch Linux Deployment
# Created: $(date -Iseconds)
#
# SECURITY WARNING: This file contains sensitive password information!
# Usage: source this file to set environment variables

# User account password
export DEPLOY_USER_PASSWORD="$user_password"

# Root account password
export DEPLOY_ROOT_PASSWORD="$root_password"

# LUKS encryption passphrase
export DEPLOY_LUKS_PASSPHRASE="$luks_passphrase"

# WiFi network password
export DEPLOY_WIFI_PASSWORD="$wifi_password"

# Deployment command
# ./zero_touch_deploy.sh --password-mode env

echo "Environment variables set for Arch Linux deployment"
echo "Run: ./zero_touch_deploy.sh --password-mode env"
EOF
            ;;
            
        "xml")
            cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<arch_linux_passwords>
  <metadata>
    <generated_at>$(date -Iseconds)</generated_at>
    <generator>arch_linux_automation</generator>
    <format_version>1.0</format_version>
    <warning>This file contains sensitive password information!</warning>
  </metadata>
  
  <passwords>
    <user_password>$user_password</user_password>
    <root_password>$root_password</root_password>
    <luks_passphrase>$luks_passphrase</luks_passphrase>
    <wifi_password>$wifi_password</wifi_password>
  </passwords>
  
  <deployment>
    <environment_variables>
      <variable name="DEPLOY_USER_PASSWORD" value="$user_password"/>
      <variable name="DEPLOY_ROOT_PASSWORD" value="$root_password"/>
      <variable name="DEPLOY_LUKS_PASSPHRASE" value="$luks_passphrase"/>
      <variable name="DEPLOY_WIFI_PASSWORD" value="$wifi_password"/>
    </environment_variables>
    <command>./zero_touch_deploy.sh --password-mode env</command>
  </deployment>
</arch_linux_passwords>
EOF
            ;;
            
        "csv")
            cat << EOF
field,value,description
user_password,$user_password,User account password
root_password,$root_password,Root account password
luks_passphrase,$luks_passphrase,LUKS encryption passphrase
wifi_password,$wifi_password,WiFi network password
generated_at,$(date -Iseconds),Generation timestamp
EOF
            ;;
            
        "ini")
            cat << EOF
# Generated Passwords for Arch Linux Deployment
# Created: $(date -Iseconds)

[passwords]
user_password = $user_password
root_password = $root_password
luks_passphrase = $luks_passphrase
wifi_password = $wifi_password

[metadata]
generated_at = $(date -Iseconds)
generator = arch_linux_automation
format_version = 1.0

[deployment]
command = ./zero_touch_deploy.sh --password-mode env

# Environment variables to export:
# export DEPLOY_USER_PASSWORD="$user_password"
# export DEPLOY_ROOT_PASSWORD="$root_password" 
# export DEPLOY_LUKS_PASSPHRASE="$luks_passphrase"
# export DEPLOY_WIFI_PASSWORD="$wifi_password"
EOF
            ;;
            
        "txt"|"text")
            cat << EOF
ARCH LINUX DEPLOYMENT PASSWORDS
================================
Generated: $(date -Iseconds)

SECURITY WARNING: This file contains sensitive password information!
Store securely and delete after deployment.

PASSWORDS:
----------
User Account Password:    $user_password
Root Account Password:    $root_password
LUKS Encryption Passphrase: $luks_passphrase
WiFi Network Password:    $wifi_password

DEPLOYMENT USAGE:
-----------------
1. Export environment variables:
   export DEPLOY_USER_PASSWORD="$user_password"
   export DEPLOY_ROOT_PASSWORD="$root_password"
   export DEPLOY_LUKS_PASSPHRASE="$luks_passphrase"
   export DEPLOY_WIFI_PASSWORD="$wifi_password"

2. Run deployment:
   ./zero_touch_deploy.sh --password-mode env

SECURITY NOTES:
---------------
- Store this file securely
- Do not commit to version control
- Delete after successful deployment
- Use encrypted storage when possible
- Never share passwords via insecure channels
EOF
            ;;
            
        *)
            log_error "Unsupported format: $format"
            return 1
            ;;
    esac
}

# Save password data to file
save_password_file() {
    local output_file="$1"
    local format="$2"
    local encrypt="${3:-false}"
    local compress="${4:-false}"
    
    log_info "Saving passwords to file: $output_file (format: $format)"
    
    # Prepare password data
    local password_data
    password_data=$(prepare_password_data "$format")
    
    # Create temporary file
    local temp_file="/tmp/password_output_$$"
    echo "$password_data" > "$temp_file"
    
    # Process file based on options
    local final_file="$temp_file"
    
    # Encrypt if requested
    if [[ "$encrypt" == "true" ]]; then
        log_info "Encrypting password file..."
        
        echo -e "${BLUE}Enter encryption passphrase:${NC}"
        local encryption_passphrase
        read -s encryption_passphrase
        echo
        
        local encrypted_file="/tmp/password_encrypted_$$"
        if openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$temp_file" -out "$encrypted_file" -k "$encryption_passphrase" 2>/dev/null; then
            final_file="$encrypted_file"
            log_success "Password file encrypted"
        else
            log_error "Failed to encrypt password file"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    fi
    
    # Compress if requested
    if [[ "$compress" == "true" ]]; then
        log_info "Compressing password file..."
        
        if command -v gzip >/dev/null 2>&1; then
            local compressed_file="/tmp/password_compressed_$$"
            if gzip -c "$final_file" > "$compressed_file"; then
                final_file="$compressed_file"
                output_file="$output_file.gz"
                log_success "Password file compressed"
            else
                log_error "Failed to compress password file"
            fi
        else
            log_warn "gzip not available, skipping compression"
        fi
    fi
    
    # Copy to final destination
    if cp "$final_file" "$output_file"; then
        # Set secure permissions
        chmod 600 "$output_file"
        
        log_success "Password file saved: $output_file"
        
        # Show file information
        show_file_info "$output_file" "$format" "$encrypt" "$compress"
        
        # Cleanup temporary files
        rm -f "$temp_file" "/tmp/password_encrypted_$$" "/tmp/password_compressed_$$" 2>/dev/null
        
        return 0
    else
        log_error "Failed to save password file"
        rm -f "$temp_file" "/tmp/password_encrypted_$$" "/tmp/password_compressed_$$" 2>/dev/null
        return 1
    fi
}

# Show file information
show_file_info() {
    local file_path="$1"
    local format="$2"
    local encrypted="$3"
    local compressed="$4"
    
    echo
    echo -e "${PURPLE}📄 Password File Information:${NC}"
    echo "File: $file_path"
    echo "Format: $format"
    echo "Size: $(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "unknown") bytes"
    echo "Permissions: $(stat -c%a "$file_path" 2>/dev/null || stat -f%A "$file_path" 2>/dev/null || echo "unknown")"
    echo "Encrypted: $encrypted"
    echo "Compressed: $compressed"
    echo "Created: $(date)"
    echo
}

# Generate multiple formats
generate_multiple_formats() {
    local base_name="$1"
    local formats=("yaml" "json" "env" "txt")
    local encrypt="$2"
    local compress="$3"
    
    log_info "Generating multiple password file formats..."
    
    for format in "${formats[@]}"; do
        local extension="$format"
        [[ "$format" == "env" ]] && extension="sh"
        [[ "$format" == "txt" ]] && extension="txt"
        
        local output_file="${base_name}.${extension}"
        
        if save_password_file "$output_file" "$format" "$encrypt" "$compress"; then
            log_success "Generated: $output_file"
        else
            log_error "Failed to generate: $output_file"
        fi
    done
}

# Create password backup archive
create_backup_archive() {
    local archive_name="$1"
    local encrypt="$2"
    
    log_info "Creating password backup archive..."
    
    # Create temporary directory
    local temp_dir="/tmp/password_backup_$$"
    mkdir -p "$temp_dir"
    
    # Generate files in different formats
    local formats=("yaml" "json" "env" "txt" "xml" "csv" "ini")
    
    for format in "${formats[@]}"; do
        local extension="$format"
        [[ "$format" == "env" ]] && extension="sh"
        
        local file_path="$temp_dir/passwords.$extension"
        local password_data
        password_data=$(prepare_password_data "$format")
        echo "$password_data" > "$file_path"
        chmod 600 "$file_path"
    done
    
    # Create README
    cat > "$temp_dir/README.txt" << EOF
ARCH LINUX DEPLOYMENT PASSWORD ARCHIVE
======================================

This archive contains generated passwords in multiple formats:

- passwords.yaml - YAML format (recommended)
- passwords.json - JSON format
- passwords.sh   - Bash environment variables
- passwords.txt  - Plain text format
- passwords.xml  - XML format
- passwords.csv  - CSV format  
- passwords.ini  - INI format

USAGE:
------
1. Choose your preferred format
2. Export the environment variables
3. Run: ./zero_touch_deploy.sh --password-mode env

SECURITY:
---------
- Keep this archive secure
- Delete after deployment
- Do not share via insecure channels

Generated: $(date -Iseconds)
EOF
    
    # Create archive
    if command -v tar >/dev/null 2>&1; then
        local archive_file="$archive_name.tar.gz"
        
        if tar -czf "$archive_file" -C "$(dirname "$temp_dir")" "$(basename "$temp_dir")"; then
            # Encrypt if requested
            if [[ "$encrypt" == "true" ]]; then
                echo -e "${BLUE}Enter encryption passphrase for archive:${NC}"
                local encryption_passphrase
                read -s encryption_passphrase
                echo
                
                local encrypted_archive="$archive_name.tar.gz.enc"
                if openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$archive_file" -out "$encrypted_archive" -k "$encryption_passphrase" 2>/dev/null; then
                    rm -f "$archive_file"
                    archive_file="$encrypted_archive"
                    log_success "Archive encrypted"
                fi
            fi
            
            chmod 600 "$archive_file"
            log_success "Password archive created: $archive_file"
        else
            log_error "Failed to create archive"
        fi
    else
        log_error "tar command not available"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Show help information
show_help() {
    cat << 'EOF'
File Password Delivery

Saves generated passwords to various file formats with optional encryption and compression.

Functions:
  save_password_file           - Save passwords to single file
  generate_multiple_formats    - Generate multiple file formats
  create_backup_archive        - Create comprehensive password archive
  prepare_password_data        - Format password data for output

Supported Formats:
  yaml, yml    - YAML format (recommended)
  json         - JSON structured data
  env, bash    - Bash environment variables
  xml          - XML format
  csv          - Comma-separated values
  ini          - INI configuration format
  txt, text    - Plain text format

Options:
  --encrypt    - Encrypt output with AES-256
  --compress   - Compress output with gzip
  --archive    - Create multi-format archive

File Extensions:
  Format extensions are automatically applied:
  - yaml/yml → .yaml
  - json → .json
  - env/bash → .sh
  - txt/text → .txt
  - xml → .xml
  - csv → .csv
  - ini → .ini

Usage Examples:

1. Save YAML password file:
   save_password_file "passwords.yaml" "yaml" false false

2. Save encrypted JSON file:
   save_password_file "passwords.json" "json" true false

3. Generate multiple formats:
   generate_multiple_formats "deployment_passwords" false false

4. Create encrypted backup archive:
   create_backup_archive "password_backup" true

Security Features:
- AES-256 encryption with PBKDF2 key derivation
- Secure file permissions (600)
- Gzip compression support
- Multiple format support
- Comprehensive security warnings in output

File Contents:
Each file includes:
- Generated passwords
- Usage instructions
- Security warnings
- Deployment commands
- Metadata and timestamps

EOF
}

# Main execution
main() {
    local action="${1:-save}"
    
    case "$action" in
        "save")
            local output_file="${2:-passwords.yaml}"
            local format="${3:-yaml}"
            local encrypt="${4:-false}"
            local compress="${5:-false}"
            save_password_file "$output_file" "$format" "$encrypt" "$compress"
            ;;
        "multi")
            local base_name="${2:-deployment_passwords}"
            local encrypt="${3:-false}"
            local compress="${4:-false}"
            generate_multiple_formats "$base_name" "$encrypt" "$compress"
            ;;
        "archive")
            local archive_name="${2:-password_backup}"
            local encrypt="${3:-false}"
            create_backup_archive "$archive_name" "$encrypt"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {save|multi|archive|help} [options]"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi