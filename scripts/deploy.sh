#!/bin/bash
#
# deploy.sh - Unified Deployment Script for Arch Linux Desktop Automation
#
# This script consolidates all deployment functionality into a single entry point
# with subcommands for different installation phases and deployment modes.
#
# Usage: ./deploy.sh [COMMAND] [OPTIONS]
#
# Commands:
#   install     Base system installation (replaces auto_install.sh)
#   desktop     Desktop environment setup (replaces auto_deploy.sh)
#   security    Security hardening (replaces security scripts)
#   full        Complete end-to-end deployment (replaces zero_touch_deploy.sh)
#   help        Show detailed help
#
# Options:
#   --profile PROFILE      Deployment profile: work|personal|development
#   --password MODE        Password mode: env|file|generate|interactive
#   --password-file FILE   Path to encrypted password file (for file mode)
#   --network MODE         Network mode: auto|manual|skip
#   --encryption           Enable disk encryption
#   --no-encryption        Disable disk encryption
#   --hostname HOSTNAME    System hostname
#   --user USERNAME        Primary username
#   --config FILE          Custom configuration file
#   --dry-run              Show what would be done without executing
#   --verbose              Enable verbose output
#   --quiet                Suppress non-essential output
#   --help, -h             Show help
#

# Security: Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Set secure umask
umask 077

# Try to load common functions - handle different deployment scenarios
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Try multiple paths for common.sh
COMMON_PATHS=(
    "$SCRIPT_DIR/internal/common.sh"           # When in scripts/ directory
    "$SCRIPT_DIR/../scripts/internal/common.sh" # When in project root
    "$SCRIPT_DIR/scripts/internal/common.sh"   # When in project root (alternative)
)

COMMON_LOADED=false
for COMMON_PATH in "${COMMON_PATHS[@]}"; do
    if [[ -f "$COMMON_PATH" ]]; then
        # shellcheck source=internal/common.sh
        source "$COMMON_PATH" && COMMON_LOADED=true && break
    fi
done

if [[ "${COMMON_LOADED:-}" != "true" ]]; then
    echo "Warning: Cannot load common.sh, using basic logging"
    
    # Basic logging functions as fallback
    if [[ -z "${LOG_DIR:-}" ]]; then
        LOG_DIR="$(pwd)/logs"
    fi
    mkdir -p "$LOG_DIR"
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="$LOG_DIR/deployment-$(date +%Y%m%d_%H%M%S).log"
    fi
    
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "$LOG_FILE"; }
    log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" | tee -a "$LOG_FILE"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE"; }
    log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" | tee -a "$LOG_FILE"; }
    log_to_file() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }
fi

#
# Enhanced UI Components and Terminal Functions  
#

# Enhanced color codes and UI components (extend from common.sh)
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly REVERSE='\033[7m'

# UI symbols for better visual feedback
readonly CHECKMARK='✓'
readonly CROSSMARK='✗'
readonly ARROW='→'
readonly BULLET='•'
readonly SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
readonly BOX_CHARS='┌─┐│└─┘├┤┬┴┼'

# Terminal capabilities detection
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
TERM_COLORS=$(tput colors 2>/dev/null || echo 8)

