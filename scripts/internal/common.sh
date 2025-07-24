#!/bin/bash
#
# common.sh - Shared functions for Arch Linux Desktop Automation
# 
# This file provides standardized functions used across all scripts in the
# automation system. It includes logging, error handling, user interaction,
# validation, and utility functions.
#

# Global configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly LOG_DIR="$PROJECT_ROOT/logs"
readonly CONFIG_DIR="$PROJECT_ROOT/config"

# Initialize logging
mkdir -p "$LOG_DIR"
readonly LOG_FILE="$LOG_DIR/deployment-$(date +%Y%m%d_%H%M%S).log"

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_ERROR=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

# Default log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}

# Exit codes (standardized across all scripts)
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NETWORK_ERROR=10
readonly EXIT_PERMISSION_ERROR=11
readonly EXIT_DEPENDENCY_ERROR=12
readonly EXIT_CONFIG_ERROR=13
readonly EXIT_INSTALL_ERROR=20
readonly EXIT_VALIDATION_ERROR=21

#
# Logging Functions
#

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Internal logging function
_log() {
    local level=$1
    local color=$2
    local prefix=$3
    shift 3
    local message="$*"
    
    if [[ $level -le $LOG_LEVEL ]]; then
        local timestamp
        timestamp=$(get_timestamp)
        if [[ -t 1 ]]; then
            # Terminal output with colors
            echo -e "${color}[${timestamp}] ${prefix}: ${message}${NC}" >&2
        else
            # Non-terminal output without colors
            echo "[${timestamp}] ${prefix}: ${message}" >&2
        fi
        
        # Also log to timestamped file
        echo "[${timestamp}] ${prefix}: ${message}" >> "$LOG_FILE"
    fi
}

# Log error message
log_error() {
    _log $LOG_ERROR "$RED" "ERROR" "$@"
}

# Log warning message
log_warn() {
    _log $LOG_WARN "$YELLOW" "WARN" "$@"
}

# Log info message
log_info() {
    _log $LOG_INFO "$GREEN" "INFO" "$@"
}

# Log debug message
log_debug() {
    _log $LOG_DEBUG "$CYAN" "DEBUG" "$@"
}

# Function to log to both console and file (compatible with USB deployment script)
log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Log success message (compatible with USB deployment script)
log_success() {
    _log $LOG_INFO "$GREEN" "SUCCESS" "$@"
}

