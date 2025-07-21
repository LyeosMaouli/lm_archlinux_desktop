#!/bin/bash
# Package Manager Tool
# Unified interface for pacman and AUR package management

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AUR_HELPER="${AUR_HELPER:-yay}"
LOG_FILE="/var/log/package-manager.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running as root for system operations
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run package operations as root (except for system maintenance)"
        exit 1
    fi
}

# Check if AUR helper is available
check_aur_helper() {
    if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        print_warning "AUR helper '$AUR_HELPER' not found. Installing yay..."
        install_yay
    fi
}

# Install yay AUR helper
install_yay() {
    if command -v yay >/dev/null 2>&1; then
        print_info "yay is already installed"
        return 0
    fi
    
    print_info "Installing yay AUR helper..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        sudo pacman -S --noconfirm git
    fi
    
    # Install base development tools
    sudo pacman -S --needed --noconfirm base-devel
    
    # Clone and build yay
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    print_success "yay installed successfully"
}

# Update system
update_system() {
    print_info "Starting system update..."
    log "System update initiated"
    
    # Update pacman packages
    print_info "Updating official packages..."
    sudo pacman -Syu --noconfirm
    
    # Update AUR packages if helper is available
    if command -v "$AUR_HELPER" >/dev/null 2>&1; then
        print_info "Updating AUR packages..."
        $AUR_HELPER -Sua --noconfirm
    fi
    
    print_success "System update completed"
    log "System update completed successfully"
}

# Install packages
install_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]:-0} -eq 0 ]]; then
        print_error "No packages specified"
        return 1
    fi
    
    print_info "Installing packages: ${packages[*]}"
    log "Installing packages: ${packages[*]}"
    
    # Try official repos first
    official_packages=()
    aur_packages=()
    
    for package in "${packages[@]}"; do
        if pacman -Si "$package" >/dev/null 2>&1; then
            official_packages+=("$package")
        else
            aur_packages+=("$package")
        fi
    done
    
    # Install official packages
    if [[ ${#official_packages[@]:-0} -gt 0 ]]; then
        print_info "Installing from official repositories: ${official_packages[*]}"
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
    fi
    
    # Install AUR packages
    if [[ ${#aur_packages[@]:-0} -gt 0 ]]; then
        check_aur_helper
        print_info "Installing from AUR: ${aur_packages[*]}"
        $AUR_HELPER -S --needed --noconfirm "${aur_packages[@]}"
    fi
    
    print_success "Package installation completed"
    log "Package installation completed: ${packages[*]}"
}

# Remove packages
remove_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]:-0} -eq 0 ]]; then
        print_error "No packages specified"
        return 1
    fi
    
    print_info "Removing packages: ${packages[*]}"
    log "Removing packages: ${packages[*]}"
    
    # Check if packages are installed
    installed_packages=()
    for package in "${packages[@]}"; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            installed_packages+=("$package")
        else
            print_warning "Package '$package' is not installed"
        fi
    done
    
    if [[ ${#installed_packages[@]:-0} -gt 0 ]]; then
        sudo pacman -Rns --noconfirm "${installed_packages[@]}"
        print_success "Package removal completed"
        log "Package removal completed: ${installed_packages[*]}"
    fi
}

# Search packages
search_packages() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        print_error "No search query provided"
        return 1
    fi
    
    print_info "Searching for: $query"
    
    # Search official repositories
    echo -e "\n${BLUE}=== Official Repositories ===${NC}"
    pacman -Ss "$query" | head -20
    
    # Search AUR
    if command -v "$AUR_HELPER" >/dev/null 2>&1; then
        echo -e "\n${BLUE}=== AUR ===${NC}"
        $AUR_HELPER -Ss "$query" | head -20
    fi
}

# List installed packages
list_packages() {
    local filter="${1:-all}"
    
    case "$filter" in
        "explicit")
            print_info "Explicitly installed packages:"
            pacman -Qe
            ;;
        "aur")
            print_info "AUR packages:"
            pacman -Qm
            ;;
        "orphans")
            print_info "Orphaned packages:"
            pacman -Qtdq 2>/dev/null || echo "No orphaned packages found"
            ;;
        "all"|*)
            print_info "All installed packages:"
            pacman -Q
            ;;
    esac
}