# Enhanced UI functions
draw_box() {
    local width=${1:-60}
    local title="$2"
    local content="$3"
    
    # Use fallback characters if Unicode not supported
    local tl="┌" tr="┐" bl="└" br="┘" h="─" v="│" 
    local cross="├" rcross="┤"
    
    if [[ $TERM_COLORS -lt 8 ]]; then
        tl="+" tr="+" bl="+" br="+" h="-" v="|" cross="+" rcross="+"
    fi
    
    # Top border
    echo -ne "${BLUE}$tl"
    printf "${h}%.0s" $(seq 1 $((width - 2)))
    echo "$tr${NC}"
    
    # Title
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local padding=$(( (width - title_len - 4) / 2 ))
        echo -ne "${BLUE}$v${NC}"
        printf " %.0s" $(seq 1 $padding)
        echo -ne "${BOLD}$title${NC}"
        printf " %.0s" $(seq 1 $((width - title_len - padding - 3)))
        echo -e "${BLUE}$v${NC}"
        
        # Separator
        echo -ne "${BLUE}$cross"
        printf "${h}%.0s" $(seq 1 $((width - 2)))
        echo "$rcross${NC}"
    fi
    
    # Content
    if [[ -n "$content" ]]; then
        echo "$content" | while IFS= read -r line; do
            # Strip color codes for length calculation
            local line_clean=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
            local line_len=${#line_clean}
            echo -ne "${BLUE}$v${NC} "
            echo -ne "$line"
            printf " %.0s" $(seq 1 $((width - line_len - 4)))
            echo -e " ${BLUE}$v${NC}"
        done
    fi
    
    # Bottom border
    echo -ne "${BLUE}$bl"
    printf "${h}%.0s" $(seq 1 $((width - 2)))
    echo "$br${NC}"
}

show_banner() {
    local version="$1"
    local width=70
    
    clear
    echo
    draw_box $width "Arch Linux Desktop Automation v$version" "
${DIM}Enterprise-grade desktop automation system${NC}
${DIM}Built with Ansible and modern security practices${NC}

${GREEN}${CHECKMARK}${NC} Hyprland Wayland Desktop
${GREEN}${CHECKMARK}${NC} Security Hardening  
${GREEN}${CHECKMARK}${NC} Profile-based Configuration
${GREEN}${CHECKMARK}${NC} Multiple Deployment Modes"
    echo
}

# Enhanced progress indicator
show_enhanced_progress() {
    local current=$1
    local total=$2
    local description=${3:-"Processing"}
    local width=40
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Use different characters for filled/empty parts
    printf "\r${BOLD}%s:${NC} [${GREEN}" "$description"
    printf "█%.0s" $(seq 1 $filled)
    printf "${DIM}░%.0s" $(seq 1 $empty)
    printf "${NC}] ${CYAN}%d%%${NC} (${YELLOW}%d${NC}/${YELLOW}%d${NC})" $percentage $current $total
    
    if [[ $current -eq $total ]]; then
        echo -e " ${GREEN}${CHECKMARK} Complete${NC}"
    fi
}

# Enhanced spinner with custom message
show_enhanced_spinner() {
    local pid=$1
    local message=${2:-"Working"}
    local delay=0.1
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        local char=${chars:$((i % ${#chars})):1}
        printf "\r${CYAN}%s${NC} %s..." "$char" "$message"
        sleep $delay
        i=$((i + 1))
    done
    printf "\r%*s\r" $((${#message} + 10)) ""
}

# Interactive menu system
show_interactive_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    
    while true; do
        clear
        echo
        draw_box 60 "$title" ""
        echo
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${REVERSE} ${ARROW} ${options[$i]} ${NC}"
            else
                echo -e "      ${options[$i]}"
            fi
        done
        
        echo
        echo -e "${DIM}Use arrow keys to navigate, Enter to select, 'q' to quit${NC}"
        
        # Read single character
        read -rsn1 key
        case "$key" in
            $'\x1b')  # Escape sequence
                read -rsn2 key
                case "$key" in
                    '[A') ((selected > 0)) && ((selected--)) ;;  # Up
                    '[B') ((selected < ${#options[@]} - 1)) && ((selected++)) ;;  # Down
                esac
                ;;
            '') return $selected ;;  # Enter
            'q'|'Q') return 255 ;;   # Quit
        esac
    done
}

# Enhanced confirmation with better UI
enhanced_confirm() {
    local prompt="$1"
    local default=${2:-"n"}
    local response
    
    while true; do
        echo
        if [[ "$default" == "y" ]]; then
            echo -ne "${YELLOW}${BULLET}${NC} $prompt ${GREEN}[Y/n]${NC}: "
            read -r response
            response=${response:-y}
        else
            echo -ne "${YELLOW}${BULLET}${NC} $prompt ${RED}[y/N]${NC}: "
            read -r response
            response=${response:-n}
        fi
        
        case $response in
            [Yy]|[Yy][Ee][Ss]) 
                echo -e "  ${GREEN}${CHECKMARK} Confirmed${NC}"
                return 0 
                ;;
            [Nn]|[Nn][Oo]) 
                echo -e "  ${RED}${CROSSMARK} Cancelled${NC}"
                return 1 
                ;;
            *) 
                echo -e "  ${RED}${CROSSMARK} Please answer yes or no.${NC}" 
                ;;
        esac
    done
}

# Enhanced error display
show_error_box() {
    local error_msg="$1"
    local details="$2"
    
    echo
    draw_box 70 "${RED}Error${NC}" "${RED}${CROSSMARK} $error_msg${NC}

${details:+${DIM}$details${NC}}"
    echo
}

# Enhanced success display  
show_success_box() {
    local success_msg="$1"
    local details="$2"
    
    echo
    draw_box 70 "${GREEN}Success${NC}" "${GREEN}${CHECKMARK} $success_msg${NC}

${details:+${DIM}$details${NC}}"
    echo
}

# Script metadata
readonly SCRIPT_NAME="deploy.sh"
readonly SCRIPT_VERSION="2.0.0"

# Default configuration
DEFAULT_PROFILE="work"
DEFAULT_PASSWORD_MODE="generate"
DEFAULT_NETWORK_MODE="auto"
DEFAULT_HOSTNAME="phoenix"
DEFAULT_USER="lyeosmaouli"
DEFAULT_ENCRYPTION="true"

# Project structure
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
if [[ -z "${CONFIG_DIR:-}" ]]; then
    CONFIG_DIR="$PROJECT_ROOT/config"
fi

# Configuration variables (can be overridden by CLI or config file)
PROFILE="$DEFAULT_PROFILE"
PASSWORD_MODE="$DEFAULT_PASSWORD_MODE"
PASSWORD_FILE=""
NETWORK_MODE="$DEFAULT_NETWORK_MODE"
HOSTNAME="$DEFAULT_HOSTNAME"
USER_NAME="$DEFAULT_USER"
ENCRYPTION_ENABLED="$DEFAULT_ENCRYPTION"
CONFIG_FILE=""
DRY_RUN=false
COMMAND=""

# Performance configuration
ENABLE_PARALLEL_PROCESSING=${ENABLE_PARALLEL_PROCESSING:-true}
ENABLE_SMART_CACHING=${ENABLE_SMART_CACHING:-true}
CACHE_CLEANUP=${CACHE_CLEANUP:-false}
PERFORMANCE_MODE=${PERFORMANCE_MODE:-auto}  # auto, fast, safe

#
# Performance Optimization Functions
#

# Smart caching for deployment phases
enable_deployment_caching() {
    if [[ "$ENABLE_SMART_CACHING" == "true" ]]; then
        export ENABLE_CACHING=true
        export ANSIBLE_CACHE_PLUGIN=memory
        export ANSIBLE_CACHE_PLUGIN_CONNECTION=/tmp/ansible_cache_$$
        log_info "Smart caching enabled for deployment"
    fi
}

# Optimize Ansible performance
optimize_ansible_performance() {
    if [[ "$ENABLE_PARALLEL_PROCESSING" == "true" ]]; then
        # Set Ansible performance options
        export ANSIBLE_HOST_KEY_CHECKING=False
        export ANSIBLE_SSH_PIPELINING=True
        export ANSIBLE_SSH_MULTIPLEXING=True
        export ANSIBLE_FORKS=${PARALLEL_JOBS:-4}
        
        # Create SSH control master directory
        mkdir -p ~/.ssh/controlmasters
        
        log_info "Ansible performance optimizations enabled (forks: ${ANSIBLE_FORKS})"
    fi
}

# Pre-flight performance checks
check_performance_prerequisites() {
    log_info "Checking performance prerequisites..."
    
    # Check available memory
    local available_mem
    available_mem=$(free -m | awk '/^Mem:/{print $7}')
    
    if [[ $available_mem -lt 1024 ]]; then
        log_warn "Low available memory: ${available_mem}MB"
        log_warn "Consider reducing parallel jobs or enabling swap"
        
        # Automatically reduce parallel jobs if memory is low
        if [[ $PARALLEL_JOBS -gt 2 ]]; then
            PARALLEL_JOBS=2
            log_info "Reduced parallel jobs to 2 due to low memory"
        fi
    fi
    
    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo 1)
    
    if [[ $PARALLEL_JOBS -gt $cpu_cores ]]; then
        log_warn "Parallel jobs ($PARALLEL_JOBS) exceed CPU cores ($cpu_cores)"
        log_info "This may cause context switching overhead"
    fi
    
    # Check disk space
    local available_space
    available_space=$(df /tmp | tail -1 | awk '{print $4}')
    
    if [[ $available_space -lt 1048576 ]]; then  # Less than 1GB
        log_warn "Low disk space in /tmp: ${available_space}KB"
        log_warn "Consider cleaning up or disabling caching"
        
        if [[ "$ENABLE_SMART_CACHING" == "true" ]]; then
            log_info "Disabling caching due to low disk space"
            ENABLE_SMART_CACHING=false
        fi
    fi
    
    log_info "Performance prerequisites check completed"
}

# Clean up performance artifacts
cleanup_performance_artifacts() {
    if [[ "$CACHE_CLEANUP" == "true" ]]; then
        log_info "Cleaning up performance artifacts..."
        
        # Clean Ansible cache
        rm -rf /tmp/ansible_cache_* 2>/dev/null || true
        
        # Clean SSH control masters
        rm -rf ~/.ssh/controlmasters/* 2>/dev/null || true
        
        # Clean deployment cache if function exists
        if command -v clear_cache >/dev/null 2>&1; then
            clear_cache functions
        fi
        
        log_info "Performance cleanup completed"
    fi
}

#
# Help and Usage Functions
#

show_usage() {
    draw_box 80 "Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]" "
${BOLD}COMMANDS:${NC}
  ${GREEN}install${NC}     Install base Arch Linux system
  ${GREEN}desktop${NC}     Set up Hyprland desktop environment  
  ${GREEN}security${NC}    Apply security hardening
  ${GREEN}full${NC}        Complete end-to-end deployment
  ${GREEN}help${NC}        Show detailed help and examples

${BOLD}OPTIONS:${NC}
  ${YELLOW}--profile${NC} PROFILE         Deployment profile (work|personal|development)
  ${YELLOW}--password${NC} MODE           Password handling (env|file|generate|interactive)
  ${YELLOW}--password-file${NC} FILE      Encrypted password file path
  ${YELLOW}--network${NC} MODE            Network setup (auto|manual|skip)
  ${YELLOW}--encryption${NC}              Enable disk encryption (default)
  ${YELLOW}--no-encryption${NC}           Disable disk encryption
  ${YELLOW}--hostname${NC} HOSTNAME       System hostname (default: phoenix)
  ${YELLOW}--user${NC} USERNAME           Primary user (default: lyeosmaouli)
  ${YELLOW}--config${NC} FILE             Custom configuration file
  ${YELLOW}--dry-run${NC}                 Preview actions without executing  
  ${YELLOW}--verbose${NC}, -v             Enable verbose output
  ${YELLOW}--quiet${NC}, -q               Suppress non-essential output
  ${YELLOW}--parallel${NC}                Enable parallel processing (default)
  ${YELLOW}--no-parallel${NC}             Disable parallel processing
  ${YELLOW}--cache${NC}                   Enable smart caching (default)
  ${YELLOW}--no-cache${NC}                Disable caching
  ${YELLOW}--performance${NC} MODE        Performance mode (auto|fast|safe)
  ${YELLOW}--cleanup${NC}                 Clean up cache after deployment
  ${YELLOW}--help${NC}, -h                Show this help

${BOLD}EXAMPLES:${NC}
  ${CYAN}$SCRIPT_NAME full${NC}
      Complete automated deployment
  
  ${CYAN}$SCRIPT_NAME full --profile personal --hostname myarch${NC}
      Custom deployment with options
  
  ${CYAN}$SCRIPT_NAME install --encryption${NC}
      Step 1: Base system installation
  
  ${CYAN}$SCRIPT_NAME full --dry-run --verbose${NC}
      Preview actions without executing"
}

show_detailed_help() {
    show_usage
    cat << EOF

DETAILED COMMAND DESCRIPTIONS:

  install
    Installs the base Arch Linux system including:
    - Disk partitioning and formatting
    - Base package installation
    - Bootloader configuration (systemd-boot)
    - User account creation
    - Basic system configuration

  desktop
    Sets up the Hyprland desktop environment including:
    - Wayland compositor and utilities
    - Audio system (PipeWire)
    - Applications and themes
    - Desktop configuration files
    - AUR package management

  security
    Applies comprehensive security hardening:
    - Firewall configuration (UFW)
    - Intrusion prevention (fail2ban)
    - System auditing and logging
    - SSH hardening
    - Kernel parameter tuning

  full
    Executes all deployment phases in sequence:
    install -> desktop -> security
    This is the recommended approach for new installations.

CONFIGURATION:

  Profiles determine which packages and configurations are applied:
  - work:        Business applications, security focus
  - personal:    Media applications, gaming support
  - development: Development tools, programming environments

  Password modes determine how user passwords are handled:
  - env:         Read from DEPLOY_USER_PASSWORD environment variable
  - file:        Decrypt from encrypted password file
  - generate:    Auto-generate secure passwords
  - interactive: Prompt user for passwords

CONFIGURATION FILE:

  Create $CONFIG_DIR/deploy.conf to set defaults:

    USER_NAME="myuser"
    HOSTNAME="myhost"
    PROFILE="personal"
    PASSWORD_MODE="generate"
    ENCRYPTION_ENABLED=true
    NETWORK_MODE="auto"
    LOG_LEVEL=3

ENVIRONMENT VARIABLES:

  DEPLOY_USER_PASSWORD    User password (for password mode 'env')
  LOG_LEVEL              Logging verbosity (1=error, 2=warn, 3=info, 4=debug)
  DEBUG                  Enable debug mode (true/false)

SECURITY CONSIDERATIONS:

  - All passwords are handled securely with no plaintext storage
  - Encrypted password files use AES-256 with PBKDF2 key derivation
  - Generated passwords are cryptographically secure (32+ characters)
  - Interactive mode uses hidden input and secure prompting
  - All operations are logged for audit purposes

For more information, see the documentation in $PROJECT_ROOT/docs/

EOF
}

#
# Configuration and Argument Parsing
#

load_configuration() {
    # Load from config file if it exists
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        if ! load_config "$CONFIG_FILE"; then
            show_error_box "Configuration Error" "Failed to load configuration file: $CONFIG_FILE"
            exit $EXIT_CONFIG_ERROR
        fi
    else
        # Try multiple paths for default config file
        local config_paths=(
            "$CONFIG_DIR/deploy.conf"                    # Standard project structure
            "$PROJECT_ROOT/config/deploy.conf"           # Alternative path
            "$SCRIPT_DIR/../config/deploy.conf"          # When in scripts directory
            "$SCRIPT_DIR/../../config/deploy.conf"       # When in scripts/internal
        )
        
        local config_loaded=false
        for config_path in "${config_paths[@]}"; do
            if [[ -f "$config_path" ]]; then
                log_info "Loading configuration from: $config_path"
                if load_config "$config_path"; then
                    config_loaded=true
                    break
                fi
            fi
        done
        
        if [[ "$config_loaded" != "true" ]]; then
            log_warn "Configuration file not found, using defaults"
            log_info "Searched paths: ${config_paths[*]}"
        fi
    fi
    
    # Override with any values from config (using get_config function if available)
    if command -v get_config >/dev/null 2>&1; then
        PROFILE="${PROFILE:-$(get_config "PROFILE" "$DEFAULT_PROFILE")}"
        PASSWORD_MODE="${PASSWORD_MODE:-$(get_config "PASSWORD_MODE" "$DEFAULT_PASSWORD_MODE")}"
        NETWORK_MODE="${NETWORK_MODE:-$(get_config "NETWORK_MODE" "$DEFAULT_NETWORK_MODE")}"
        HOSTNAME="${HOSTNAME:-$(get_config "HOSTNAME" "$DEFAULT_HOSTNAME")}"
        USER_NAME="${USER_NAME:-$(get_config "USER_NAME" "$DEFAULT_USER")}"
        ENCRYPTION_ENABLED="${ENCRYPTION_ENABLED:-$(get_config "ENCRYPTION_ENABLED" "$DEFAULT_ENCRYPTION")}"
    fi
}

# Auto-detect .enc files and update configuration
auto_detect_enc_files() {
    log_info "Checking for .enc password files in project root..."
    
    # Find .enc files in project root
    local enc_files=()
    while IFS= read -r -d '' enc_file; do
        enc_files+=("$enc_file")
    done < <(find "$PROJECT_ROOT" -maxdepth 1 -name "*.enc" -type f -print0 2>/dev/null)
    
    if [[ ${#enc_files[@]} -eq 0 ]]; then
        log_info "No .enc files found, using current PASSWORD_MODE: $PASSWORD_MODE"
        return 0
    fi
    
    # Found .enc file(s)
    local enc_file="${enc_files[0]}"  # Use the first one found
    local enc_filename=$(basename "$enc_file")
    log_success "Found encrypted password file: $enc_filename"
    
    # Update deploy.conf to use the found .enc file
    local deploy_conf="$CONFIG_DIR/deploy.conf"
    if [[ -f "$deploy_conf" ]]; then
        log_info "Updating deploy.conf to use detected password file..."
        
        # Create a backup
        cp "$deploy_conf" "$deploy_conf.bak.$(date +%s)" 2>/dev/null || true
        
        # Update PASSWORD_MODE and PASSWORD_FILE
        sed -i "s/^PASSWORD_MODE=.*/PASSWORD_MODE=\"file\"/" "$deploy_conf"
        sed -i "s|^PASSWORD_FILE=.*|PASSWORD_FILE=\"$enc_filename\"|" "$deploy_conf"
        
        log_success "Updated deploy.conf:"
        log_info "  PASSWORD_MODE=\"file\""
        log_info "  PASSWORD_FILE=\"$enc_filename\""
        
        # Reload configuration to pick up the changes
        PASSWORD_MODE="file"
        PASSWORD_FILE="$enc_filename"
        
    else
        log_warn "deploy.conf not found, using detected file directly"
        PASSWORD_MODE="file"
        PASSWORD_FILE="$enc_filename"
    fi
}

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo
        show_error_box "Missing Command" "No command specified. Use --help for usage information."
        show_usage
        exit "${EXIT_INVALID_ARGS:-1}"
    fi
    
    # First argument is the command
    COMMAND="${1:-}"
    shift
    
    # Validate command before processing options
    case "$COMMAND" in
        install|desktop|security|full|help) ;;
        "")
            show_error_box "Missing Command" "Command is required"
            show_usage
            exit "${EXIT_INVALID_ARGS:-1}"
            ;;
        *)
            show_error_box "Invalid Command: $COMMAND" "Valid commands: install, desktop, security, full, help"
            show_usage
            exit "${EXIT_INVALID_ARGS:-1}"
            ;;
    esac
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--profile requires a value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                PROFILE="$2"
                shift 2
                ;;
            --password)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--password requires a value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                PASSWORD_MODE="$2"
                shift 2
                ;;
            --password-file)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--password-file requires a file path"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                PASSWORD_FILE="$2"
                shift 2
                ;;
            --network)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--network requires a value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                NETWORK_MODE="$2"
                shift 2
                ;;
            --encryption)
                ENCRYPTION_ENABLED="true"
                shift
                ;;
            --no-encryption)
                ENCRYPTION_ENABLED="false"
                shift
                ;;
            --hostname)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--hostname requires a hostname value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                HOSTNAME="$2"
                shift 2
                ;;
            --user)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--user requires a username value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                USER_NAME="$2"
                shift 2
                ;;
            --config)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--config requires a file path"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                LOG_LEVEL="${LOG_DEBUG:-4}"
                shift
                ;;
            --quiet|-q)
                LOG_LEVEL="${LOG_ERROR:-1}"
                shift
                ;;
            --parallel)
                ENABLE_PARALLEL_PROCESSING=true
                shift
                ;;
            --no-parallel)
                ENABLE_PARALLEL_PROCESSING=false
                shift
                ;;
            --cache)
                ENABLE_SMART_CACHING=true
                shift
                ;;
            --no-cache)
                ENABLE_SMART_CACHING=false
                shift
                ;;
            --performance)
                if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
                    log_error "--performance requires a mode value"
                    exit "${EXIT_INVALID_ARGS:-1}"
                fi
                PERFORMANCE_MODE="$2"
                shift 2
                ;;
            --cleanup)
                CACHE_CLEANUP=true
                shift
                ;;
            --help|-h)
                show_detailed_help
                exit "${EXIT_SUCCESS:-0}"
                ;;
            *)
                show_error_box "Unknown Option: $1" "Use --help for available options"
                show_usage
                exit "${EXIT_INVALID_ARGS:-1}"
                ;;
        esac
    done
}

validate_arguments() {
    # Validate command
    case ${COMMAND:-} in
        install|desktop|security|full|help) ;;
        *)
            log_error "Invalid command: $COMMAND"
            show_usage
            exit $EXIT_INVALID_ARGS
            ;;
    esac
    
    # Validate profile
    case ${PROFILE:-} in
        work|personal|development) ;;
        *)
            log_error "Invalid profile: $PROFILE"
            log_error "Valid profiles: work, personal, development"
            exit $EXIT_INVALID_ARGS
            ;;
    esac
    
    # Validate password mode
    case ${PASSWORD_MODE:-} in
        env|file|generate|interactive) ;;
        *)
            log_error "Invalid password mode: $PASSWORD_MODE"
            log_error "Valid modes: env, file, generate, interactive"
            exit $EXIT_INVALID_ARGS
            ;;
    esac
    
    # Validate network mode
    case ${NETWORK_MODE:-} in
        auto|manual|skip) ;;
        *)
            log_error "Invalid network mode: $NETWORK_MODE"
            log_error "Valid modes: auto, manual, skip"
            exit $EXIT_INVALID_ARGS
            ;;
    esac
    
    # Validate password file if specified
    if [[ "${PASSWORD_MODE:-}" == "file" ]]; then
        if [[ -z "${PASSWORD_FILE:-}" ]]; then
            log_error "Password file required for password mode 'file'"
            log_error "Use --password-file option to specify the file path"
            exit $EXIT_INVALID_ARGS
        fi
        if [[ ! -f "$PASSWORD_FILE" ]]; then
            log_error "Password file not found: $PASSWORD_FILE"
            exit $EXIT_INVALID_ARGS
        fi
    fi
    
    # Validate hostname
    if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}[a-zA-Z0-9]?$ ]]; then
        log_error "Invalid hostname: $HOSTNAME"
        log_error "Hostname must contain only letters, numbers, and hyphens"
        exit $EXIT_INVALID_ARGS
    fi
    
    # Validate username
    if [[ ! "$USER_NAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        log_error "Invalid username: $USER_NAME"
        log_error "Username must start with a letter and contain only lowercase letters, numbers, underscores, and hyphens"
        exit $EXIT_INVALID_ARGS
    fi
}

#
# Pre-flight Checks
#

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running on Arch Linux
    if ! check_arch_linux; then
        log_error "This script must be run on Arch Linux"
        exit $EXIT_VALIDATION_ERROR
    fi
    
    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_error "Unsupported architecture: $arch"
        log_error "This script only supports x86_64 systems"
        exit $EXIT_VALIDATION_ERROR
    fi
    
    # Check UEFI boot mode (skip in development/container environments)
    if [[ -n "${DEVELOPMENT_MODE:-}" ]] || [[ -f /.dockerenv ]]; then
        log_info "Skipping UEFI check (development/container environment detected)"
    elif [[ ! -d /sys/firmware/efi ]]; then
        log_error "UEFI boot mode required"
        log_error "This script requires UEFI boot mode, not legacy BIOS"
        log_error "For development/testing, set DEVELOPMENT_MODE=true to skip this check"
        exit $EXIT_VALIDATION_ERROR
    fi
    
    # For install command, check if we're in live environment
    if [[ "${COMMAND:-}" == "install" ]] || [[ "${COMMAND:-}" == "full" ]]; then
        if ! check_live_environment; then
            log_warn "Not running in live environment - installation commands may fail"
            if ! confirm "Continue anyway?"; then
                log_info "Installation cancelled by user"
                exit $EXIT_SUCCESS
            fi
        fi
    fi
    
    # Check network connectivity if needed
    if [[ "${NETWORK_MODE:-}" != "skip" ]]; then
        log_info "Checking network connectivity..."
        if ! check_network; then
            log_error "Network connectivity test failed"
            if [[ "${NETWORK_MODE:-}" == "auto" ]]; then
                log_error "Auto network mode requires working internet connection"
                exit $EXIT_NETWORK_ERROR
            else
                log_warn "Network issues detected - manual configuration may be required"
            fi
        fi
    fi
    
    log_info "System requirements check completed"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local base_deps=("curl" "git" "ansible-playbook")
    local install_deps=("parted" "mkfs.ext4" "cryptsetup")
    
    case ${COMMAND:-} in
        install|full)
            validate_deps "${base_deps[@]}" "${install_deps[@]}"
            ;;
        desktop|security)
            validate_deps "${base_deps[@]}"
            ;;
    esac
    
    log_info "Dependency check completed"
}

