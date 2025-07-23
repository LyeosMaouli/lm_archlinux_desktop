# System Tools

This directory contains **next-generation utility tools** for system management, monitoring, and maintenance of the Arch Linux Hyprland system. Now includes **container development support**, **performance monitoring**, and **enhanced structured logging**.

## Tools Overview

### 📊 system_info.sh
Comprehensive system information display tool with **container awareness**.

**Features:**
- Hardware information (CPU, memory, graphics, storage)
- Hyprland environment status
- Network configuration
- Service status monitoring
- Package information
- Security status overview
- Performance metrics
- **🆕 Container environment detection**
- **🆕 Development environment status**
- **🆕 Structured JSON output support**

**Usage:**
```bash
./system_info.sh           # Standard output
./system_info.sh --json    # 🆕 JSON structured output
./system_info.sh --dev     # 🆕 Development environment focus
```

### 📦 package_manager.sh
Unified interface for pacman and AUR package management.

**Features:**
- System updates (pacman + AUR)
- Package installation/removal
- Package search and information
- Orphan package cleanup
- Package list backup/restore
- Automated yay installation

**Usage:**
```bash
./package_manager.sh update
./package_manager.sh install firefox code
./package_manager.sh search hyprland
./package_manager.sh clean
```

### 🔧 hardware_checker.sh
Hardware compatibility validation for Arch Linux Hyprland.

**Features:**
- CPU architecture and feature validation
- Memory requirements check
- Graphics hardware compatibility
- Storage requirements validation
- Network hardware detection
- Wayland compatibility assessment
- Boot system analysis (UEFI/BIOS)

**Usage:**
```bash
./hardware_checker.sh
```

### 💾 backup_manager.sh
Comprehensive backup and restore solution.

**Features:**
- Full system backups
- Selective backups (config, user data, custom)
- Compressed archive creation
- Backup verification
- Restore functionality
- Automatic cleanup of old backups
- Package list preservation

**Usage:**
```bash
./backup_manager.sh create full
./backup_manager.sh list
./backup_manager.sh restore 20240101-120000
```

## Tool Categories

### System Information
- **system_info.sh**: Real-time system status and configuration display with container awareness
- **hardware_checker.sh**: Hardware compatibility and requirement validation

### Package Management
- **package_manager.sh**: Unified pacman/AUR interface with enhanced features

### Data Management
- **backup_manager.sh**: Complete backup and restore solution with verification

### 🆕 Development Environment
- **Container Integration**: All tools work seamlessly in DevContainers and Docker Compose environments
- **Performance Monitoring**: Built-in deployment performance tracking and analytics
- **Structured Logging**: JSON-based logging with correlation IDs for monitoring
- **Development Workflows**: Enhanced support for container-based development

## Integration

These tools are designed to work with the Ansible automation system:

### Ansible Integration Points
- Can be deployed via `configs/ansible/roles/system_tools/`
- Configured through Ansible variables
- Called from maintenance playbooks

### Script Dependencies
```bash
# Install required dependencies
sudo pacman -S --needed jq curl tar gzip findutils coreutils

# For AUR functionality
./package_manager.sh install-yay
```

## Configuration

### Environment Variables
```bash
# Package manager
export AUR_HELPER="yay"  # or "paru"

# Backup manager
export BACKUP_DIR="$HOME/backups"
export KEEP_BACKUPS="7"
```

### Configuration Files
- `~/.config/backup-manager.conf`: Backup settings
- `/var/log/`: Tool logs and reports

## Common Workflows

### 🆕 Container Development Workflow
```bash
# In DevContainer or Docker Compose environment
# All tools work seamlessly in containers

# Container-aware system info
./system_info.sh --dev

# Performance monitoring for deployments
dev-monitor deployment_123

# Structured logging analysis
dev-audit-logs --correlation-id deployment_123

# Container-specific package management
./package_manager.sh check --container-safe
```

### System Health Check
```bash
# Check hardware compatibility
./hardware_checker.sh

# View system information (with container detection)
./system_info.sh

# Check for updates
./package_manager.sh check
```

### System Maintenance
```bash
# Update system
./package_manager.sh update

# Clean packages
./package_manager.sh clean

# Create backup
./backup_manager.sh create full

# Cleanup old backups
./backup_manager.sh cleanup
```

### Emergency Recovery
```bash
# List available backups
./backup_manager.sh list

# Verify backup integrity
./backup_manager.sh verify 20240101-120000

# Restore configuration
./backup_manager.sh restore 20240101-120000 .config
```

## Output and Logging

### Log Files
- `/var/log/system-info.log`: System information queries
- `/var/log/package-manager.log`: Package operations
- `/var/log/backup-manager.log`: Backup operations
- `/tmp/hardware-check-*.log`: Hardware validation reports

### Report Formats
- Colored terminal output with status indicators
- Structured logs with timestamps
- JSON output available for some tools
- Detailed reports saved to files

## Security Considerations

### Permissions
- Most tools run as regular user
- System modifications require sudo
- Backup restoration prompts for confirmation
- Package installation requires authentication

### Data Protection
- Backups exclude sensitive cache files
- SSH keys and GPG data handled securely
- Configuration files preserved with proper permissions
- No credentials stored in plain text

## Performance Impact

### Resource Usage
- **system_info.sh**: Minimal impact, read-only operations
- **package_manager.sh**: Moderate during updates/installations
- **hardware_checker.sh**: Low impact, mostly reads system files
- **backup_manager.sh**: High I/O during backup operations

### Optimization
- Parallel operations where possible
- Efficient file exclusion patterns
- Compressed archives to save space
- Incremental backup support planned

## Troubleshooting

### Common Issues

**Package Manager Issues:**
```bash
# Reset pacman keys
sudo pacman-key --init
sudo pacman-key --populate archlinux

# Clear package cache
sudo pacman -Scc
```

**Backup Issues:**
```bash
# Check disk space
df -h

# Verify backup integrity
./backup_manager.sh verify BACKUP_ID

# Check permissions
ls -la $BACKUP_DIR
```

**Hardware Checker Issues:**
```bash
# Install missing dependencies
sudo pacman -S --needed lspci-utils dmidecode

# Run with verbose output
./hardware_checker.sh > hardware-report.txt 2>&1
```

### Debug Mode
Most tools support verbose output:
```bash
# Enable debug logging
export DEBUG=1
./tool_name.sh
```

## Customization

### Adding Custom Checks
Tools are designed to be extensible. Add custom functions following the existing patterns:

```bash
# In hardware_checker.sh
check_custom_hardware() {
    print_section "Custom Hardware Check"
    # Your custom checks here
}
```

### Configuration Templates
Create configuration templates for different environments:
- Development workstation
- Production server
- Minimal installation

## Support and Updates

### Tool Updates
Tools are version-controlled with the main project. Update via:
```bash
git pull origin main
chmod +x tools/*.sh
```

### Documentation
- Individual tool help: `./tool_name.sh --help`
- Project documentation: `docs/`
- Configuration examples: `configs/`

### Issue Reporting
For tool-specific issues:
1. Check tool logs
2. Run with debug output
3. Verify dependencies
4. Test in isolated environment