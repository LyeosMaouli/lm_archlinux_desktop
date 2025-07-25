# Password Management System

## Overview

The Arch Linux Hyprland Desktop Automation system features a revolutionary hybrid password management system that enables fully automated deployments while maintaining enterprise-grade security. The system now uses **centralized configuration** through `config/deploy.conf` and supports multiple password input methods with intelligent fallback mechanisms and **automatic dependency installation**.

## 🔧 Centralized Configuration

All password settings can be configured in the main `config/deploy.conf` file:

```bash
# Password configuration in config/deploy.conf
PASSWORD_MODE="generate"                    # Default password method
PASSWORD_FILE="../passwords.enc"           # Path to encrypted password file

# The system automatically uses these settings for all deployment methods
```

**Benefits**:
- Single source of truth for all password settings
- Consistent behavior across USB, local, and CI/CD deployments  
- Easy to manage and version control
- Supports all deployment environments

## 🔐 Password Input Methods

The system supports four password input methods in priority order:

### 1. Environment Variables (Primary)
**Use Case**: CI/CD pipelines, enterprise automation, container deployments

Set passwords as environment variables before running deployment:

```bash
# Set passwords
export DEPLOY_USER_PASSWORD="secure_user_password"
export DEPLOY_ROOT_PASSWORD="secure_root_password"
export DEPLOY_LUKS_PASSPHRASE="secure_luks_passphrase"
export DEPLOY_WIFI_SSID="MyWiFiNetwork"
export DEPLOY_WIFI_PASSWORD="wifi_password"

# Deploy with environment method (dependencies auto-installed)
./scripts/deploy.sh full --password env
```

**Security Features**:
- Passwords only exist in process environment
- Automatically cleared after use
- No disk storage of plain text passwords
- Process isolation prevents exposure

### 2. Encrypted Password Files (Secondary)
**Use Case**: Offline deployments, secure password storage, repeatable deployments

Create and use encrypted password files:

```bash
# Create encrypted password file
./scripts/utils/passwords.sh create-file --output passwords.enc

# Deploy using encrypted file
./scripts/deploy.sh full --password file --password-file passwords.enc
```

**Security Features**:
- AES-256 encryption with PBKDF2 key derivation
- 100,000+ iterations for key strengthening
- Secure file permissions (600)
- Base64 encoding for safe storage

### 3. Auto-Generated Passwords (Tertiary)
**Use Case**: True zero-touch deployments, development environments

Generate cryptographically secure passwords automatically:

```bash
# Deploy with auto-generated passwords
./scripts/deploy.sh full --password generate
```

**Security Features**:
- Cryptographically secure random generation using /dev/urandom
- Configurable password complexity
- Multiple secure delivery methods
- Strength validation and complexity enforcement

### 4. Interactive Prompts (Fallback)
**Use Case**: Manual deployments, troubleshooting

Traditional secure password prompting:

```bash
# Interactive mode (default fallback)
./scripts/deploy.sh full --password interactive
```

## 🚀 Quick Start Examples

### GitHub CI/CD Pipeline
```yaml
# GitHub Actions / GitLab CI
- name: Deploy Arch Linux System
  env:
    DEPLOY_USER_PASSWORD: ${{ secrets.USER_PASSWORD }}
    DEPLOY_ROOT_PASSWORD: ${{ secrets.ROOT_PASSWORD }}
    DEPLOY_LUKS_PASSPHRASE: ${{ secrets.LUKS_PASSPHRASE }}
  run: |
    curl -fsSL https://raw.githubusercontent.com/LyeosMaouli/lm_archlinux_desktop/main/scripts/deployment/zero_touch_deploy.sh | bash -s -- --password-mode env
```

### Secure Offline Deployment
```bash
# Create encrypted password file
./scripts/utils/passwords.sh create-file \
  --user-password "secure_user_pass" \
  --root-password "secure_root_pass" \
  --luks-passphrase "secure_luks_pass" \
  --output deployment-passwords.enc

# Deploy using encrypted file
./zero_touch_deploy.sh \
  --password-mode file \
  --password-file deployment-passwords.enc
```

### Development/Testing Environment
```bash
# Auto-generate passwords with file output
./zero_touch_deploy.sh \
  --password-mode generate
```

## 📋 Detailed Usage Guide

### Creating Password Files

#### Interactive Creation
```bash
# Run password file creator
./scripts/utils/passwords.sh create-file

# Follow prompts to enter passwords securely
# File will be encrypted with your chosen passphrase
```