#
# Deployment Functions
#

execute_install_phase() {
    log_info "Starting base system installation..."
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "[DRY RUN] Would execute base system installation with:"
        log_info "  Hostname: $HOSTNAME"
        log_info "  User: $USER_NAME"
        log_info "  Encryption: $ENCRYPTION_ENABLED"
        log_info "  Profile: $PROFILE"
        return 0
    fi
    
    # Call installation utility with our configuration
    local install_args=(
        "--hostname" "$HOSTNAME"
        "--user" "$USER_NAME"
        "--profile" "$PROFILE"
    )
    
    if [[ "${ENCRYPTION_ENABLED:-}" == "true" ]]; then
        install_args+=("--encryption")
    fi
    
    if [[ "${PASSWORD_MODE:-}" != "interactive" ]]; then
        install_args+=("--password-mode" "$PASSWORD_MODE")
    fi
    
    if [[ -n "${PASSWORD_FILE:-}" ]]; then
        install_args+=("--password-file" "$PASSWORD_FILE")
    fi
    
    log_debug "Calling installation with args: ${install_args[*]}"
    
    # For now, call the existing auto_install.sh with translated arguments
    # TODO: Replace with native implementation
    if ! "$SCRIPT_DIR/deployment/auto_install.sh" "${install_args[@]}"; then
        log_error "Base system installation failed"
        return $EXIT_INSTALL_ERROR
    fi
    
    log_info "Base system installation completed successfully"
}

