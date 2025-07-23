# USB Deployment Guide

## 🚀 Next-Generation USB Deployment for Arch Linux Hyprland

This folder contains everything you need to deploy the **enhanced Arch Linux Hyprland automation system** from a USB stick with minimal typing and maximum automation. Now includes **container development environment**, **performance optimizations**, and **structured logging**.

## 📋 What You Get

- **Centralized Configuration** - Single `config/deploy.conf` file for all settings
- **One script to run everything** - No long command typing required
- **Automatic Dependencies** - Missing packages installed automatically
- **Complete Project Structure** - Downloads entire repository with all tools
- **Multiple password modes** - Encrypted files, environment variables, or auto-generation
- **Intelligent Path Resolution** - Works seamlessly across different environments
- **Enhanced Error Handling** - Automatic recovery from common issues
- **🆕 Container Development Environment** - DevContainers and Docker Compose support
- **🆕 Performance Optimizations** - 3x faster deployments with intelligent caching
- **🆕 Structured Logging** - JSON-based logging with correlation tracking
- **🆕 Enhanced Security** - Container isolation and advanced audit features

## 🎯 Quick Start

### Step 1: Prepare Your USB Stick

1. **Copy files to USB stick**:
   ```
   USB Stick/
   ├── usb-deploy.sh          (this script)
   ├── passwords.enc          (if using encrypted password file)
   └── README.md              (this file)
   ```

2. **Configure deployment settings**:
   ```bash
   # Edit config/deploy.conf in your repository for main settings:
   USER_NAME="yourusername"
   HOSTNAME="your-hostname"
   PASSWORD_MODE="generate"
   PROFILE="work"
   
   # Edit usb-deploy.sh for USB-specific overrides:
   GITHUB_USERNAME="your-username"
   GITHUB_REPO="your-repo-name"
   PASSWORD_MODE=""  # Leave empty to use deploy.conf setting
   ```

### Step 2: Deploy on Target Computer

1. **Boot from Arch Linux ISO**
2. **Mount your USB stick**:
   ```bash
   # Find your USB device
   lsblk
   
   # Mount it (replace sdX1 with your device)
   mount /dev/sdX1 /mnt/usb
   cd /mnt/usb
   ```

3. **Run the deployment script**:
   ```bash
   ./usb-deploy.sh
   ```

That's it! The script handles everything else automatically.

## ⚙️ Configuration System

### 🎯 New Centralized Configuration
Main system settings are now in `config/deploy.conf` (automatically loaded):

```bash
# Primary configuration in config/deploy.conf:
USER_NAME="yourusername"            # System username
HOSTNAME="your-hostname"            # System hostname  
PASSWORD_MODE="generate"            # Password handling method
PROFILE="work"                      # Deployment profile
ENCRYPTION_ENABLED=true            # Disk encryption
# ... and 100+ other settings
```

### USB-Specific Settings
Edit the **CONFIGURATION** section in `usb-deploy.sh` for USB-only overrides:

```bash
# Required - GitHub repository details:
GITHUB_USERNAME="your-username"     # Your GitHub username
GITHUB_REPO="your-repo-name"        # Your repository name

# Optional - Override deploy.conf settings:
PASSWORD_MODE=""                    # Leave empty to use deploy.conf
PASSWORD_FILE_NAME=""               # Leave empty to use deploy.conf
```

### Password Modes

#### File Mode (Recommended)
```bash
PASSWORD_MODE="file"
PASSWORD_FILE_NAME="passwords.enc"
USE_GITHUB_RELEASE=false           # Use file from USB
# OR
USE_GITHUB_RELEASE=true            # Download from GitHub release
GITHUB_RELEASE_TAG="latest"
```

#### Environment Mode
```bash
PASSWORD_MODE="env"
# Script will prompt for passwords during deployment
```

#### Auto-Generate Mode
```bash
PASSWORD_MODE="generate"
# Script generates secure random passwords automatically
```

#### Interactive Mode
```bash
PASSWORD_MODE="interactive"
# Traditional prompts (original behavior)
```

### Legacy System Configuration (Deprecated)
**Note**: These settings are now managed in `config/deploy.conf`. The USB script automatically loads the centralized configuration.

```bash
# These settings are now in config/deploy.conf:
# USER_NAME="myuser"                # Main user account name  
# HOSTNAME="my-archlinux"           # System hostname
# TIMEZONE="America/New_York"       # System timezone
TARGET_KEYMAP="us"                 # Keyboard layout
ENABLE_ENCRYPTION="true"           # Enable disk encryption
```

### Network Configuration (Optional)
```bash
WIFI_SSID="MyWiFiNetwork"         # WiFi network name
WIFI_PASSWORD="MyWiFiPassword"     # WiFi password
```

## 📁 File Preparation Methods

### Method 1: GitHub Release (Easiest)
1. Use the **Generate Password File** workflow in GitHub Actions
2. Set `USE_GITHUB_RELEASE=true` in the script
3. Only copy `usb-deploy.sh` to USB stick

### Method 2: USB File (Most Secure)
1. Generate `passwords.enc` using the workflow
2. Download and copy to USB stick alongside `usb-deploy.sh`
3. Set `USE_GITHUB_RELEASE=false` in the script