#### Command Line Creation
```bash
# Non-interactive creation
./scripts/utils/passwords.sh create-file \
  --user-password "your_user_password" \
  --root-password "your_root_password" \
  --luks-passphrase "your_luks_passphrase" \
  --wifi-password "your_wifi_password" \
  --output my_passwords.enc
```

#### Verify Password File
```bash
# Verify file integrity and structure
./scripts/utils/passwords.sh create-file --verify passwords.enc
```

### Environment Variable Setup

#### Basic Setup
```bash
# Set required passwords
export DEPLOY_USER_PASSWORD="secure_password"
export DEPLOY_ROOT_PASSWORD="secure_password"

# Optional passwords
export DEPLOY_LUKS_PASSPHRASE="encryption_passphrase"
export DEPLOY_WIFI_PASSWORD="wifi_password"
```

#### Template Generation
```bash
# Generate environment template
./scripts/utils/passwords.sh template my_env.sh

# Edit template with actual passwords
nano my_env.sh

# Source and deploy
source my_env.sh
./scripts/deploy.sh full --password env
```

### Auto-Generated Passwords

#### Generation and Display
```bash
# Generate passwords and display on screen
./scripts/deploy.sh full --password generate
```

#### Save Generated Passwords
```bash
# Generate and save to various formats
./scripts/utils/passwords.sh generate generate file
./scripts/utils/passwords.sh generate generate encrypted-file
```

#### Password Delivery Methods
```bash
# Display as QR code
./scripts/utils/passwords.sh display

# Send via email
./scripts/utils/passwords.sh send html

# Save to multiple file formats
./scripts/utils/passwords.sh multi deployment_passwords
```

## 🔧 Advanced Configuration

### Password Strength Requirements

- **User/Root Passwords**: Minimum 8 characters, 3+ character types
- **LUKS Passphrase**: Minimum 12 characters (uses memorable word format)
- **WiFi Password**: Minimum 1 character (flexible for various networks)

### Encryption Specifications

- **File Encryption**: AES-256-CBC with PBKDF2 key derivation
- **Key Derivation**: 100,000 iterations with random salt
- **Password Hashing**: SHA-512 with secure salt generation

### Delivery Method Configuration

#### Email Delivery Setup
```bash
# Configure email delivery
export DEPLOY_EMAIL_RECIPIENT="user@example.com"
export DEPLOY_SMTP_SERVER="smtp.gmail.com"
export DEPLOY_SMTP_PORT="587"
export DEPLOY_SMTP_USERNAME="sender@gmail.com"
export DEPLOY_SMTP_PASSWORD="app_password"

# Send password email
./scripts/utils/passwords.sh send html
```

#### QR Code Generation
```bash
# Display QR code in terminal
./scripts/utils/passwords.sh display

# Save QR code as image
./scripts/utils/passwords.sh save passwords.png png

# Generate encrypted QR code
./scripts/utils/passwords.sh encrypted passwords_secure.png
```

## 🛡️ Security Best Practices

### Password Management
1. **Use environment variables for CI/CD** - Most secure for automation
2. **Use encrypted files for offline deployment** - Secure storage solution
3. **Auto-generate for development** - Convenient and secure
4. **Avoid plain text storage** - Never store passwords unencrypted

### Deployment Security
1. **Verify password strength** - System enforces minimum requirements
2. **Clear sensitive data** - Automatic cleanup after use
3. **Use secure channels** - TLS for network communication
4. **Audit password access** - Log password-related events

### Storage Security
1. **Encrypted file permissions** - Set to 600 (owner only)
2. **Secure deletion** - Use shred when available
3. **Backup encryption** - Always encrypt password backups
4. **Access control** - Limit access to password files

## 📚 API Reference

### Core Functions

#### `password_manager.sh`
```bash
# Main password collection function
collect_passwords [mode]

# Get password by type
get_password <type>

# Set password by type  
set_password <type> <password>

# Export passwords to environment
export_passwords

# Show password status
show_password_status
```

### Unified Password System (`scripts/utils/passwords.sh`)

All password management is now consolidated into a single, powerful utility:

```bash
# Create encrypted password file
./scripts/utils/passwords.sh create-file passwords.enc [passphrase] [user_pass] [root_pass] [luks_pass]

# Generate secure passwords
./scripts/utils/passwords.sh generate [--save] [--display]

# Create environment template
./scripts/utils/passwords.sh template-env [output_file]

# Collect passwords for deployment (used internally by deploy.sh)
source scripts/utils/passwords.sh
collect_passwords [mode]
get_password [type]
```

