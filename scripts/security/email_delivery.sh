#!/bin/bash
# Email Password Delivery
# Sends generated passwords via secure email

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
EMAIL_RECIPIENT=""
EMAIL_SUBJECT="Arch Linux Deployment Passwords"
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_USERNAME=""
SMTP_PASSWORD=""
USE_TLS="true"
ENCRYPT_EMAIL="false"
GPG_RECIPIENT=""

# Logging functions
log_info() {
    echo -e "${BLUE}[EMAIL]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[EMAIL-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[EMAIL-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[EMAIL-SUCCESS]${NC} $1" >&2
}

# Check email dependencies
check_email_dependencies() {
    log_info "Checking email dependencies..."
    
    local available_tools=()
    
    # Check for sendmail/mail command
    if command -v sendmail >/dev/null 2>&1; then
        available_tools+=("sendmail")
    fi
    
    if command -v mail >/dev/null 2>&1; then
        available_tools+=("mail")
    fi
    
    # Check for msmtp (lightweight SMTP client)
    if command -v msmtp >/dev/null 2>&1; then
        available_tools+=("msmtp")
    fi
    
    # Check for Python with email capabilities
    if python3 -c "import smtplib, ssl" 2>/dev/null; then
        available_tools+=("python-smtp")
    fi
    
    # Check for GPG if encryption requested
    if [[ "$ENCRYPT_EMAIL" == "true" ]]; then
        if ! command -v gpg >/dev/null 2>&1; then
            log_error "GPG not found - required for email encryption"
            return 1
        fi
        available_tools+=("gpg")
    fi
    
    if [[ ${#available_tools[@]} -eq 0 ]]; then
        log_error "No email sending tools available"
        log_info "Please install: sendmail, msmtp, or python3"
        return 1
    fi
    
    log_success "Available email tools: ${available_tools[*]}"
    return 0
}

# Load email configuration from environment
load_email_config() {
    EMAIL_RECIPIENT="${DEPLOY_EMAIL_RECIPIENT:-$EMAIL_RECIPIENT}"
    SMTP_SERVER="${DEPLOY_SMTP_SERVER:-$SMTP_SERVER}"
    SMTP_PORT="${DEPLOY_SMTP_PORT:-$SMTP_PORT}"
    SMTP_USERNAME="${DEPLOY_SMTP_USERNAME:-$SMTP_USERNAME}"
    SMTP_PASSWORD="${DEPLOY_SMTP_PASSWORD:-$SMTP_PASSWORD}"
    USE_TLS="${DEPLOY_USE_TLS:-$USE_TLS}"
    GPG_RECIPIENT="${DEPLOY_GPG_RECIPIENT:-$GPG_RECIPIENT}"
    
    # Check required configuration
    if [[ -z "$EMAIL_RECIPIENT" ]]; then
        log_error "Email recipient not configured"
        return 1
    fi
    
    log_info "Email configuration loaded"
    return 0
}

# Prepare password email content
prepare_email_content() {
    local format="${1:-html}"
    
    # Get passwords from environment
    local user_password="${USER_PASSWORD:-}"
    local root_password="${ROOT_PASSWORD:-}"
    local luks_passphrase="${LUKS_PASSPHRASE:-}"
    local wifi_password="${WIFI_PASSWORD:-}"
    
    case "$format" in
        "plain")
            cat << EOF
Subject: $EMAIL_SUBJECT

Arch Linux Deployment Passwords
Generated: $(date -Iseconds)

IMPORTANT: This email contains sensitive password information.
Delete this email after saving the passwords securely.

User Account Password: $user_password
Root Account Password: $root_password
EOF
            [[ -n "$luks_passphrase" ]] && echo "LUKS Encryption Passphrase: $luks_passphrase"
            [[ -n "$wifi_password" ]] && echo "WiFi Password: $wifi_password"
            cat << EOF

Security Notes:
- These passwords were generated securely for your Arch Linux deployment
- Store them in a secure password manager
- Do not forward this email
- Delete this email after use

Deployment Usage:
Export the passwords as environment variables:
export DEPLOY_USER_PASSWORD="$user_password"
export DEPLOY_ROOT_PASSWORD="$root_password"
EOF
            [[ -n "$luks_passphrase" ]] && echo "export DEPLOY_LUKS_PASSPHRASE=\"$luks_passphrase\""
            [[ -n "$wifi_password" ]] && echo "export DEPLOY_WIFI_PASSWORD=\"$wifi_password\""
            echo
            echo "Then run: ./zero_touch_deploy.sh --password-mode env"
            ;;
            
        "html")
            cat << EOF
Subject: $EMAIL_SUBJECT
Content-Type: text/html; charset=UTF-8

<!DOCTYPE html>
<html>
<head>
    <title>$EMAIL_SUBJECT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .password-section { background-color: #fff3cd; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #ffc107; }
        .password { font-family: monospace; background-color: #f8f9fa; padding: 5px; border-radius: 3px; }
        .warning { background-color: #f8d7da; color: #721c24; padding: 10px; border-radius: 5px; margin: 10px 0; }
        .usage { background-color: #d1ecf1; padding: 15px; border-radius: 5px; margin: 10px 0; }
        code { background-color: #f8f9fa; padding: 2px 4px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h2>🔐 Arch Linux Deployment Passwords</h2>
        <p><strong>Generated:</strong> $(date -Iseconds)</p>
    </div>

    <div class="warning">
        <strong>⚠️ IMPORTANT SECURITY NOTICE</strong><br>
        This email contains sensitive password information. Delete this email after saving the passwords securely.
    </div>

    <div class="password-section">
        <h3>Generated Passwords</h3>
        <p><strong>User Account Password:</strong><br><span class="password">$user_password</span></p>
        <p><strong>Root Account Password:</strong><br><span class="password">$root_password</span></p>
EOF
            [[ -n "$luks_passphrase" ]] && echo "        <p><strong>LUKS Encryption Passphrase:</strong><br><span class=\"password\">$luks_passphrase</span></p>"
            [[ -n "$wifi_password" ]] && echo "        <p><strong>WiFi Password:</strong><br><span class=\"password\">$wifi_password</span></p>"
            cat << EOF
    </div>

    <div class="usage">
        <h3>🚀 Deployment Usage</h3>
        <p>Export the passwords as environment variables:</p>
        <code>export DEPLOY_USER_PASSWORD="$user_password"</code><br>
        <code>export DEPLOY_ROOT_PASSWORD="$root_password"</code><br>
EOF
            [[ -n "$luks_passphrase" ]] && echo "        <code>export DEPLOY_LUKS_PASSPHRASE=\"$luks_passphrase\"</code><br>"
            [[ -n "$wifi_password" ]] && echo "        <code>export DEPLOY_WIFI_PASSWORD=\"$wifi_password\"</code><br>"
            cat << EOF
        <p>Then run: <code>./zero_touch_deploy.sh --password-mode env</code></p>
    </div>

    <div class="warning">
        <h3>🔒 Security Guidelines</h3>
        <ul>
            <li>Store passwords in a secure password manager</li>
            <li>Do not forward this email to others</li>
            <li>Delete this email after extracting passwords</li>
            <li>Use secure, encrypted communication channels</li>
        </ul>
    </div>
</body>
</html>
EOF
            ;;
            
        "json")
            cat << EOF
{
    "subject": "$EMAIL_SUBJECT",
    "generated": "$(date -Iseconds)",
    "passwords": {
        "user_password": "$user_password",
        "root_password": "$root_password",
        "luks_passphrase": "$luks_passphrase",
        "wifi_password": "$wifi_password"
    },
    "deployment_commands": [
        "export DEPLOY_USER_PASSWORD=\"$user_password\"",
        "export DEPLOY_ROOT_PASSWORD=\"$root_password\"",
        "export DEPLOY_LUKS_PASSPHRASE=\"$luks_passphrase\"",
        "export DEPLOY_WIFI_PASSWORD=\"$wifi_password\"",
        "./zero_touch_deploy.sh --password-mode env"
    ]
}
EOF
            ;;
    esac
}

# Encrypt email content with GPG
encrypt_email_content() {
    local email_content="$1"
    local recipient="$2"
    
    log_info "Encrypting email content with GPG..."
    
    # Check if recipient key exists
    if ! gpg --list-keys "$recipient" >/dev/null 2>&1; then
        log_error "GPG key not found for recipient: $recipient"
        log_info "Import the recipient's public key first"
        return 1
    fi
    
    # Encrypt the content
    local encrypted_content
    encrypted_content=$(echo "$email_content" | gpg --encrypt --armor --recipient "$recipient" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        cat << EOF
Subject: $EMAIL_SUBJECT (Encrypted)
Content-Type: text/plain; charset=UTF-8

This email contains GPG-encrypted password information.
Decrypt with: gpg --decrypt

$encrypted_content
EOF
        log_success "Email content encrypted successfully"
        return 0
    else
        log_error "Failed to encrypt email content"
        return 1
    fi
}

# Send email using Python SMTP
send_email_python() {
    local email_content="$1"
    
    python3 << EOF
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import sys

try:
    # Parse email content
    lines = """$email_content""".split('\n')
    subject = ""
    content_type = "text/plain"
    body_lines = []
    in_body = False
    
    for line in lines:
        if line.startswith("Subject: "):
            subject = line[9:]
        elif line.startswith("Content-Type: "):
            content_type = line[14:].split(';')[0]
        elif line.strip() == "" and not in_body:
            in_body = True
        elif in_body:
            body_lines.append(line)
    
    body = '\n'.join(body_lines)
    
    # Create message
    msg = MIMEMultipart()
    msg['From'] = "$SMTP_USERNAME"
    msg['To'] = "$EMAIL_RECIPIENT"
    msg['Subject'] = subject
    
    # Attach body
    if "html" in content_type:
        msg.attach(MIMEText(body, 'html'))
    else:
        msg.attach(MIMEText(body, 'plain'))
    
    # Create SMTP session
    if "$USE_TLS" == "true":
        context = ssl.create_default_context()
        server = smtplib.SMTP('$SMTP_SERVER', $SMTP_PORT)
        server.starttls(context=context)
    else:
        server = smtplib.SMTP('$SMTP_SERVER', $SMTP_PORT)
    
    # Login and send
    server.login("$SMTP_USERNAME", "$SMTP_PASSWORD")
    text = msg.as_string()
    server.sendmail("$SMTP_USERNAME", "$EMAIL_RECIPIENT", text)
    server.quit()
    
    print("Email sent successfully", file=sys.stderr)
    
except Exception as e:
    print(f"Failed to send email: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

# Send email using msmtp
send_email_msmtp() {
    local email_content="$1"
    
    # Create temporary msmtp config
    local msmtp_config="/tmp/msmtp_config_$$"
    cat > "$msmtp_config" << EOF
defaults
auth           on
tls            $USE_TLS
logfile        /tmp/msmtp.log

account        default
host           $SMTP_SERVER
port           $SMTP_PORT
from           $SMTP_USERNAME
user           $SMTP_USERNAME
password       $SMTP_PASSWORD
EOF
    
    # Send email
    if echo "$email_content" | msmtp -C "$msmtp_config" "$EMAIL_RECIPIENT"; then
        log_success "Email sent using msmtp"
        rm -f "$msmtp_config"
        return 0
    else
        log_error "Failed to send email using msmtp"
        rm -f "$msmtp_config"
        return 1
    fi
}

# Send email using system mail command
send_email_system() {
    local email_content="$1"
    
    # Extract subject from content
    local subject
    subject=$(echo "$email_content" | grep "^Subject: " | cut -d' ' -f2-)
    
    # Extract body (everything after first empty line)
    local body
    body=$(echo "$email_content" | sed -n '/^$/,$p' | tail -n +2)
    
    # Send using mail command
    if echo "$body" | mail -s "$subject" "$EMAIL_RECIPIENT"; then
        log_success "Email sent using system mail"
        return 0
    else
        log_error "Failed to send email using system mail"
        return 1
    fi
}

# Main email sending function
send_password_email() {
    local format="${1:-html}"
    local encrypt="${2:-$ENCRYPT_EMAIL}"
    
    log_info "Preparing email delivery..."
    
    # Load configuration
    if ! load_email_config; then
        return 1
    fi
    
    # Check dependencies
    if ! check_email_dependencies; then
        return 1
    fi
    
    # Prepare email content
    local email_content
    email_content=$(prepare_email_content "$format")
    
    # Encrypt if requested
    if [[ "$encrypt" == "true" ]]; then
        if [[ -z "$GPG_RECIPIENT" ]]; then
            log_error "GPG recipient not configured for encryption"
            return 1
        fi
        email_content=$(encrypt_email_content "$email_content" "$GPG_RECIPIENT")
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    
    # Try sending with available methods
    log_info "Sending email to: $EMAIL_RECIPIENT"
    
    # Try Python SMTP first (most reliable)
    if python3 -c "import smtplib, ssl" 2>/dev/null && [[ -n "$SMTP_SERVER" ]]; then
        if send_email_python "$email_content"; then
            return 0
        fi
    fi
    
    # Try msmtp
    if command -v msmtp >/dev/null 2>&1 && [[ -n "$SMTP_SERVER" ]]; then
        if send_email_msmtp "$email_content"; then
            return 0
        fi
    fi
    
    # Try system mail command
    if command -v mail >/dev/null 2>&1; then
        if send_email_system "$email_content"; then
            return 0
        fi
    fi
    
    log_error "All email sending methods failed"
    return 1
}

# Configure email interactively
configure_email_interactive() {
    echo -e "${BLUE}📧 Email Configuration Setup${NC}"
    echo
    
    read -p "Email recipient: " EMAIL_RECIPIENT
    read -p "SMTP server (e.g., smtp.gmail.com): " SMTP_SERVER
    read -p "SMTP port [587]: " smtp_port
    SMTP_PORT="${smtp_port:-587}"
    read -p "SMTP username: " SMTP_USERNAME
    echo -n "SMTP password: "
    read -s SMTP_PASSWORD
    echo
    
    read -p "Use TLS encryption? [Y/n]: " use_tls
    if [[ "$use_tls" =~ ^[Nn]$ ]]; then
        USE_TLS="false"
    else
        USE_TLS="true"
    fi
    
    read -p "Encrypt email with GPG? [y/N]: " encrypt_email
    if [[ "$encrypt_email" =~ ^[Yy]$ ]]; then
        ENCRYPT_EMAIL="true"
        read -p "GPG recipient (email or key ID): " GPG_RECIPIENT
    fi
    
    log_success "Email configuration completed"
}

# Show help information
show_help() {
    cat << 'EOF'
Email Password Delivery

Sends generated passwords via secure email with optional GPG encryption.

Functions:
  send_password_email          - Send passwords via email
  configure_email_interactive  - Set up email configuration interactively
  prepare_email_content        - Generate email content in various formats

Configuration (Environment Variables):
  DEPLOY_EMAIL_RECIPIENT    - Email recipient address
  DEPLOY_SMTP_SERVER        - SMTP server hostname
  DEPLOY_SMTP_PORT          - SMTP server port (default: 587)
  DEPLOY_SMTP_USERNAME      - SMTP authentication username
  DEPLOY_SMTP_PASSWORD      - SMTP authentication password
  DEPLOY_USE_TLS            - Use TLS encryption (true/false)
  DEPLOY_GPG_RECIPIENT      - GPG key for email encryption

Supported Email Formats:
  plain    - Plain text email
  html     - HTML formatted email (default)
  json     - JSON structured data

Dependencies:
  - Python 3 with smtplib (preferred) OR msmtp OR mail command
  - GPG (for email encryption)

Usage Examples:

1. Send HTML email:
   source email_delivery.sh
   send_password_email "html"

2. Send encrypted email:
   ENCRYPT_EMAIL="true" GPG_RECIPIENT="user@example.com"
   send_password_email "html" "true"

3. Configure interactively:
   configure_email_interactive

Security Features:
- TLS/SSL encryption for SMTP
- Optional GPG encryption for email content
- Secure password prompting
- HTML and plain text formats
- Temporary credential handling

Email Providers:
Common SMTP settings:
- Gmail: smtp.gmail.com:587 (app passwords required)
- Outlook: smtp-mail.outlook.com:587
- Yahoo: smtp.mail.yahoo.com:587

EOF
}

# Main execution
main() {
    local action="${1:-send}"
    
    case "$action" in
        "send")
            local format="${2:-html}"
            local encrypt="${3:-false}"
            send_password_email "$format" "$encrypt"
            ;;
        "configure")
            configure_email_interactive
            ;;
        "test")
            # Test email configuration
            EMAIL_RECIPIENT="${2:-}"
            if [[ -z "$EMAIL_RECIPIENT" ]]; then
                log_error "Email recipient required for test"
                exit 1
            fi
            
            # Send test email
            local test_content="Subject: Email Configuration Test

This is a test email from the Arch Linux deployment password delivery system.

If you receive this email, your email configuration is working correctly.

Sent: $(date -Iseconds)
"
            if python3 -c "import smtplib, ssl" 2>/dev/null; then
                send_email_python "$test_content"
            else
                log_error "Python SMTP not available for testing"
                exit 1
            fi
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {send|configure|test|help} [options]"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi