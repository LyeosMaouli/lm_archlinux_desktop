#!/bin/bash
# Example USB Deployment Configuration
# Copy this file as usb-deploy.sh and customize the settings below

# =====================================
# EXAMPLE CONFIGURATION
# =====================================

# Replace with your actual GitHub details
GITHUB_USERNAME="john-doe"                    # Your GitHub username
GITHUB_REPO="my-arch-desktop"                 # Your repository name  
GITHUB_BRANCH="main"                          # Branch to use

# Choose your password method
PASSWORD_MODE="file"                          # "file", "env", "generate", or "interactive"

# Password file settings (for file mode)
PASSWORD_FILE_NAME="passwords.enc"            # Name of encrypted file
USE_GITHUB_RELEASE=false                      # Use file from USB stick
# USE_GITHUB_RELEASE=true                     # Download from GitHub release
# GITHUB_RELEASE_TAG="latest"                 # Release tag to download

# System configuration (optional - leave empty for auto-detection/prompts)
TARGET_HOSTNAME="johns-laptop"               # Computer name
TARGET_USERNAME="john"                       # Main user account
TARGET_TIMEZONE="America/New_York"           # System timezone
TARGET_KEYMAP="us"                           # Keyboard layout
ENABLE_ENCRYPTION="true"                     # Enable disk encryption

# Network configuration (optional)
WIFI_SSID="HomeWiFi"                         # WiFi network name
WIFI_PASSWORD=""                             # WiFi password (empty = prompt)

# =====================================
# MORE EXAMPLES
# =====================================

# Example 1: Minimal configuration with prompts
# GITHUB_USERNAME="jane-smith"
# GITHUB_REPO="arch-setup"
# PASSWORD_MODE="interactive"
# # Everything else will be prompted during deployment

# Example 2: Development setup with auto-generated passwords
# GITHUB_USERNAME="developer"
# GITHUB_REPO="dev-arch"
# PASSWORD_MODE="generate"
# TARGET_HOSTNAME="dev-machine"
# ENABLE_ENCRYPTION="false"

# Example 3: Office deployment with GitHub release
# GITHUB_USERNAME="company"
# GITHUB_REPO="office-arch-setup"
# PASSWORD_MODE="file"
# USE_GITHUB_RELEASE=true
# GITHUB_RELEASE_TAG="v2.1"
# TARGET_TIMEZONE="Europe/London"
# TARGET_KEYMAP="uk"

# Example 4: Home server setup
# GITHUB_USERNAME="homelab"
# GITHUB_REPO="server-arch"
# PASSWORD_MODE="env"
# TARGET_HOSTNAME="homeserver"
# TARGET_USERNAME="admin"
# ENABLE_ENCRYPTION="true"

# =====================================
# INSTRUCTIONS
# =====================================

# 1. Copy this file as usb-deploy.sh:
#    cp example-config.sh usb-deploy.sh
#
# 2. Edit the configuration above with your actual details
#
# 3. Copy to USB stick along with passwords.enc (if using file mode)
#
# 4. Boot target computer from Arch Linux ISO
#
# 5. Mount USB and run:
#    mount /dev/sdX1 /mnt/usb
#    cd /mnt/usb
#    ./usb-deploy.sh

echo "This is an example configuration file."
echo "Copy this as usb-deploy.sh and edit the configuration section."
echo ""
echo "Usage:"
echo "  cp example-config.sh usb-deploy.sh"
echo "  nano usb-deploy.sh  # Edit configuration"
echo "  # Copy to USB stick and run on target computer"