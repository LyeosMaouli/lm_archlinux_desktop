# Target Computer Deployment Guide

## 🖥️ How to Deploy Arch Linux on Your Target Computer Using GitHub Passwords

This guide explains how to use passwords stored in GitHub to deploy Arch Linux on any target computer.

## 🎯 Understanding the Workflow

GitHub Secrets are **only available within GitHub Actions**, not for direct public access. Here's how to properly use them for target computer deployment:

## 🚀 Method 1: Generate Encrypted Password File (Recommended)

### Step 1: Create Password File Generator Workflow

Add this workflow to your repository: `.github/workflows/generate-passwords.yml`

```yaml
name: Generate Password File

on:
  workflow_dispatch:
    inputs:
      encryption_passphrase:
        description: 'Passphrase to encrypt the password file'
        required: true
        type: string

jobs:
  generate-password-file:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      
    - name: Create password file
      run: |
        # Create temporary password file
        cat > passwords.yaml << EOF
        user_password: "${{ secrets.DEPLOY_USER_PASSWORD }}"
        root_password: "${{ secrets.DEPLOY_ROOT_PASSWORD }}"
        luks_passphrase: "${{ secrets.DEPLOY_LUKS_PASSPHRASE }}"
        wifi_password: "${{ secrets.DEPLOY_WIFI_PASSWORD }}"
        EOF
        
        # Encrypt the password file
        openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
          -in passwords.yaml -out passwords.enc \
          -k "${{ github.event.inputs.encryption_passphrase }}"
        
        # Clean up plain text
        rm passwords.yaml
        
    - name: Upload encrypted password file
      uses: actions/upload-artifact@v4
      with:
        name: encrypted-passwords
        path: passwords.enc
        retention-days: 1
```

### Step 2: Generate Your Password File

1. Go to **Actions** tab in your GitHub repository
2. Click **"Generate Password File"** workflow
3. Click **"Run workflow"**
4. Enter a **strong encryption passphrase** (remember this!)
5. Download the generated `passwords.enc` file

### Step 3: Deploy on Target Computer

1. **Boot target computer** from Arch Linux ISO
2. **Transfer the encrypted file** to the target computer:

```bash
# Method A: Download from your repository releases
curl -L -o passwords.enc "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/TAG/passwords.enc"

# Method B: Use a USB stick to transfer the file
# Copy passwords.enc to USB, then mount it on target computer

# Method C: Upload to temporary file sharing (less secure)
# Upload to pastebin, transfer.sh, etc. and download
```

3. **Run deployment** with encrypted file:

```bash
# Download and run deployment script
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git && cd YOUR_REPO
chmod +x deploy.sh

# Deploy using encrypted password file
./deploy.sh --password-mode file --password-file passwords.enc
# You'll be prompted for the encryption passphrase you used
```

## 🚀 Method 2: Environment Variables on Target Computer

### For Manual Setup on Target Computer:

```bash
# 1. Boot from Arch Linux ISO

# 2. Set environment variables manually
export DEPLOY_USER_PASSWORD="your_user_password"
export DEPLOY_ROOT_PASSWORD="your_root_password"
export DEPLOY_LUKS_PASSPHRASE="your_luks_passphrase"
export DEPLOY_WIFI_PASSWORD="your_wifi_password"

# 3. Download and run deployment
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git && cd YOUR_REPO
chmod +x deploy.sh
./scripts/deploy.sh full --password env
```

### For Scripted Setup:

Create a setup script that you run on the target computer:

```bash
#!/bin/bash
# save as setup-deployment.sh

echo "🔐 Setting up Arch Linux deployment..."

# Prompt for passwords securely
echo "Enter user password:"
read -s USER_PASS
echo "Enter root password:"
read -s ROOT_PASS
echo "Enter LUKS passphrase (optional):"
read -s LUKS_PASS

# Export environment variables
export DEPLOY_USER_PASSWORD="$USER_PASS"
export DEPLOY_ROOT_PASSWORD="$ROOT_PASS"
export DEPLOY_LUKS_PASSPHRASE="$LUKS_PASS"

# Download and run deployment
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git && cd YOUR_REPO
chmod +x deploy.sh
./scripts/deploy.sh full --password env

# Clean up
unset DEPLOY_USER_PASSWORD DEPLOY_ROOT_PASSWORD DEPLOY_LUKS_PASSPHRASE
```

