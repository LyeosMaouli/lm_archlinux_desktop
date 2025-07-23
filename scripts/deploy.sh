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

#
# Help and Usage Functions
#

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

COMMANDS:
  install     Install base Arch Linux system
  desktop     Set up Hyprland desktop environment
  security    Apply security hardening
  full        Complete end-to-end deployment
  help        Show detailed help and examples

OPTIONS:
  --profile PROFILE         Deployment profile (work|personal|development)
  --password MODE           Password handling (env|file|generate|interactive)
  --password-file FILE      Encrypted password file path
  --network MODE            Network setup (auto|manual|skip)
  --encryption              Enable disk encryption (default)
  --no-encryption           Disable disk encryption
  --hostname HOSTNAME       System hostname (default: phoenix)
  --user USERNAME           Primary user (default: lyeosmaouli)
  --config FILE             Custom configuration file
  --dry-run                 Preview actions without executing
  --verbose, -v             Enable verbose output
  --quiet, -q               Suppress non-essential output
  --help, -h                Show this help

EXAMPLES:
  # Complete automated deployment
  $SCRIPT_NAME full

  # Custom deployment with options
  $SCRIPT_NAME full --profile personal --password generate --hostname myarch

  # Step-by-step deployment
  $SCRIPT_NAME install --encryption
  $SCRIPT_NAME desktop --profile work
  $SCRIPT_NAME security

  # Use encrypted password file
  $SCRIPT_NAME full --password file --password-file /path/to/passwords.enc

  # Dry run to preview actions
  $SCRIPT_NAME full --dry-run --verbose

EOF
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
            log_error "Failed to load configuration file: $CONFIG_FILE"
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
        show_usage
        exit $EXIT_INVALID_ARGS
    fi
    
    # First argument is the command
    COMMAND="$1"
    shift
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --password)
                PASSWORD_MODE="$2"
                shift 2
                ;;
            --password-file)
                PASSWORD_FILE="$2"
                shift 2
                ;;
            --network)
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
                HOSTNAME="$2"
                shift 2
                ;;
            --user)
                USER_NAME="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                LOG_LEVEL=$LOG_DEBUG
                shift
                ;;
            --quiet|-q)
                LOG_LEVEL=$LOG_ERROR
                shift
                ;;
            --help|-h)
                show_detailed_help
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit $EXIT_INVALID_ARGS
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
    
    # Check UEFI boot mode
    if [[ ! -d /sys/firmware/efi ]]; then
        log_error "UEFI boot mode required"
        log_error "This script requires UEFI boot mode, not legacy BIOS"
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
    
    show_progress 1 3 "Full Deployment"
    
    if ! execute_desktop_phase; then
        log_error "Full deployment failed at desktop phase"
        return $EXIT_INSTALL_ERROR
    fi
    
    show_progress 2 3 "Full Deployment"
    
    if ! execute_security_phase; then
        log_error "Full deployment failed at security phase"
        return $EXIT_INSTALL_ERROR
    fi
    
    show_progress 3 3 "Full Deployment"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_info "Full deployment completed successfully in ${minutes}m${seconds}s"
    
    # Show final system information
    echo
    echo "🎉 Deployment Complete!"
    echo "===================="
    get_system_info
    echo
    echo "Next Steps:"
    echo "  1. Reboot the system: sudo reboot"
    echo "  2. Log in with user: $USER_NAME"
    echo "  3. Desktop environment: Hyprland"
    echo "  4. Check logs: $LOG_DIR/"
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
    
    # Show banner
    echo "=========================================="
    echo "  Arch Linux Desktop Deployment v$SCRIPT_VERSION"
    echo "=========================================="
    echo "Command: $COMMAND"
    echo "Profile: $PROFILE"
    echo "User: $USER_NAME"
    echo "Hostname: $HOSTNAME"
    echo "Password Mode: $PASSWORD_MODE"
    echo "Encryption: $ENCRYPTION_ENABLED"
    echo "Network: $NETWORK_MODE"
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        echo "Mode: DRY RUN (preview only)"
    fi
    echo "=========================================="
    echo
    
    # Handle help command
    if [[ "${COMMAND:-}" == "help" ]]; then
        show_detailed_help
        exit $EXIT_SUCCESS
    fi
    
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
}

# Execute main function with all arguments
main "$@"