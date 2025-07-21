#!/bin/bash
# QR Code Password Delivery
# Generates QR codes for password delivery and display

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
QR_OUTPUT_FILE=""
QR_FORMAT="terminal"  # terminal, png, svg
QR_ERROR_CORRECTION="M"  # L, M, Q, H

# Logging functions
log_info() {
    echo -e "${BLUE}[QR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[QR-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[QR-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[QR-SUCCESS]${NC} $1" >&2
}

# Check QR code dependencies
check_qr_dependencies() {
    log_info "Checking QR code dependencies..."
    
    local available_tools=()
    
    # Check for qrencode (preferred)
    if command -v qrencode >/dev/null 2>&1; then
        available_tools+=("qrencode")
    fi
    
    # Check for python qrcode module
    if python3 -c "import qrcode" 2>/dev/null; then
        available_tools+=("python-qrcode")
    fi
    
    if [[ ${#available_tools[@]:-0} -eq 0 ]]; then
        log_error "No QR code generation tools available"
        log_info "Please install: qrencode or python3-qrcode"
        return 1
    fi
    
    log_success "Available QR tools: ${available_tools[*]}"
    return 0
}

# Generate QR code using qrencode
generate_qr_qrencode() {
    local data="$1"
    local output_file="$2"
    local format="$3"
    
    case "$format" in
        "terminal"|"ansi")
            qrencode -t ansiutf8 -l "$QR_ERROR_CORRECTION" "$data"
            ;;
        "png")
            qrencode -t png -l "$QR_ERROR_CORRECTION" -o "$output_file" "$data"
            log_success "QR code saved as PNG: $output_file"
            ;;
        "svg")
            qrencode -t svg -l "$QR_ERROR_CORRECTION" -o "$output_file" "$data"
            log_success "QR code saved as SVG: $output_file"
            ;;
        *)
            log_error "Unsupported QR format: $format"
            return 1
            ;;
    esac
}

# Generate QR code using Python
generate_qr_python() {
    local data="$1"
    local output_file="$2"
    local format="$3"
    
    python3 << EOF
import qrcode
import sys

# Create QR code instance
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_M,
    box_size=10,
    border=4,
)

qr.add_data("""$data""")
qr.make(fit=True)

# Generate based on format
if "$format" == "terminal":
    qr.print_ascii(out=sys.stdout)
elif "$format" == "png":
    img = qr.make_image(fill_color="black", back_color="white")
    img.save("$output_file")
    print("QR code saved as PNG: $output_file", file=sys.stderr)
else:
    print("Unsupported format: $format", file=sys.stderr)
    sys.exit(1)
EOF
}

# Prepare password data for QR code
prepare_password_data() {
    local format="${1:-compact}"
    
    # Get passwords from environment
    local user_password="${USER_PASSWORD:-}"
    local root_password="${ROOT_PASSWORD:-}"
    local luks_passphrase="${LUKS_PASSPHRASE:-}"
    local wifi_password="${WIFI_PASSWORD:-}"
    
    case "$format" in
        "compact")
            # Compact format for smaller QR codes
            local data="U:$user_password|R:$root_password"
            [[ -n "$luks_passphrase" ]] && data="$data|L:$luks_passphrase"
            [[ -n "$wifi_password" ]] && data="$data|W:$wifi_password"
            echo "$data"
            ;;
        "json")
            # JSON format for structured data
            cat << EOF
{"user":"$user_password","root":"$root_password","luks":"$luks_passphrase","wifi":"$wifi_password"}
EOF
            ;;
        "yaml")
            # YAML format
            cat << EOF
user_password: "$user_password"
root_password: "$root_password"
luks_passphrase: "$luks_passphrase"  
wifi_password: "$wifi_password"
EOF
            ;;
        *)
            log_error "Unknown data format: $format"
            return 1
            ;;
    esac
}

# Display QR code with instructions
display_qr_with_instructions() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                              ║${NC}"
    echo -e "${PURPLE}║                    [PASSWORD] Password QR Code                     ║${NC}"
    echo -e "${PURPLE}║                                                              ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${BLUE}📱 Scan this QR code to transfer passwords securely:${NC}"
    echo
    
    # Generate and display QR code
    local qr_data
    qr_data=$(prepare_password_data "compact")
    
    if command -v qrencode >/dev/null 2>&1; then
        generate_qr_qrencode "$qr_data" "" "terminal"
    elif python3 -c "import qrcode" 2>/dev/null; then
        generate_qr_python "$qr_data" "" "terminal"
    else
        echo -e "${RED}[ERROR] No QR code generator available${NC}"
        return 1
    fi
    
    echo
    echo -e "${YELLOW}[LIST] QR Code Format:${NC}"
    echo "Format: U:user|R:root|L:luks|W:wifi"
    echo "Where U=User, R=Root, L=LUKS, W=WiFi passwords"
    echo
    
    echo -e "${BLUE}[SECURE] Security Notes:${NC}"
    echo "• QR code contains password data - keep secure"
    echo "• Use in trusted environments only"
    echo "• Delete any saved QR code files after use"
    echo "• Consider using encrypted QR codes for sensitive data"
    echo
    
    echo -e "${GREEN}Press Enter when you have scanned the QR code...${NC}"
    read -r
}