#### Legacy Individual Scripts (Deprecated)
```bash
# Generate all required passwords
generate_secure_passwords

# Generate single secure password
generate_secure_password <length> <use_special> <exclude_ambiguous>

# Generate memorable password
generate_memorable_password <word_count> <add_numbers>
```

### Delivery Functions

#### `qr_delivery.sh`
```bash
# Display password QR code
display_qr_with_instructions

# Save QR code to file
save_qr_to_file <output> <format> <encrypt>

# Generate WiFi QR code
generate_wifi_qr <ssid> <password> <security>
```

#### `email_delivery.sh`
```bash
# Send password email
send_password_email <format> <encrypt>

# Configure email interactively
configure_email_interactive
```

#### `file_delivery.sh`
```bash
# Save password file
save_password_file <output> <format> <encrypt> <compress>

# Generate multiple formats
generate_multiple_formats <base_name> <encrypt> <compress>

# Create backup archive
create_backup_archive <archive_name> <encrypt>
```

## 🔍 Troubleshooting

### Common Issues

#### Environment Variables Not Found
```bash
# Check environment variables
./scripts/utils/passwords.sh status

# Validate CI/CD environment
./scripts/utils/passwords.sh validate-ci
```

#### Encrypted File Issues
```bash
# Verify file integrity
./scripts/utils/passwords.sh create-file --verify passwords.enc

# Check file information
./scripts/security/encrypted_file_handler.sh info passwords.enc
```

#### Password Generation Problems
```bash
# Test password generation
./scripts/utils/passwords.sh generate single 16

# Check random sources
./scripts/utils/passwords.sh generate generate
```

### Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Password management system not found" | Missing password manager | Check file paths and permissions |
| "No suitable random source found" | Missing /dev/urandom or OpenSSL | Install OpenSSL or check system |
| "Failed to decrypt password file" | Wrong passphrase or corrupted file | Verify passphrase and file integrity |
| "Missing required secrets in CI/CD" | Environment variables not set | Configure secrets in CI/CD system |

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Enable debug mode
export VERBOSE=true

# Run with debugging
./scripts/deploy.sh full --password auto
```

## 🎯 Use Case Examples

### Scenario 1: Enterprise Deployment
**Requirements**: Automated deployment with corporate security standards

**Solution**: Environment variables with CI/CD integration
```bash
# Set in CI/CD secrets
DEPLOY_USER_PASSWORD: "Corporate#Pass123"
DEPLOY_ROOT_PASSWORD: "Admin#Secure456"
DEPLOY_LUKS_PASSPHRASE: "Corporate-Disk-Encryption-2024"

# Deploy
./scripts/deploy.sh full --password env
```

### Scenario 2: Offline Secure Deployment
**Requirements**: No internet, maximum security

**Solution**: Encrypted password file
```bash
# Create offline
./scripts/utils/passwords.sh create-file --output secure.enc

# Deploy offline
./zero_touch_deploy.sh --password-mode file --password-file secure.enc
```

### Scenario 3: Development Environment
**Requirements**: Quick setup, temporary passwords

**Solution**: Auto-generated passwords
```bash
# Generate and display
./scripts/deploy.sh full --password generate

# Save for later use
./scripts/utils/passwords.sh save dev_passwords.yaml yaml
```

### Scenario 4: Remote Team Deployment
**Requirements**: Secure password sharing

**Solution**: Multiple delivery methods
```bash
# Generate passwords
./scripts/utils/passwords.sh generate generate

# Send via email (encrypted)
./scripts/utils/passwords.sh send html true

# Create QR code backup
./scripts/utils/passwords.sh encrypted team_passwords.png
```

## 🚀 Future Enhancements

### Planned Features
- **Hardware Security Module (HSM) integration**
- **OAuth/OIDC provider integration**
- **Biometric authentication support**
- **Multi-factor authentication**
- **Password rotation automation**
- **Integration with enterprise password managers** (1Password, Bitwarden, etc.)

### Contributing
To contribute to the password management system:

1. Fork the repository
2. Create feature branch
3. Test with all password methods
4. Update documentation
5. Submit pull request

## 📄 License

This password management system is part of the Arch Linux Hyprland Desktop Automation project and is licensed under the MIT License.

---

**Security Notice**: This documentation contains examples with placeholder passwords. Always use strong, unique passwords in production environments.