execute_desktop_phase() {
    log_info "Starting desktop environment setup..."
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "[DRY RUN] Would execute desktop setup with:"
        log_info "  Profile: $PROFILE"
        log_info "  Hyprland desktop environment"
        log_info "  Audio: PipeWire"
        log_info "  Applications based on profile"
        return 0
    fi
    
    # Execute Ansible playbook for desktop setup
    local ansible_args=(
        "-i" "$PROJECT_ROOT/configs/ansible/inventory/localhost.yml"
        "$PROJECT_ROOT/configs/ansible/playbooks/desktop.yml"
        "--extra-vars" "profile=$PROFILE"
        "--extra-vars" "user_name=$USER_NAME"
    )
    
    if [[ $LOG_LEVEL -ge $LOG_DEBUG ]]; then
        ansible_args+=("-v")
    fi
    
    log_debug "Calling Ansible with args: ${ansible_args[*]}"
    
    if ! ansible-playbook "${ansible_args[@]}"; then
        log_error "Desktop environment setup failed"
        return $EXIT_INSTALL_ERROR
    fi
    
    log_info "Desktop environment setup completed successfully"
}

execute_security_phase() {
    log_info "Starting security hardening..."
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "[DRY RUN] Would execute security hardening:"
        log_info "  UFW firewall configuration"
        log_info "  fail2ban intrusion prevention"
        log_info "  System audit logging"
        log_info "  SSH hardening"
        log_info "  Kernel parameter tuning"
        return 0
    fi
    
    # Execute Ansible playbook for security hardening
    local ansible_args=(
        "-i" "$PROJECT_ROOT/configs/ansible/inventory/localhost.yml"
        "$PROJECT_ROOT/configs/ansible/playbooks/security.yml"
        "--extra-vars" "user_name=$USER_NAME"
    )
    
    if [[ $LOG_LEVEL -ge $LOG_DEBUG ]]; then
        ansible_args+=("-v")
    fi
    
    log_debug "Calling Ansible with args: ${ansible_args[*]}"
    
    if ! ansible-playbook "${ansible_args[@]}"; then
        log_error "Security hardening failed"
        return $EXIT_INSTALL_ERROR
    fi
    
    log_info "Security hardening completed successfully"
}