## 🚀 Method 3: Auto-Generated Passwords (Simplest)

**For development/testing** where you don't care about specific passwords:

```bash
# 1. Boot from Arch Linux ISO

# 2. Download and run with auto-generated passwords
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git && cd YOUR_REPO
chmod +x deploy.sh

# 3. Use auto-generated passwords
./deploy.sh --password-mode generate
# Passwords will be displayed on screen for you to save
```

## 🚀 Method 4: Pre-Built Installation Image (Advanced)

### Create Custom ISO with Passwords

```yaml
# .github/workflows/build-custom-iso.yml
name: Build Custom ISO

on:
  workflow_dispatch:

jobs:
  build-iso:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Build custom Arch ISO
      run: |
        # Download Arch Linux ISO
        # Customize with passwords and deployment script
        # Upload as release artifact
        
    - name: Upload custom ISO
      uses: actions/upload-artifact@v4
      with:
        name: custom-arch-iso
        path: custom-arch.iso
```

## 📋 Complete Step-by-Step Example

Let's walk through **Method 1** (encrypted file) completely:

### On GitHub (One Time Setup):
1. **Store passwords** in GitHub Secrets (as shown in previous guide)
2. **Add the password file generator workflow** to your repository
3. **Run the workflow** to generate `passwords.enc`
4. **Download** the encrypted file

### On Target Computer:
```bash
# 1. Boot from Arch Linux ISO

# 2. Connect to internet
wifi-menu  # or use ethernet

# 3. Transfer encrypted password file (choose one method):

# Method A: From USB stick
mkdir /mnt/usb
mount /dev/sdb1 /mnt/usb  # adjust device as needed
cp /mnt/usb/passwords.enc .

# Method B: Download from release
curl -L -o passwords.enc "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/passwords.enc"

# Method C: From temporary upload
curl -o passwords.enc "https://transfer.sh/get/abc123/passwords.enc"

# 4. Download deployment script
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git && cd YOUR_REPO
chmod +x deploy.sh

# 5. Run deployment
./deploy.sh --password-mode file --password-file passwords.enc
# Enter your encryption passphrase when prompted

# 6. Wait for completion (30-60 minutes)
# System will reboot automatically to Hyprland desktop
```

## 🔒 Security Considerations

### Encrypted File Method (Most Secure):
✅ **Passwords encrypted** with your passphrase  
✅ **Temporary file** can be deleted after use  
✅ **No plain text** storage anywhere  

### Environment Variables Method:
✅ **No file storage** of passwords  
⚠️ **Manual entry** required each time  
⚠️ **Visible in process list** temporarily  

### Auto-Generation Method:
✅ **No password management** needed  
⚠️ **Random passwords** you need to save  
⚠️ **Less control** over password format  

## 🎯 Which Method to Choose?

| Scenario | Recommended Method | Why |
|----------|-------------------|-----|
| **Production deployment** | Encrypted File | Maximum security, reusable |
| **Development/Testing** | Auto-Generated | Quick and easy |
| **One-off installation** | Environment Variables | No file management |
| **Multiple computers** | Encrypted File | Consistent passwords |

## 🔧 Troubleshooting

**"Can't download passwords.enc":**
- Check GitHub repository is public or you have access
- Verify the download URL is correct
- Try alternative transfer methods (USB, temporary upload)

**"Wrong passphrase" error:**
- Double-check the encryption passphrase you used
- Try re-generating the password file
- Ensure no typos in the passphrase

**"No internet on target computer":**
- Use USB stick method to transfer files
- Set up WiFi with `wifi-menu` command
- Check ethernet cable connection

The key point is: **GitHub Secrets → Generate encrypted file → Transfer to target computer → Deploy with encrypted file**

This workflow gives you the security of GitHub Secrets with the practicality of local deployment.