#
# Progress and Status Functions
#

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local description=${3:-"Processing"}
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}%s: [" "$description"
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%%${NC}" $percentage
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Show spinner for long operations
show_spinner() {
    local pid=$1
    local message=${2:-"Working"}
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${YELLOW}%s... %c${NC}" "$message" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%*s\r" $((${#message} + 10)) ""
}

#
# User Interaction Functions
#

# Secure user input (hides input for passwords)
prompt_user() {
    local prompt="$1"
    local secure=${2:-false}
    local default_value="$3"
    local response
    
    if [[ "$secure" == "true" ]]; then
        echo -n "$prompt: "
        read -rs response
        echo
    else
        if [[ -n "${default_value:-}" ]]; then
            read -r -p "$prompt [$default_value]: " response
            response=${response:-$default_value}
        else
            read -r -p "$prompt: " response
        fi
    fi
    
    echo "$response"
}

# Yes/no confirmation
confirm() {
    local prompt="$1"
    local default=${2:-"n"}
    local response
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -r -p "$prompt [Y/n]: " response
            response=${response:-y}
        else
            read -r -p "$prompt [y/N]: " response
            response=${response:-n}
        fi
        
        case $response in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

#
# Validation Functions
#

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Require root privileges
require_root() {
    if ! check_root; then
        log_error "This script must be run as root (use sudo)"
        exit $EXIT_PERMISSION_ERROR
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate dependencies
validate_deps() {
    local deps=("$@")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "Missing required dependencies: ${missing_deps[*]}"
        
        # Try to install missing dependencies automatically
        if install_missing_deps "${missing_deps[@]}"; then
            log_success "Successfully installed missing dependencies"
            return 0
        else
            log_error "Failed to install dependencies: ${missing_deps[*]}"
            log_info "Please install the missing dependencies manually and try again"
            return $EXIT_DEPENDENCY_ERROR
        fi
    fi
    
    return 0
}

# Install missing dependencies with enhanced error handling
install_missing_deps() {
    local deps=("$@")
    local packages_to_install=()
    local max_retries=3
    local retry_delay=2
    
    log_info "Attempting to install missing dependencies: ${deps[*]}"
    
    # Enhanced command-to-package mapping
    for dep in "${deps[@]}"; do
        case "$dep" in
            "ansible-playbook")
                packages_to_install+=("ansible")
                ;;
            "mkfs.ext4")
                packages_to_install+=("e2fsprogs")
                ;;
            "cryptsetup")
                packages_to_install+=("cryptsetup")
                ;;
            "parted")
                packages_to_install+=("parted")
                ;;
            "git")
                packages_to_install+=("git")
                ;;
            "curl")
                packages_to_install+=("curl")
                ;;
            *)
                # For unknown commands, assume package name matches command name
                packages_to_install+=("$dep")
                ;;
        esac
    done
    
    # Check if we can install packages (need pacman and sudo)
    if ! command_exists "pacman"; then
        log_error "pacman not found - cannot install dependencies automatically"
        log_info "Please install pacman or run this script on an Arch Linux system"
        return 1
    fi
    
    if ! command_exists "sudo"; then
        log_error "sudo not found - cannot install dependencies automatically"
        log_info "Please install sudo or run as root: su -c './deploy.sh [args]'"
        return 1
    fi
    
    # Update package database first
    log_info "Updating package database..."
    if ! sudo pacman -Sy --noconfirm 2>/dev/null; then
        log_warn "Failed to update package database - proceeding with installation anyway"
    fi
    
    # Remove duplicates from packages list
    local unique_packages=($(printf '%s\n' "${packages_to_install[@]}" | sort -u))
    
    # Try installation with retry logic
    local attempt=1
    local install_success=false
    
    while [[ $attempt -le $max_retries ]]; do
        log_info "Installation attempt $attempt/$max_retries - Installing packages: ${unique_packages[*]}"
        
        # Capture both stdout and stderr for better error diagnosis
        local pacman_output
        pacman_output=$(sudo pacman -S --needed --noconfirm "${unique_packages[@]}" 2>&1)
        local pacman_exit_code=$?
        
        if [[ $pacman_exit_code -eq 0 ]]; then
            log_success "Package installation completed successfully"
            install_success=true
            break
        else
            log_warn "Package installation failed (attempt $attempt/$max_retries)"
            log_debug "Pacman output: $pacman_output"
            
            # Analyze common error patterns and provide specific guidance
            if echo "$pacman_output" | grep -q "target not found"; then
                log_error "Some packages were not found in repositories"
                log_info "This might be due to:"
                log_info "  - Outdated package database (try: sudo pacman -Sy)"
                log_info "  - Package name mismatch"
                log_info "  - Package moved to AUR"
            elif echo "$pacman_output" | grep -q "conflicting dependencies"; then
                log_error "Package conflicts detected"
                log_info "Manual intervention may be required to resolve conflicts"
            elif echo "$pacman_output" | grep -q "failed to synchronize"; then
                log_error "Network connectivity issues detected"
                log_info "Please check your internet connection and try again"
            fi
            
            if [[ $attempt -lt $max_retries ]]; then
                log_info "Retrying in ${retry_delay} seconds..."
                sleep $retry_delay
                retry_delay=$((retry_delay * 2))  # Exponential backoff
            fi
        fi
        
        ((attempt++))
    done
    
    if [[ "$install_success" != "true" ]]; then
        log_error "Failed to install packages after $max_retries attempts"
        log_error "Last pacman output:"
        echo "$pacman_output" | while IFS= read -r line; do
            log_error "  $line"
        done
        
        # Provide manual installation instructions
        log_info ""
        log_info "Manual installation required:"
        log_info "Please run the following commands manually:"
        log_info "  sudo pacman -Sy  # Update package database"
        log_info "  sudo pacman -S ${unique_packages[*]}"
        log_info ""
        log_info "If packages are not found, they might be available in AUR:"
        for pkg in "${unique_packages[@]}"; do
            log_info "  yay -S $pkg  # or use your preferred AUR helper"
        done
        
        return 1
    fi
    
    # Verify installation success by checking if commands are now available
    log_info "Verifying installation..."
    local failed_deps=()
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            failed_deps+=("$dep")
        fi
    done
    
    if [[ ${#failed_deps[@]} -eq 0 ]]; then
        log_success "All dependencies successfully installed and verified"
        return 0
    else
        log_error "Some dependencies still missing after installation: ${failed_deps[*]}"
        log_info "This could indicate:"
        log_info "  - Package was installed but provides a different command name"
        log_info "  - Package installation succeeded but PATH needs updating"
        log_info "  - Additional configuration required"
        
        # Try to find installed packages that might provide the missing commands
        for failed_dep in "${failed_deps[@]}"; do
            log_info "Searching for package that provides '$failed_dep'..."
            if command_exists "pkgfile"; then
                local providing_pkg
                providing_pkg=$(pkgfile -q "$failed_dep" 2>/dev/null | head -1)
                if [[ -n "$providing_pkg" ]]; then
                    log_info "  Command '$failed_dep' might be provided by package: $providing_pkg"
                fi
            fi
        done
        
        return 1
    fi
}

# Check network connectivity
check_network() {
    local test_url=${1:-"8.8.8.8"}
    local timeout=${2:-5}
    
    if ping -c 1 -W "$timeout" "$test_url" >/dev/null 2>&1; then
        return 0
    else
        return $EXIT_NETWORK_ERROR
    fi
}

# Check if system is Arch Linux
check_arch_linux() {
    if [[ -f /etc/os-release ]]; then
        if grep -q "ID=arch" /etc/os-release; then
            return 0
        fi
    fi
    return 1
}

# Check if running in live environment
check_live_environment() {
    if [[ -d /run/archiso ]]; then
        return 0
    else
        return 1
    fi
}

#
# File and Path Functions
#

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    local permissions=${2:-755}
    
    if [[ ! -d "$dir" ]]; then
        if ! mkdir -p "$dir" && chmod "$permissions" "$dir"; then
            log_error "Failed to create directory: $dir"
            return 1
        fi
        log_debug "Created directory: $dir"
    fi
    return 0
}

# Backup file before modification
backup_file() {
    local file="$1"
    local backup_suffix=${2:-".backup.$(date +%Y%m%d_%H%M%S)"}
    
    if [[ -f "$file" ]]; then
        local backup_file="${file}${backup_suffix}"
        if cp "$file" "$backup_file"; then
            log_debug "Backed up $file to $backup_file"
            return 0
        else
            log_error "Failed to backup $file"
            return 1
        fi
    fi
    return 0
}

# Safe file write (atomic operation)
safe_write_file() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"
    
    if echo "$content" > "$temp_file" && mv "$temp_file" "$file"; then
        log_debug "Successfully wrote to $file"
        return 0
    else
        log_error "Failed to write to $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

#
# Configuration Management
#

# Load configuration file
load_config() {
    local config_file="${1:-$CONFIG_DIR/deploy.conf}"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
        return 0
    else
        log_warn "Configuration file not found: $config_file"
        return 1
    fi
}

# Get config value with default
get_config() {
    local key="$1"
    local default_value="$2"
    local config_file="${3:-$CONFIG_DIR/deploy.conf}"
    
    if [[ -f "$config_file" ]]; then
        local value
        value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2- | tr -d '"'"'" 2>/dev/null)
        echo "${value:-$default_value}"
    else
        echo "$default_value"
    fi
}