# Clean package cache and orphans
clean_system() {
    print_info "Cleaning package cache and orphaned packages..."
    log "System cleanup initiated"
    
    # Clean package cache
    print_info "Cleaning package cache..."
    sudo pacman -Sc --noconfirm
    
    # Remove orphaned packages
    orphans=$(pacman -Qtdq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        print_info "Removing orphaned packages..."
        echo "$orphans" | sudo pacman -Rns --noconfirm -
        print_success "Orphaned packages removed"
    else
        print_info "No orphaned packages found"
    fi
    
    # Clean AUR cache if yay is available
    if command -v yay >/dev/null 2>&1; then
        print_info "Cleaning AUR cache..."
        yay -Sc --noconfirm
    fi
    
    print_success "System cleanup completed"
    log "System cleanup completed"
}

# Check for updates
check_updates() {
    print_info "Checking for available updates..."
    
    # Check official repositories
    if command -v checkupdates >/dev/null 2>&1; then
        official_updates=$(checkupdates 2>/dev/null | wc -l)
        print_info "Official repository updates: $official_updates"
        
        if [[ $official_updates -gt 0 ]]; then
            echo -e "\n${BLUE}=== Official Updates ===${NC}"
            checkupdates 2>/dev/null
        fi
    fi
    
    # Check AUR updates
    if command -v "$AUR_HELPER" >/dev/null 2>&1; then
        print_info "Checking AUR updates..."
        aur_updates=$($AUR_HELPER -Qua 2>/dev/null | wc -l)
        print_info "AUR updates: $aur_updates"
        
        if [[ $aur_updates -gt 0 ]]; then
            echo -e "\n${BLUE}=== AUR Updates ===${NC}"
            $AUR_HELPER -Qua 2>/dev/null
        fi
    fi
}

# Package information
package_info() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        print_error "No package specified"
        return 1
    fi
    
    # Check if installed
    if pacman -Q "$package" >/dev/null 2>&1; then
        print_info "Package '$package' is installed"
        pacman -Qi "$package"
    else
        print_info "Package '$package' is not installed"
        
        # Try to get info from repositories
        if pacman -Si "$package" >/dev/null 2>&1; then
            pacman -Si "$package"
        elif command -v "$AUR_HELPER" >/dev/null 2>&1; then
            $AUR_HELPER -Si "$package" 2>/dev/null || print_error "Package not found in repositories or AUR"
        else
            print_error "Package not found in repositories"
        fi
    fi
}

# Backup installed packages
backup_packages() {
    local backup_dir="${1:-$HOME/package-backups}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    mkdir -p "$backup_dir"
    
    print_info "Creating package backup in $backup_dir"
    
    # Backup explicit packages
    pacman -Qe > "$backup_dir/explicit-packages-$timestamp.txt"
    
    # Backup AUR packages
    pacman -Qm > "$backup_dir/aur-packages-$timestamp.txt"
    
    # Backup all packages
    pacman -Q > "$backup_dir/all-packages-$timestamp.txt"
    
    print_success "Package lists backed up to $backup_dir"
    log "Package backup created in $backup_dir"
}

# Restore packages from backup
restore_packages() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_info "Restoring packages from $backup_file"
    
    # Read packages and install
    while read -r package _; do
        if [[ -n "$package" && ! "$package" =~ ^# ]]; then
            print_info "Installing $package..."
            install_packages "$package"
        fi
    done < "$backup_file"
    
    print_success "Package restoration completed"
}

# Show help
show_help() {
    cat << 'EOF'
Package Manager Tool - Unified pacman and AUR interface

Usage: package_manager.sh [COMMAND] [OPTIONS]

Commands:
  update                    Update all packages (pacman + AUR)
  install <packages...>     Install packages
  remove <packages...>      Remove packages
  search <query>           Search for packages
  list [all|explicit|aur|orphans]  List installed packages
  clean                    Clean cache and remove orphans
  check                    Check for available updates
  info <package>           Show package information
  backup [directory]       Backup installed package lists
  restore <backup_file>    Restore packages from backup
  install-yay              Install yay AUR helper

Examples:
  ./package_manager.sh update
  ./package_manager.sh install firefox code
  ./package_manager.sh search hyprland
  ./package_manager.sh list aur
  ./package_manager.sh clean
  ./package_manager.sh backup ~/my-packages
  ./package_manager.sh info firefox

Environment Variables:
  AUR_HELPER              AUR helper to use (default: yay)

EOF
}

# Main script logic
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "${1:-}" in
        "update")
            check_root
            update_system
            ;;
        "install")
            check_root
            shift
            install_packages "$@"
            ;;
        "remove")
            shift
            remove_packages "$@"
            ;;
        "search")
            search_packages "${2:-}"
            ;;
        "list")
            list_packages "${2:-all}"
            ;;
        "clean")
            clean_system
            ;;
        "check")
            check_updates
            ;;
        "info")
            package_info "${2:-}"
            ;;
        "backup")
            backup_packages "${2:-}"
            ;;
        "restore")
            restore_packages "${2:-}"
            ;;
        "install-yay")
            install_yay
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"