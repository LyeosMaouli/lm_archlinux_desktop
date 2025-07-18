# scripts/profile_manager.sh - Multiple configuration profiles
#!/bin/bash

PROFILES_DIR="configs/profiles"
CURRENT_PROFILE="$HOME/.current_profile"

switch_profile() {
    local profile=$1
    local profile_dir="$PROFILES_DIR/$profile"
    
    if [ ! -d "$profile_dir" ]; then
        echo "Profile '$profile' not found"
        exit 1
    fi
    
    # Backup current configuration
    backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$HOME/.config" "$backup_dir/"
    
    # Apply profile configuration
    rsync -av "$profile_dir/" "$HOME/.config/"
    
    # Update current profile marker
    echo "$profile" > "$CURRENT_PROFILE"
    
    # Restart Hyprland
    hyprctl reload
    
    echo "Switched to profile: $profile"
}

list_profiles() {
    echo "Available profiles:"
    ls -1 "$PROFILES_DIR" | sed 's/^/  /'
}

case "$1" in
    switch)
        switch_profile "$2"
        ;;
    list)
        list_profiles
        ;;
    *)
        echo "Usage: $0 {switch|list} [profile_name]"
        exit 1
        ;;
esac