#
# Error Handling and Cleanup
#

# Cleanup function (called on exit)
cleanup() {
    local exit_code=$?
    log_debug "Cleanup function called with exit code: $exit_code"
    
    # Remove temporary files
    find /tmp -name "arch_deploy_*" -user "$(id -u)" -delete 2>/dev/null || true
    
    # Restore terminal settings
    stty sane 2>/dev/null || true
    
    return $exit_code
}

# Set up signal handlers
setup_signal_handlers() {
    trap cleanup EXIT
    trap 'log_error "Script interrupted by user"; exit $EXIT_GENERAL_ERROR' INT TERM
}

# Error handler for critical errors
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Critical error occurred at line $line_number (exit code: $exit_code)"
    log_error "Call stack:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done
    
    cleanup
    exit $exit_code
}

# Enable error handling
enable_error_handling() {
    set -eE
    trap 'handle_error $LINENO' ERR
    setup_signal_handlers
}

#
# Hardware Detection
#

# Detect CPU vendor
detect_cpu_vendor() {
    if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        echo "intel"
    elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Detect GPU vendor
detect_gpu_vendor() {
    if lspci | grep -i vga | grep -qi intel; then
        echo "intel"
    elif lspci | grep -i vga | grep -qi nvidia; then
        echo "nvidia"
    elif lspci | grep -i vga | grep -qi amd; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Check if system is a laptop
is_laptop() {
    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        return 0
    else
        return 1
    fi
}

#
# System Information
#

# Get system information
get_system_info() {
    echo "System Information:"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  CPU: $(detect_cpu_vendor)"
    echo "  GPU: $(detect_gpu_vendor)"
    echo "  Laptop: $(is_laptop && echo "Yes" || echo "No")"
    echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $2}')"
}

#
# Initialization
#

# Initialize logging directory
init_logging() {
    ensure_dir "$LOG_DIR" 755
    
    # Rotate logs if they get too large (>10MB)
    local log_file="$LOG_DIR/deployment.log"
    if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 10485760 ]]; then
        mv "$log_file" "${log_file}.old"
        log_info "Rotated log file"
    fi
}

# Initialize common functions
init_common() {
    # Set up logging
    init_logging
    
    # Enable error handling if not in debug mode
    if [[ "${DEBUG:-false}" != "true" ]]; then
        enable_error_handling
    fi
    
    # Set default umask for security
    umask 022
    
    log_debug "Common functions initialized"
}

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_common
fi