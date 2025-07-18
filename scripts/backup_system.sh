#!/bin/bash
# scripts/backup_system.sh - Automated system backup

BACKUP_DIR="/backup/$(hostname)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

create_backup() {
    mkdir -p "$BACKUP_PATH"
    
    # System configuration backup
    rsync -aAXH --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "$BACKUP_PATH/system/"
    
    # User data backup
    rsync -aAXH "/home/$USER/" "$BACKUP_PATH/home/"
    
    # Database backup of installed packages
    pacman -Qqe > "$BACKUP_PATH/packages_explicit.txt"
    pacman -Qqm > "$BACKUP_PATH/packages_aur.txt"
    
    # Configuration checksums
    find /etc -type f -exec sha256sum {} \; > "$BACKUP_PATH/config_checksums.txt"
    
    echo "Backup completed: $BACKUP_PATH"
}

restore_backup() {
    local backup_path=$1
    
    if [ ! -d "$backup_path" ]; then
        echo "Backup path not found: $backup_path"
        exit 1
    fi
    
    # Restore system files
    rsync -aAXH "$backup_path/system/" /
    
    # Restore user data
    rsync -aAXH "$backup_path/home/" "/home/$USER/"
    
    # Reinstall packages
    pacman -S --needed - < "$backup_path/packages_explicit.txt"
    
    echo "Restore completed from: $backup_path"
}

case "$1" in
    create)
        create_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    *)
        echo "Usage: $0 {create|restore} [backup_path]"
        exit 1
        ;;
esac