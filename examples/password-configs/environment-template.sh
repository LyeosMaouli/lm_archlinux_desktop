#!/bin/bash
# Environment Variables Template for Arch Linux Deployment
# Copy this file, customize it, and source before deployment

# SECURITY WARNING: This file contains sensitive password information!
# - Store securely (chmod 600)
# - Do not commit to version control
# - Delete after deployment

# ========================================
# REQUIRED PASSWORDS
# ========================================

# User account password (minimum 8 characters)
# This will be the password for your main user account
export DEPLOY_USER_PASSWORD="CHANGE_ME_secure_user_password_123"

# Root account password (minimum 8 characters)
# This will be the password for the root/administrator account
export DEPLOY_ROOT_PASSWORD="CHANGE_ME_secure_root_password_456"

# ========================================
# OPTIONAL PASSWORDS
# ========================================

# LUKS disk encryption passphrase (minimum 12 characters)
# Only needed if you enable full disk encryption
# You'll need to enter this passphrase every time you boot
export DEPLOY_LUKS_PASSPHRASE="CHANGE_ME_very_secure_luks_passphrase_789"

# WiFi network password
# Only needed if you want to configure WiFi during deployment
export DEPLOY_WIFI_PASSWORD="CHANGE_ME_wifi_password"

# WiFi network name (SSID)
# The name of your WiFi network
export DEPLOY_WIFI_SSID="Your_WiFi_Network_Name"

# ========================================
# EMAIL DELIVERY CONFIGURATION (OPTIONAL)
# ========================================

# Email recipient for deployment notifications
export DEPLOY_EMAIL_RECIPIENT="user@example.com"

# SMTP server configuration
export DEPLOY_SMTP_SERVER="smtp.gmail.com"
export DEPLOY_SMTP_PORT="587"
export DEPLOY_SMTP_USERNAME="sender@gmail.com"
export DEPLOY_SMTP_PASSWORD="app_password_or_smtp_password"
export DEPLOY_USE_TLS="true"

# GPG encryption for email (optional)
export DEPLOY_GPG_RECIPIENT="user@example.com"

# ========================================
# DEPLOYMENT CONFIGURATION
# ========================================

# System hostname
export DEPLOY_HOSTNAME="archlinux-desktop"

# Username for the main user account
export DEPLOY_USERNAME="myuser"

# Timezone (e.g., "America/New_York", "Europe/London", "Asia/Tokyo")
export DEPLOY_TIMEZONE="UTC"

# Keyboard layout (e.g., "us", "uk", "fr", "de")
export DEPLOY_KEYMAP="us"

# Disk device for installation (e.g., "/dev/sda", "/dev/nvme0n1")
# Leave empty for auto-detection
export DEPLOY_DISK=""

# Enable full disk encryption (true/false)
export DEPLOY_ENABLE_ENCRYPTION="true"

# ========================================
# USAGE INSTRUCTIONS
# ========================================

# 1. Copy this file to a secure location
# cp environment-template.sh my-deployment.sh

# 2. Edit with your actual passwords
# nano my-deployment.sh

# 3. Set secure permissions
# chmod 600 my-deployment.sh

# 4. Source the environment variables
# source my-deployment.sh

# 5. Verify environment is set
# env | grep DEPLOY_

# 6. Run deployment
# ./scripts/deploy.sh full --password env

# 7. Clean up after deployment
# unset $(env | grep DEPLOY_ | cut -d= -f1)
# rm -f my-deployment.sh

# ========================================
# PASSWORD STRENGTH GUIDELINES
# ========================================

# Strong passwords should have:
# - At least 8 characters (12+ recommended)
# - Mix of uppercase and lowercase letters
# - Numbers
# - Special characters (!@#$%^&*)
# - No dictionary words
# - Unique for each account

# Examples of GOOD passwords:
# - "MyStr0ng!P@ssw0rd2024"
# - "Tr0ub4dor&3"
# - "c0rrect-h0rse-battery-staple!"

# Examples of BAD passwords:
# - "password123"
# - "admin"
# - "123456"
# - "qwerty"

# ========================================
# CI/CD USAGE
# ========================================

# For CI/CD pipelines, set these as environment variables or secrets:
# - GitHub Actions: Repository Settings > Secrets and variables > Actions
# - GitLab CI: Project Settings > CI/CD > Variables
# - Jenkins: Manage Jenkins > Credentials
# - Azure DevOps: Project Settings > Service connections

# ========================================
# SECURITY BEST PRACTICES
# ========================================

# 1. Use unique passwords for each system
# 2. Enable disk encryption (LUKS) for laptops
# 3. Use a password manager for password generation
# 4. Rotate passwords regularly
# 5. Enable two-factor authentication where possible
# 6. Monitor login attempts and system logs
# 7. Keep backups of important passphrases (securely)

echo "Environment variables loaded for Arch Linux deployment"
echo "Review all passwords before proceeding with deployment"
echo ""
echo "To deploy: ./scripts/deploy.sh full --password env"
echo "To clear: unset \$(env | grep DEPLOY_ | cut -d= -f1)"