# Generate encrypted QR code
generate_encrypted_qr() {
    local encryption_key="$1"
    local output_file="$2"
    local format="$3"
    
    log_info "Generating encrypted QR code..."
    
    # Prepare password data
    local password_data
    password_data=$(prepare_password_data "json")
    
    # Encrypt the data
    local encrypted_data
    encrypted_data=$(echo "$password_data" | openssl enc -aes-256-cbc -a -salt -k "$encryption_key" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Generate QR code with encrypted data
        if command -v qrencode >/dev/null 2>&1; then
            generate_qr_qrencode "$encrypted_data" "$output_file" "$format"
        elif python3 -c "import qrcode" 2>/dev/null; then
            generate_qr_python "$encrypted_data" "$output_file" "$format"
        else
            log_error "No QR code generator available"
            return 1
        fi
        
        log_success "Encrypted QR code generated"
        echo -e "${BLUE}Encryption key: ${YELLOW}$encryption_key${NC}"
        echo -e "${YELLOW}[WARNING]  Save this key - needed to decrypt QR data${NC}"
        
        return 0
    else
        log_error "Failed to encrypt password data"
        return 1
    fi
}

# Save QR code to file
save_qr_to_file() {
    local output_file="$1"
    local format="$2"
    local encrypt="${3:-false}"
    
    if [[ "$encrypt" == "true" ]]; then
        echo -e "${BLUE}Enter encryption key for QR code:${NC}"
        local encryption_key
        read -s encryption_key
        echo
        
        generate_encrypted_qr "$encryption_key" "$output_file" "$format"
    else
        local qr_data
        qr_data=$(prepare_password_data "compact")
        
        if command -v qrencode >/dev/null 2>&1; then
            generate_qr_qrencode "$qr_data" "$output_file" "$format"
        elif python3 -c "import qrcode" 2>/dev/null; then
            generate_qr_python "$qr_data" "$output_file" "$format"
        else
            log_error "No QR code generator available"
            return 1
        fi
    fi
}

# Generate WiFi QR code
generate_wifi_qr() {
    local ssid="$1"
    local password="$2"
    local security="${3:-WPA}"
    local hidden="${4:-false}"
    
    # WiFi QR code format: WIFI:T:WPA;S:mynetwork;P:mypass;H:false;
    local wifi_qr_data="WIFI:T:$security;S:$ssid;P:$password;H:$hidden;"
    
    echo -e "${BLUE}📶 WiFi Network QR Code:${NC}"
    echo "Network: $ssid"
    echo "Security: $security"
    echo
    
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ansiutf8 -l "$QR_ERROR_CORRECTION" "$wifi_qr_data"
    elif python3 -c "import qrcode" 2>/dev/null; then
        python3 -c "
import qrcode
qr = qrcode.QRCode(version=1, box_size=10, border=4)
qr.add_data('$wifi_qr_data')
qr.make(fit=True)
qr.print_ascii()
"
    else
        log_error "No QR code generator available"
        return 1
    fi
    
    echo
    echo -e "${GREEN}Scan with phone camera to connect to WiFi automatically${NC}"
}

# Show help information
show_help() {
    cat << 'EOF'
QR Code Password Delivery

Generates QR codes for secure password transmission and mobile device scanning.

Functions:
  display_qr_with_instructions  - Show password QR code with usage instructions
  save_qr_to_file              - Save QR code to image file (PNG/SVG)
  generate_encrypted_qr        - Create encrypted QR code with password protection
  generate_wifi_qr             - Generate WiFi network QR code
  prepare_password_data        - Format password data for QR encoding

Supported Formats:
  terminal     - Display QR code in terminal (ANSI/UTF-8)
  png          - Save as PNG image file
  svg          - Save as SVG vector file

Data Formats:
  compact      - U:user|R:root|L:luks|W:wifi (smallest QR code)
  json         - JSON structured data
  yaml         - YAML formatted data

Dependencies:
  - qrencode (preferred) OR python3-qrcode
  - OpenSSL (for encryption)

Usage Examples:

1. Display password QR code:
   source qr_delivery.sh
   display_qr_with_instructions

2. Save QR code as PNG:
   save_qr_to_file "passwords.png" "png" false

3. Generate encrypted QR code:
   save_qr_to_file "passwords_encrypted.png" "png" true

4. WiFi QR code:
   generate_wifi_qr "MyNetwork" "wifi_password" "WPA"

Security Features:
- Compact encoding to minimize QR code size
- Optional AES-256 encryption
- Secure password prompting
- Temporary data handling
- Format validation

QR Code Scanning:
Most modern smartphones can scan QR codes with the camera app.
Use QR scanner apps for better functionality and data extraction.

EOF
}

# Main execution
main() {
    local action="${1:-display}"
    
    # Check dependencies
    if ! check_qr_dependencies; then
        exit 1
    fi
    
    case "$action" in
        "display")
            display_qr_with_instructions
            ;;
        "save")
            local output_file="${2:-passwords_qr.png}"
            local format="${3:-png}"
            local encrypt="${4:-false}"
            save_qr_to_file "$output_file" "$format" "$encrypt"
            ;;
        "wifi")
            local ssid="${2:-}"
            local password="${3:-}"
            local security="${4:-WPA}"
            if [[ -z "$ssid" ]] || [[ -z "$password" ]]; then
                log_error "WiFi SSID and password required"
                exit 1
            fi
            generate_wifi_qr "$ssid" "$password" "$security"
            ;;
        "encrypted")
            local output_file="${2:-passwords_encrypted.png}"
            local format="${3:-png}"
            save_qr_to_file "$output_file" "$format" true
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {display|save|wifi|encrypted|help} [options]"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi