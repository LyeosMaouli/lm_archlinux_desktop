#!/bin/bash
# Backup Manager Tool
# Comprehensive backup and restore solution for Arch Linux system

set -euo pipefail
# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Configuration
BACKUP_BASE_DIR="${BACKUP_DIR:-$HOME/backups}"
CONFIG_FILE="$HOME/.config/backup-manager.conf"

# Default backup items
DEFAULT_BACKUP_ITEMS=(
    "$HOME/.config"
    "$HOME/.local/share"
    "$HOME/.ssh"
    "$HOME/.gnupg"
    "$HOME/Documents"
    "$HOME/Pictures"
    "$HOME/Videos"
    "$HOME/Music"
    "/etc/fstab"
    "/etc/hosts"
    "/etc/hostname"
    "/etc/locale.conf"
    "/etc/vconsole.conf"
    "/etc/mkinitcpio.conf"
    "/boot/loader"
)






# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        log_info "No configuration file found, using defaults"
    fi
}

# Save configuration
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    cat > "$CONFIG_FILE" << EOF
# Backup Manager Configuration
BACKUP_BASE_DIR="$BACKUP_BASE_DIR"
COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"
EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-*.tmp *.cache *.log}"
BACKUP_ENCRYPTION="${BACKUP_ENCRYPTION:-false}"
EOF
    
    log_success "Configuration saved to $CONFIG_FILE"
}

# Initialize backup environment
init_backup() {
    mkdir -p "$BACKUP_BASE_DIR"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Create backup directories
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$BACKUP_BASE_DIR/$timestamp"
    
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Create system backup
create_system_backup() {
    local backup_type="${1:-full}"
    local custom_items=("${@:2}")
    
    log_info "Creating $backup_type backup..."
    log_to_file "Starting $backup_type backup"
    
    local backup_dir
    backup_dir=$(init_backup)
    local timestamp=$(basename "$backup_dir")
    
    # Determine what to backup
    local backup_items=()
    
    case "$backup_type" in
        "full")
            backup_items=("${DEFAULT_BACKUP_ITEMS[@]}")
            if [[ ${#custom_items[@]} -gt 0 ]]; then
                backup_items+=("${custom_items[@]}")
            fi
            ;;
        "config")
            backup_items=(
                "$HOME/.config"
                "/etc"
            )
            ;;
        "user")
            backup_items=(
                "$HOME/Documents"
                "$HOME/Pictures"
                "$HOME/Videos"
                "$HOME/Music"
                "$HOME/Downloads"
            )
            ;;
        "custom")
            backup_items=("${custom_items[@]}")
            ;;
    esac
    
    # Create backup manifest
    local manifest_file="$backup_dir/backup-manifest.txt"
    {
        echo "# Backup Manifest"
        echo "# Created: $(date)"
        echo "# Hostname: $(hostname)"
        echo "# User: $(whoami)"
        echo "# Type: $backup_type"
        echo ""
        echo "# Backup Items:"
        printf '%s\n' "${backup_items[@]}"
    } > "$manifest_file"
    
    # Create system info
    local sysinfo_file="$backup_dir/system-info.txt"
    {
        echo "# System Information"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
        echo "Backup Date: $(date)"
        echo ""
        echo "# Package List"
        pacman -Q > "$backup_dir/package-list.txt" 2>/dev/null || true
        pacman -Qe > "$backup_dir/explicit-packages.txt" 2>/dev/null || true
        pacman -Qm > "$backup_dir/aur-packages.txt" 2>/dev/null || true
    } > "$sysinfo_file"
    
    # Backup each item
    local success_count=0
    local fail_count=0
    
    for item in "${backup_items[@]}"; do
        if [[ -e "$item" ]]; then
            local item_name
            item_name=$(basename "$item")
            local backup_file="$backup_dir/${item_name}-backup.tar.gz"
            
            log_info "Backing up: $item"
            
            # Create exclude file for common patterns
            local exclude_file
            exclude_file=$(mktemp)
            {
                echo "*.tmp"
                echo "*.cache"
                echo "*.log"
                echo ".git"
                echo "node_modules"
                echo "__pycache__"
                echo "*.pyc"
                echo ".DS_Store"
                echo "Thumbs.db"
            } > "$exclude_file"
            
            if tar -czf "$backup_file" -X "$exclude_file" -C "$(dirname "$item")" "$(basename "$item")" 2>/dev/null; then
                local size
                size=$(du -h "$backup_file" | cut -f1)
                log_success "Backed up $item ($size)"
                echo "$item -> $backup_file ($size)" >> "$backup_dir/backup-log.txt"
                ((success_count++))
            else
                log_error "Failed to backup $item"
                echo "FAILED: $item" >> "$backup_dir/backup-log.txt"
                ((fail_count++))
            fi
            
            rm -f "$exclude_file"
        else
            log_warn "Item not found: $item"
            echo "NOT_FOUND: $item" >> "$backup_dir/backup-log.txt"
        fi
    done
    
    # Create backup summary
    local summary_file="$backup_dir/backup-summary.txt"
    {
        echo "# Backup Summary"
        echo "Backup Type: $backup_type"
        echo "Timestamp: $timestamp"
        echo "Success Count: $success_count"
        echo "Failed Count: $fail_count"
        echo "Total Size: $(du -sh "$backup_dir" | cut -f1)"
        echo ""
        echo "# Verification"
        find "$backup_dir" -name "*.tar.gz" -exec tar -tzf {} \; > "$backup_dir/file-list.txt" 2>/dev/null || true
    } > "$summary_file"
    
    # Compress entire backup if requested
    if [[ "${COMPRESS_BACKUP:-true}" == "true" ]]; then
        log_info "Compressing backup archive..."
        local archive_file="$BACKUP_BASE_DIR/backup-$timestamp.tar.gz"
        
        if tar -czf "$archive_file" -C "$BACKUP_BASE_DIR" "$timestamp"; then
            rm -rf "$backup_dir"
            log_success "Backup archived to: $archive_file"
            echo "$archive_file"
        else
            log_error "Failed to create backup archive"
            echo "$backup_dir"
        fi
    else
        log_success "Backup completed: $backup_dir"
        echo "$backup_dir"
    fi
    
    log_to_file "Backup completed: $success_count success, $fail_count failed"
    
    # Cleanup old backups
    cleanup_old_backups
}

# List available backups
list_backups() {
    log_info "Available backups in $BACKUP_BASE_DIR:"
    
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log_warn "Backup directory not found: $BACKUP_BASE_DIR"
        return 1
    fi
    
    local backup_count=0
    
    # List directories
    while IFS= read -r -d '' backup_dir; do
        local timestamp
        timestamp=$(basename "$backup_dir")
        local size
        size=$(du -sh "$backup_dir" | cut -f1)
        
        # Check for summary file
        if [[ -f "$backup_dir/backup-summary.txt" ]]; then
            local backup_type
            backup_type=$(grep "Backup Type:" "$backup_dir/backup-summary.txt" | cut -d: -f2 | tr -d ' ')
            echo "  $timestamp ($backup_type, $size)"
        else
            echo "  $timestamp ($size)"
        fi
        
        ((backup_count++))
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "20*" -print0 2>/dev/null | sort -z)
    
    # List archive files
    while IFS= read -r -d '' archive_file; do
        local filename
        filename=$(basename "$archive_file")
        local size
        size=$(du -sh "$archive_file" | cut -f1)
        echo "  $filename (archive, $size)"
        ((backup_count++))
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type f -name "backup-*.tar.gz" -print0 2>/dev/null | sort -z)
    
    if [[ $backup_count -eq 0 ]]; then
        log_info "No backups found"
    else
        log_info "Total backups: $backup_count"
    fi
}

# Show backup details
show_backup_info() {
    local backup_id="$1"
    
    if [[ -z "$backup_id" ]]; then
        log_error "No backup ID specified"
        return 1
    fi
    
    local backup_path="$BACKUP_BASE_DIR/$backup_id"
    local archive_path="$BACKUP_BASE_DIR/backup-$backup_id.tar.gz"
    
    # Check for directory
    if [[ -d "$backup_path" ]]; then
        log_info "Backup Information: $backup_id"
        
        if [[ -f "$backup_path/backup-summary.txt" ]]; then
            cat "$backup_path/backup-summary.txt"
        fi
        
        if [[ -f "$backup_path/backup-manifest.txt" ]]; then
            echo ""
            echo "Backup Manifest:"
            cat "$backup_path/backup-manifest.txt"
        fi
        
    # Check for archive
    elif [[ -f "$archive_path" ]]; then
        log_info "Backup Archive: $archive_path"
        
        # Extract and show summary
        local temp_dir
        temp_dir=$(mktemp -d)
        
        if tar -xzf "$archive_path" -C "$temp_dir" 2>/dev/null; then
            local extracted_dir
            extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "20*" | head -1)
            
            if [[ -f "$extracted_dir/backup-summary.txt" ]]; then
                cat "$extracted_dir/backup-summary.txt"
            fi
        fi
        
        rm -rf "$temp_dir"
    else
        log_error "Backup not found: $backup_id"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    local backup_id="$1"
    local restore_items=("${@:2}")
    
    if [[ -z "$backup_id" ]]; then
        log_error "No backup ID specified"
        return 1
    fi
    
    log_warn "This will overwrite existing files. Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    local backup_path="$BACKUP_BASE_DIR/$backup_id"
    local archive_path="$BACKUP_BASE_DIR/backup-$backup_id.tar.gz"
    local temp_dir
    
    # Handle archive extraction
    if [[ -f "$archive_path" ]]; then
        log_info "Extracting backup archive..."
        temp_dir=$(mktemp -d)
        
        if tar -xzf "$archive_path" -C "$temp_dir"; then
            backup_path=$(find "$temp_dir" -maxdepth 1 -type d -name "20*" | head -1)
        else
            log_error "Failed to extract backup archive"
            return 1
        fi
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_info "Restoring from backup: $backup_id"
    log_to_file "Starting restore from backup: $backup_id"
    
    # If no specific items, restore all
    if [[ ${#restore_items[@]} -eq 0 ]]; then
        restore_items=($(find "$backup_path" -name "*-backup.tar.gz" -exec basename {} \; | sed 's/-backup\.tar\.gz$//' 2>/dev/null || true))
    fi
    
    local success_count=0
    local fail_count=0
    
    for item in "${restore_items[@]}"; do
        local backup_file="$backup_path/${item}-backup.tar.gz"
        
        if [[ -f "$backup_file" ]]; then
            log_info "Restoring: $item"
            
            # Determine restore location
            local restore_location
            case "$item" in
                ".config"|".local"|".ssh"|".gnupg")
                    restore_location="$HOME"
                    ;;
                "Documents"|"Pictures"|"Videos"|"Music")
                    restore_location="$HOME"
                    ;;
                "etc")
                    restore_location="/"
                    ;;
                "loader")
                    restore_location="/boot"
                    ;;
                *)
                    restore_location="$HOME"
                    ;;
            esac
            
            # Create backup of existing files
            local existing_backup
            existing_backup="/tmp/restore-backup-$(date +%s)-$item"
            
            if [[ -e "$restore_location/$item" ]]; then
                log_info "Backing up existing $item to $existing_backup"
                cp -r "$restore_location/$item" "$existing_backup" 2>/dev/null || true
            fi
            
            # Restore files
            if tar -xzf "$backup_file" -C "$restore_location" 2>/dev/null; then
                log_success "Restored: $item"
                ((success_count++))
            else
                log_error "Failed to restore: $item"
                
                # Restore original if backup exists
                if [[ -e "$existing_backup" ]]; then
                    log_info "Restoring original $item"
                    rm -rf "$restore_location/$item" 2>/dev/null || true
                    mv "$existing_backup" "$restore_location/$item" 2>/dev/null || true
                fi
                
                ((fail_count++))
            fi
        else
            log_warn "Backup file not found: $backup_file"
        fi
    done
    
    # Cleanup temp directory
    if [[ -n "${temp_dir:-}" ]]; then
        rm -rf "$temp_dir"
    fi
    
    log_info "Restore completed: $success_count success, $fail_count failed"
    log_to_file "Restore completed: $success_count success, $fail_count failed"
    
    if [[ $success_count -gt 0 ]]; then
        log_warn "Some files have been restored. You may need to restart applications or log out/in."
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    local keep_count="${KEEP_BACKUPS:-7}"
    
    log_info "Cleaning up old backups (keeping $keep_count most recent)..."
    
    # Count backups
    local backup_count
    backup_count=$(find "$BACKUP_BASE_DIR" -maxdepth 1 \( -type d -name "20*" -o -type f -name "backup-*.tar.gz" \) | wc -l)
    
    if [[ $backup_count -le $keep_count ]]; then
        log_info "No cleanup needed ($backup_count backups, keeping $keep_count)"
        return 0
    fi
    
    # Remove old directories
    find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "20*" | sort | head -n -"$keep_count" | while read -r old_backup; do
        log_info "Removing old backup: $(basename "$old_backup")"
        rm -rf "$old_backup"
    done
    
    # Remove old archives
    find "$BACKUP_BASE_DIR" -maxdepth 1 -type f -name "backup-*.tar.gz" | sort | head -n -"$keep_count" | while read -r old_archive; do
        log_info "Removing old archive: $(basename "$old_archive")"
        rm -f "$old_archive"
    done
    
    log_success "Cleanup completed"
}

# Verify backup integrity
verify_backup() {
    local backup_id="$1"
    
    if [[ -z "$backup_id" ]]; then
        log_error "No backup ID specified"
        return 1
    fi
    
    local backup_path="$BACKUP_BASE_DIR/$backup_id"
    local archive_path="$BACKUP_BASE_DIR/backup-$backup_id.tar.gz"
    
    log_info "Verifying backup: $backup_id"
    
    # Handle archive
    if [[ -f "$archive_path" ]]; then
        log_info "Verifying archive integrity..."
        if tar -tzf "$archive_path" >/dev/null 2>&1; then
            log_success "Archive integrity OK"
        else
            log_error "Archive is corrupted"
            return 1
        fi
        
        # Extract for further verification
        local temp_dir
        temp_dir=$(mktemp -d)
        tar -xzf "$archive_path" -C "$temp_dir"
        backup_path=$(find "$temp_dir" -maxdepth 1 -type d -name "20*" | head -1)
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found"
        return 1
    fi
    
    # Verify individual backup files
    local total_files=0
    local corrupt_files=0
    
    while IFS= read -r -d '' backup_file; do
        ((total_files++))
        
        if tar -tzf "$backup_file" >/dev/null 2>&1; then
            log_success "OK: $(basename "$backup_file")"
        else
            log_error "CORRUPT: $(basename "$backup_file")"
            ((corrupt_files++))
        fi
    done < <(find "$backup_path" -name "*-backup.tar.gz" -print0 2>/dev/null)
    
    # Cleanup temp directory
    if [[ -n "${temp_dir:-}" ]]; then
        rm -rf "$temp_dir"
    fi
    
    log_info "Verification completed: $((total_files - corrupt_files))/$total_files files OK"
    
    if [[ $corrupt_files -eq 0 ]]; then
        log_success "Backup verification passed"
        return 0
    else
        log_error "Backup verification failed: $corrupt_files corrupt files"
        return 1
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Backup Manager Tool - Comprehensive backup and restore solution

Usage: backup_manager.sh [COMMAND] [OPTIONS]

Commands:
  create [TYPE] [ITEMS...]     Create backup
    Types: full, config, user, custom
    
  list                         List available backups
  info <BACKUP_ID>            Show backup details
  restore <BACKUP_ID> [ITEMS...] Restore from backup
  verify <BACKUP_ID>          Verify backup integrity
  cleanup                     Remove old backups
  config                      Configure backup settings

Examples:
  ./backup_manager.sh create full
  ./backup_manager.sh create config
  ./backup_manager.sh create custom ~/.vimrc ~/scripts
  ./backup_manager.sh list
  ./backup_manager.sh info 20240101-120000
  ./backup_manager.sh restore 20240101-120000
  ./backup_manager.sh verify 20240101-120000

Configuration:
  Configuration file: ~/.config/backup-manager.conf
  
  BACKUP_BASE_DIR     Base backup directory
  KEEP_BACKUPS        Number of backups to keep (default: 7)
  COMPRESS_BACKUP     Create compressed archives (default: true)

Default backup items:
  - User configuration (~/.config, ~/.local/share)
  - SSH keys and GPG keys
  - Documents, Pictures, Videos, Music
  - System configuration (/etc files)
  - Boot loader configuration

EOF
}

# Main script logic
main() {
    load_config
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "${1:-}" in
        "create")
            shift
            create_system_backup "$@"
            ;;
        "list")
            list_backups
            ;;
        "info")
            show_backup_info "${2:-}"
            ;;
        "restore")
            shift
            restore_backup "$@"
            ;;
        "verify")
            verify_backup "${2:-}"
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "config")
            save_config
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"