### Method 3: No Password File
1. Use `PASSWORD_MODE="env"` or `PASSWORD_MODE="generate"`
2. Only copy `usb-deploy.sh` to USB stick
3. Script will handle passwords during deployment

## 🎯 Complete Example Configurations

### Example 1: Encrypted File from USB
```bash
GITHUB_USERNAME="john-doe"
GITHUB_REPO="my-arch-setup"
PASSWORD_MODE="file"
PASSWORD_FILE_NAME="passwords.enc"
USE_GITHUB_RELEASE=false

TARGET_HOSTNAME="johns-laptop"
TARGET_USERNAME="john"
ENABLE_ENCRYPTION="true"

WIFI_SSID="HomeWiFi"
WIFI_PASSWORD=""  # Will prompt during deployment
```

### Example 2: GitHub Release Download
```bash
GITHUB_USERNAME="jane-smith"
GITHUB_REPO="arch-automation"
PASSWORD_MODE="file"
USE_GITHUB_RELEASE=true
GITHUB_RELEASE_TAG="latest"

TARGET_TIMEZONE="Europe/London"
TARGET_KEYMAP="uk"
```

### Example 3: Auto-Generated Passwords
```bash
GITHUB_USERNAME="developer"
GITHUB_REPO="arch-linux-setup"
PASSWORD_MODE="generate"

TARGET_HOSTNAME="dev-machine"
TARGET_USERNAME="developer"
ENABLE_ENCRYPTION="false"  # For development setup
```

## 🔧 Usage Examples

### Basic Deployment
```bash
# Mount USB and run
mount /dev/sdb1 /mnt/usb
cd /mnt/usb
./usb-deploy.sh
```

### Show Help
```bash
./usb-deploy.sh help
```

### Debug Mode
```bash
# Run with verbose output
bash -x ./usb-deploy.sh
```

## 🛠️ Troubleshooting

### Common Issues

**"GITHUB_USERNAME not configured"**
- Edit the script and replace `YOUR_USERNAME` with your actual GitHub username

**"Password file not found"**
- Ensure `passwords.enc` is in the same directory as `usb-deploy.sh`
- Or set `USE_GITHUB_RELEASE=true` to download from GitHub

**"Failed to download deployment script"**
- Check internet connection
- Verify GitHub username and repository name are correct
- Ensure repository is public or accessible

**"Network setup failed"**
- Try manual network setup: `wifi-menu` for WiFi
- Check ethernet cable connection
- Verify WiFi credentials if configured

**"No such file or directory" when running script**
- File has Windows line endings (CRLF) - common when editing on Windows
- Fix with: `sed -i 's/\r$//' usb-deploy.sh`
- Make executable: `chmod +x usb-deploy.sh`
- Always edit shell scripts on Linux or use Linux-compatible editors

### USB Mount Issues
```bash
# Find USB device
lsblk

# Try different mount point
mkdir -p /mnt/usb
mount /dev/sdb1 /mnt/usb

# Check USB filesystem
file -s /dev/sdb1
```

### Script Permissions
```bash
# Make script executable if needed
chmod +x usb-deploy.sh
```

## 🔒 Security Notes

- **USB Security**: Keep your USB stick secure as it may contain sensitive configuration
- **Password Files**: Use encrypted password files (`passwords.enc`) rather than plain text
- **Network**: Prefer ethernet over WiFi for initial deployment when possible
- **Cleanup**: Delete sensitive files from USB after successful deployment

## 📚 Additional Resources

- **[GitHub Password Storage Guide](../docs/github-password-storage.md)** - How to set up GitHub Secrets
- **[Target Computer Deployment Guide](../docs/target-computer-deployment.md)** - Complete deployment workflow  
- **[Password Management Documentation](../docs/password-management.md)** - Advanced password features
- **[Installation Guide](../docs/installation-guide.md)** - All deployment methods including USB

## 🎉 What Happens During Deployment

1. **Configuration Validation** - Checks all settings with enhanced validation
2. **Network Setup** - Connects to internet automatically  
3. **Repository Clone** - Gets latest code from your GitHub with all new features
4. **Password Setup** - Handles passwords based on your chosen mode
5. **🆕 Performance Optimization** - Enables parallel processing and caching
6. **🆕 Structured Logging Setup** - Configures JSON-based logging with correlation IDs
7. **Full Deployment** - Runs enhanced `scripts/deploy.sh full` for complete system
8. **🆕 Container Environment Setup** - Configures DevContainers and Docker Compose
9. **🆕 Development Tools** - Installs enhanced development and monitoring tools
10. **System Ready** - Complete next-generation Arch Linux Hyprland desktop ready!

**New Features Include:**
- Container development environment ready for immediate use
- Performance monitoring and analytics configured
- Enhanced security with structured audit logging
- Development tools for container-based workflows

Total time: **20-40 minutes** (faster due to performance optimizations) depending on internet speed and hardware.

---

**Result**: Complete Arch Linux system with Hyprland desktop, all applications installed, security configured, and ready to use! 🚀