execute_full_deployment() {
    log_info "Starting full deployment process..."
    
    local start_time
    start_time=$(date +%s)
    
    # Execute all phases in sequence
    if ! execute_install_phase; then
        log_error "Full deployment failed at installation phase"
        return $EXIT_INSTALL_ERROR
    fi
    
    show_enhanced_progress 1 3 "Full Deployment"
    
    if ! execute_desktop_phase; then
        log_error "Full deployment failed at desktop phase"
        return $EXIT_INSTALL_ERROR
    fi
    
    show_enhanced_progress 2 3 "Full Deployment"
    
    if ! execute_security_phase; then
        log_error "Full deployment failed at security phase"
        return $EXIT_INSTALL_ERROR
    fi
    
    show_enhanced_progress 3 3 "Full Deployment"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_info "Full deployment completed successfully in ${minutes}m${seconds}s"
    
    # Show final success with system information
    show_success_box "Deployment Complete!" "Full deployment completed in ${minutes}m${seconds}s

System Information:
$(get_system_info | sed 's/^/  /')"
    
    draw_box 60 "Next Steps" "
${GREEN}1.${NC} Reboot the system: ${CYAN}sudo reboot${NC}
${GREEN}2.${NC} Log in with user: ${YELLOW}$USER_NAME${NC}
${GREEN}3.${NC} Desktop environment: ${PURPLE}Hyprland${NC}
${GREEN}4.${NC} Check logs: ${BLUE}$LOG_DIR/${NC}"
    echo
}

