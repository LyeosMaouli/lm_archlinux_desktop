# GitHub Password Storage Guide

## 🔐 How to Store Passwords Safely in GitHub for Arch Linux Deployment

This guide shows you how to securely store and use passwords in GitHub for automated Arch Linux deployment using our password management system.

## 📋 Prerequisites

- GitHub repository (fork or your own copy of this project)
- GitHub account with repository access
- Basic understanding of GitHub Actions

## 🚀 Step-by-Step Setup Guide

### Step 1: Fork or Clone the Repository

If you haven't already, get your own copy of the repository:

**Option A: Fork the Repository**
1. Go to https://github.com/LyeosMaouli/lm_archlinux_desktop
2. Click the "Fork" button in the top right
3. Choose your account as the destination

**Option B: Clone to Your Own Repository**
```bash
# Clone the original repository
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Create your own repository on GitHub first, then:
git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git push -u origin main
```

### Step 2: Access Repository Settings

1. Go to your GitHub repository
2. Click on **"Settings"** tab (not your account settings, but repository settings)
3. In the left sidebar, scroll down to **"Security"** section
4. Click on **"Secrets and variables"**
5. Click on **"Actions"**

![GitHub Secrets Navigation](https://docs.github.com/assets/cb-45016/images/help/repository/repo-actions-settings.png)

### Step 3: Create Repository Secrets

You'll see a page with tabs: "Secrets" and "Variables". Stay on the **"Secrets"** tab.

#### Required Secrets (Minimum Setup)

Click **"New repository secret"** for each of these:

**1. DEPLOY_USER_PASSWORD**
- **Name**: `DEPLOY_USER_PASSWORD`
- **Secret**: Your desired user account password (minimum 8 characters)
- **Example**: `MySecure#UserPass2024!`

**2. DEPLOY_ROOT_PASSWORD**
- **Name**: `DEPLOY_ROOT_PASSWORD`  
- **Secret**: Your desired root/admin password (minimum 8 characters)
- **Example**: `MySecure#RootPass2024!`

#### Optional Secrets (Enhanced Setup)

**3. DEPLOY_LUKS_PASSPHRASE** (if you want disk encryption)
- **Name**: `DEPLOY_LUKS_PASSPHRASE`
- **Secret**: Your disk encryption passphrase (minimum 12 characters)
- **Example**: `My-Very-Secure-Disk-Encryption-Passphrase-2024!`

**4. DEPLOY_WIFI_PASSWORD** (if you need WiFi setup)
- **Name**: `DEPLOY_WIFI_PASSWORD`
- **Secret**: Your WiFi network password
- **Example**: `YourWiFiPassword123`

#### Notification Secrets (Optional)

**5. Email Notifications** (if you want deployment status emails)
- **DEPLOY_EMAIL_RECIPIENT**: `your-email@example.com`
- **DEPLOY_SMTP_SERVER**: `smtp.gmail.com`
- **DEPLOY_SMTP_USERNAME**: `your-sender@gmail.com`
- **DEPLOY_SMTP_PASSWORD**: `your-app-password` (see Gmail setup below)

### Step 4: Configure GitHub Actions Workflow

Create or update your GitHub Actions workflow file:

**Create file**: `.github/workflows/deploy-arch.yml`

```yaml
name: Deploy Arch Linux

on:
  workflow_dispatch:
    inputs:
      enable_encryption:
        description: 'Enable disk encryption'
        required: true
        default: true
        type: boolean

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      
    - name: Deploy Arch Linux
      run: |
        # Download and run deployment script
        curl -fsSL https://raw.githubusercontent.com/${{ github.repository }}/main/scripts/deployment/zero_touch_deploy.sh -o deploy.sh
        chmod +x deploy.sh
        ./deploy.sh --password-mode env
      env:
        DEPLOY_USER_PASSWORD: ${{ secrets.DEPLOY_USER_PASSWORD }}
        DEPLOY_ROOT_PASSWORD: ${{ secrets.DEPLOY_ROOT_PASSWORD }}
        DEPLOY_LUKS_PASSPHRASE: ${{ secrets.DEPLOY_LUKS_PASSPHRASE }}
        DEPLOY_WIFI_PASSWORD: ${{ secrets.DEPLOY_WIFI_PASSWORD }}
```

### Step 5: Set Up Email Notifications (Optional)

If you want to receive deployment notifications via email:

#### Gmail Setup
1. **Enable 2-Factor Authentication** on your Gmail account
2. **Generate App Password**:
   - Go to Google Account settings
   - Security → 2-Step Verification → App passwords
   - Generate password for "Mail"
   - Use this as `DEPLOY_SMTP_PASSWORD`

#### Add Email Secrets
```
DEPLOY_EMAIL_RECIPIENT = your-email@gmail.com
DEPLOY_SMTP_SERVER = smtp.gmail.com
DEPLOY_SMTP_USERNAME = your-sender@gmail.com
DEPLOY_SMTP_PASSWORD = your-16-digit-app-password
```

### Step 6: Test Your Setup

1. Go to your repository on GitHub
2. Click **"Actions"** tab
3. Click **"Deploy Arch Linux"** workflow
4. Click **"Run workflow"** button
5. Choose encryption option and click **"Run workflow"**

The workflow will start and use your stored secrets automatically.

## 🔒 Security Best Practices

### Password Guidelines

**Strong Passwords Should Have**:
- Minimum 8 characters (12+ recommended)
- Mix of uppercase and lowercase letters
- Numbers and special characters
- No dictionary words or personal information

**Good Password Examples**:
```
User Password: "MyStr0ng#User2024!"
Root Password: "Admin$Secure&Pass789"
LUKS Passphrase: "My-Super-Secure-Disk-Encryption-2024!"
```

**Avoid These Passwords**:
```
❌ "password123"
❌ "admin"
❌ "123456"
❌ Your name or birthday
```

### GitHub Secrets Security

✅ **GitHub Secrets are**:
- Encrypted at rest
- Never visible in logs
- Only accessible to authorized workflows
- Automatically masked in output

✅ **Best Practices**:
- Use unique passwords for each system
- Rotate passwords regularly
- Never hardcode passwords in workflow files
- Use least privilege access principles

❌ **Never Do**:
- Commit passwords to repository files
- Share secrets via insecure channels
- Use the same password everywhere
- Store secrets in workflow YAML files

## 🎯 Complete Setup Example

Here's what your secrets should look like in GitHub:

```
Repository Secrets:
├── DEPLOY_USER_PASSWORD ********** (masked)
├── DEPLOY_ROOT_PASSWORD ********** (masked)  
├── DEPLOY_LUKS_PASSPHRASE **************** (masked)
├── DEPLOY_WIFI_PASSWORD ******** (masked)
├── DEPLOY_EMAIL_RECIPIENT your-email@gmail.com
├── DEPLOY_SMTP_SERVER smtp.gmail.com
├── DEPLOY_SMTP_USERNAME sender@gmail.com
└── DEPLOY_SMTP_PASSWORD **************** (masked)
```

## 🚀 Running Your Deployment

### Method 1: Manual Workflow Run
1. Go to **Actions** tab in your repository
2. Select **"Deploy Arch Linux"** workflow
3. Click **"Run workflow"**
4. Configure options and run

### Method 2: Automatic Triggers
You can modify the workflow to run automatically:

```yaml
on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM
```

### Method 3: API Trigger
```bash
# Trigger deployment via GitHub API
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/actions/workflows/deploy-arch.yml/dispatches \
  -d '{"ref":"main"}'
```

## 🔍 Monitoring and Troubleshooting

### View Deployment Logs
1. Go to **Actions** tab
2. Click on a workflow run
3. Click on the job name
4. Expand steps to see detailed logs

### Common Issues

**"Secret not found" errors**:
- Check secret names match exactly (case-sensitive)
- Ensure secrets are created in repository settings
- Verify workflow has access to secrets

**"Password too weak" errors**:
- Increase password length (minimum 8 characters)
- Add more character types (uppercase, numbers, symbols)

**Email delivery fails**:
- Verify SMTP credentials
- Check if 2-factor authentication is enabled
- Use app passwords for Gmail

### Debug Your Setup
Add this step to your workflow for debugging:

```yaml
- name: Debug Environment
  run: |
    echo "Checking password environment..."
    if [[ -n "$DEPLOY_USER_PASSWORD" ]]; then
      echo "✅ User password is set (${#DEPLOY_USER_PASSWORD} chars)"
    else
      echo "❌ User password not found"
    fi
    
    if [[ -n "$DEPLOY_ROOT_PASSWORD" ]]; then
      echo "✅ Root password is set (${#DEPLOY_ROOT_PASSWORD} chars)"
    else
      echo "❌ Root password not found"
    fi
  env:
    DEPLOY_USER_PASSWORD: ${{ secrets.DEPLOY_USER_PASSWORD }}
    DEPLOY_ROOT_PASSWORD: ${{ secrets.DEPLOY_ROOT_PASSWORD }}
```

## 🎉 You're All Set!

Once configured, your GitHub repository will:

✅ **Securely store** all deployment passwords  
✅ **Automatically deploy** Arch Linux systems  
✅ **Send notifications** on completion  
✅ **Maintain security** with encrypted secrets  
✅ **Provide audit logs** of all deployments  

Your passwords are now safely stored in GitHub and ready for automated deployment!

## 📞 Need Help?

- **Check the logs** in GitHub Actions for specific error messages
- **Review the password requirements** in the error output
- **Verify secret names** match exactly (case-sensitive)
- **Test individual components** before full deployment

The system is designed to provide clear error messages to help you troubleshoot any issues.