#
# Main Function
#

main() {
    # Parse arguments and load configuration
    parse_arguments "$@"
    load_configuration
    
    # Auto-detect .enc files and update configuration if needed
    auto_detect_enc_files
    
    validate_arguments
    
    # Show enhanced banner
    show_banner "$SCRIPT_VERSION"
    
    # Show configuration summary
    draw_box 60 "Deployment Configuration" "
${BOLD}Command:${NC}      ${GREEN}$COMMAND${NC}
${BOLD}Profile:${NC}      ${CYAN}$PROFILE${NC}
${BOLD}User:${NC}         ${YELLOW}$USER_NAME${NC}
${BOLD}Hostname:${NC}     ${YELLOW}$HOSTNAME${NC}
${BOLD}Password:${NC}     ${PURPLE}$PASSWORD_MODE${NC}
${BOLD}Encryption:${NC}   $([ "$ENCRYPTION_ENABLED" == "true" ] && echo "${GREEN}Enabled${NC}" || echo "${RED}Disabled${NC}")
${BOLD}Network:${NC}      ${BLUE}$NETWORK_MODE${NC}$([ "${DRY_RUN:-}" == "true" ] && echo "
${BOLD}Mode:${NC}         ${YELLOW}DRY RUN (preview only)${NC}" || echo "")"
    echo
    
    # Handle help command
    if [[ "${COMMAND:-}" == "help" ]]; then
        show_detailed_help
        exit $EXIT_SUCCESS
    fi
    
    # Performance setup
    check_performance_prerequisites
    enable_deployment_caching
    optimize_ansible_performance
    
    # Pre-flight checks
    check_system_requirements
    check_dependencies
    
    # Execute requested command
    case ${COMMAND:-} in
        install)
            execute_install_phase
            ;;
        desktop)
            execute_desktop_phase
            ;;
        security)
            execute_security_phase
            ;;
        full)
            execute_full_deployment
            ;;
    esac
    
    log_info "Deployment command '$COMMAND' completed successfully"
    
    # Performance cleanup
    cleanup_performance_artifacts
}

# Execute main function with all arguments  
main "$@"