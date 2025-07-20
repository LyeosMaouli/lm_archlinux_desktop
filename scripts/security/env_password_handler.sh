#!/bin/bash
# Environment Variable Password Handler
# Handles password input via environment variables for CI/CD and automation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Environment variable names
ENV_USER_PASSWORD="DEPLOY_USER_PASSWORD"
ENV_ROOT_PASSWORD="DEPLOY_ROOT_PASSWORD"
ENV_LUKS_PASSPHRASE="DEPLOY_LUKS_PASSPHRASE"
ENV_WIFI_PASSWORD="DEPLOY_WIFI_PASSWORD"

# Alternative names for compatibility
ALT_ENV_NAMES=(
    "USER_PASSWORD:DEPLOY_USER_PASSWORD"
    "ROOT_PASSWORD:DEPLOY_ROOT_PASSWORD"
    "LUKS_PASSPHRASE:DEPLOY_LUKS_PASSPHRASE"
    "WIFI_PASSWORD:DEPLOY_WIFI_PASSWORD"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[ENV]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[ENV-WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ENV-ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[ENV-SUCCESS]${NC} $1" >&2
}

# Check if environment variable exists and is not empty
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    
    if [[ -n "$var_value" ]]; then
        return 0
    else
        return 1
    fi
}

# Get environment variable value safely
get_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    
    if [[ -n "$var_value" ]]; then
        echo "$var_value"
        return 0
    else
        return 1
    fi
}

# Check for alternative environment variable names
check_alternative_env_names() {
    log_info "Checking alternative environment variable names..."
    
    for mapping in "${ALT_ENV_NAMES[@]}"; do
        local alt_name="${mapping%:*}"
        local standard_name="${mapping#*:}"
        
        if check_env_var "$alt_name" && ! check_env_var "$standard_name"; then
            local alt_value
            alt_value=$(get_env_var "$alt_name")
            export "$standard_name"="$alt_value"
            log_info "Mapped $alt_name to $standard_name"
        fi
    done
}

# Validate environment password
validate_env_password() {
    local password="$1"
    local password_name="$2"
    local min_length="${3:-8}"
    
    # Check length
    if [[ ${#password} -lt $min_length ]]; then
        log_error "$password_name from environment is too short (minimum $min_length characters)"
        return 1
    fi
    
    # Check for obviously bad passwords
    local lower_password
    lower_password=$(echo "$password" | tr '[:upper:]' '[:lower:]')
    
    local bad_passwords=("password" "123456" "admin" "root" "user" "test" "demo")
    for bad_pass in "${bad_passwords[@]}"; do
        if [[ "$lower_password" == "$bad_pass" ]]; then
            log_error "$password_name from environment is too weak: '$bad_pass'"
            return 1
        fi
    done
    
    # Check password strength
    local score=0
    [[ ${#password} -ge 8 ]] && ((score++))
    [[ ${#password} -ge 12 ]] && ((score++))
    [[ "$password" =~ [a-z] ]] && ((score++))
    [[ "$password" =~ [A-Z] ]] && ((score++))
    [[ "$password" =~ [0-9] ]] && ((score++))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((score++))
    
    if [[ $score -lt 3 ]]; then
        log_warn "$password_name from environment has weak strength (score: $score/6)"
    fi
    
    log_info "$password_name from environment validated (strength: $score/6)"
    return 0
}

# Load all passwords from environment
load_env_passwords() {
    log_info "Loading passwords from environment variables..."
    
    # Check for alternative names first
    check_alternative_env_names
    
    local passwords_found=0
    local passwords_failed=0
    
    # User password
    if check_env_var "$ENV_USER_PASSWORD"; then
        local user_password
        user_password=$(get_env_var "$ENV_USER_PASSWORD")
        if validate_env_password "$user_password" "User password"; then
            export USER_PASSWORD="$user_password"
            log_success "User password loaded from environment"
            ((passwords_found++))
        else
            ((passwords_failed++))
        fi
    else
        log_info "User password not found in environment ($ENV_USER_PASSWORD)"
    fi
    
    # Root password
    if check_env_var "$ENV_ROOT_PASSWORD"; then
        local root_password
        root_password=$(get_env_var "$ENV_ROOT_PASSWORD")
        if validate_env_password "$root_password" "Root password"; then
            export ROOT_PASSWORD="$root_password"
            log_success "Root password loaded from environment"
            ((passwords_found++))
        else
            ((passwords_failed++))
        fi
    else
        log_info "Root password not found in environment ($ENV_ROOT_PASSWORD)"
    fi
    
    # LUKS passphrase
    if check_env_var "$ENV_LUKS_PASSPHRASE"; then
        local luks_passphrase
        luks_passphrase=$(get_env_var "$ENV_LUKS_PASSPHRASE")
        if validate_env_password "$luks_passphrase" "LUKS passphrase" 12; then
            export LUKS_PASSPHRASE="$luks_passphrase"
            log_success "LUKS passphrase loaded from environment"
            ((passwords_found++))
        else
            ((passwords_failed++))
        fi
    else
        log_info "LUKS passphrase not found in environment ($ENV_LUKS_PASSPHRASE)"
    fi
    
    # WiFi password
    if check_env_var "$ENV_WIFI_PASSWORD"; then
        local wifi_password
        wifi_password=$(get_env_var "$ENV_WIFI_PASSWORD")
        if validate_env_password "$wifi_password" "WiFi password" 1; then
            export WIFI_PASSWORD="$wifi_password"
            log_success "WiFi password loaded from environment"
            ((passwords_found++))
        else
            ((passwords_failed++))
        fi
    else
        log_info "WiFi password not found in environment ($ENV_WIFI_PASSWORD)"
    fi
    
    # Summary
    log_info "Environment password loading complete: $passwords_found found, $passwords_failed failed"
    
    if [[ $passwords_found -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Clear environment passwords securely
clear_env_passwords() {
    log_info "Clearing environment passwords..."
    
    # Clear main environment variables
    unset "$ENV_USER_PASSWORD" 2>/dev/null || true
    unset "$ENV_ROOT_PASSWORD" 2>/dev/null || true
    unset "$ENV_LUKS_PASSPHRASE" 2>/dev/null || true
    unset "$ENV_WIFI_PASSWORD" 2>/dev/null || true
    
    # Clear alternative names
    for mapping in "${ALT_ENV_NAMES[@]}"; do
        local alt_name="${mapping%:*}"
        unset "$alt_name" 2>/dev/null || true
    done
    
    # Clear exported variables
    unset USER_PASSWORD ROOT_PASSWORD LUKS_PASSPHRASE WIFI_PASSWORD 2>/dev/null || true
    
    log_info "Environment passwords cleared"
}

# Show environment password status
show_env_status() {
    echo -e "${BLUE}Environment Password Status:${NC}"
    
    local env_vars=("$ENV_USER_PASSWORD" "$ENV_ROOT_PASSWORD" "$ENV_LUKS_PASSPHRASE" "$ENV_WIFI_PASSWORD")
    local labels=("User Password" "Root Password" "LUKS Passphrase" "WiFi Password")
    
    for i in "${!env_vars[@]}"; do
        local var_name="${env_vars[$i]}"
        local label="${labels[$i]}"
        
        if check_env_var "$var_name"; then
            local var_value="${!var_name}"
            echo -e "  ${GREEN}✓${NC} $label ($var_name): Set (${#var_value} characters)"
        else
            echo -e "  ${YELLOW}○${NC} $label ($var_name): Not set"
        fi
    done
}

# Generate environment variable template
generate_env_template() {
    local output_file="${1:-env_password_template.sh}"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Environment Variable Password Template
# Set these variables before running deployment

# User account password (minimum 8 characters)
export DEPLOY_USER_PASSWORD="your_secure_user_password"

# Root account password (minimum 8 characters)
export DEPLOY_ROOT_PASSWORD="your_secure_root_password"

# LUKS encryption passphrase (minimum 12 characters, optional)
export DEPLOY_LUKS_PASSPHRASE="your_secure_luks_passphrase"

# WiFi network password (optional)
export DEPLOY_WIFI_PASSWORD="your_wifi_password"

# Usage:
# 1. Edit this file with your actual passwords
# 2. Source the file: source env_password_template.sh
# 3. Run deployment: ./zero_touch_deploy.sh --password-mode env
# 4. Clear passwords: unset DEPLOY_USER_PASSWORD DEPLOY_ROOT_PASSWORD DEPLOY_LUKS_PASSPHRASE DEPLOY_WIFI_PASSWORD

echo "Environment variables set. Run deployment with --password-mode env"
EOF
    
    chmod 600 "$output_file"
    log_success "Environment template created: $output_file"
    log_warn "Remember to edit the template with your actual passwords"
}

# Validate CI/CD environment
validate_ci_environment() {
    log_info "Validating CI/CD environment..."
    
    local ci_indicators=(
        "CI"
        "CONTINUOUS_INTEGRATION"
        "GITHUB_ACTIONS"
        "GITLAB_CI"
        "JENKINS_URL"
        "TRAVIS"
        "CIRCLECI"
        "BUILDKITE"
    )
    
    local ci_detected=false
    for indicator in "${ci_indicators[@]}"; do
        if check_env_var "$indicator"; then
            log_info "CI/CD environment detected: $indicator"
            ci_detected=true
            break
        fi
    done
    
    if [[ "$ci_detected" == true ]]; then
        log_info "Running in CI/CD environment - environment variables recommended"
        
        # Check for secrets availability
        local required_secrets=("$ENV_USER_PASSWORD" "$ENV_ROOT_PASSWORD")
        local missing_secrets=()
        
        for secret in "${required_secrets[@]}"; do
            if ! check_env_var "$secret"; then
                missing_secrets+=("$secret")
            fi
        done
        
        if [[ ${#missing_secrets[@]} -gt 0 ]]; then
            log_error "Missing required secrets in CI/CD: ${missing_secrets[*]}"
            log_error "Please configure these secrets in your CI/CD system"
            return 1
        else
            log_success "All required secrets available in CI/CD"
            return 0
        fi
    else
        log_info "No CI/CD environment detected"
        return 0
    fi
}

# Help function
show_help() {
    cat << 'EOF'
Environment Variable Password Handler

This module handles password input via environment variables for CI/CD and automation.

Environment Variables:
  DEPLOY_USER_PASSWORD     - User account password
  DEPLOY_ROOT_PASSWORD     - Root account password  
  DEPLOY_LUKS_PASSPHRASE   - LUKS encryption passphrase
  DEPLOY_WIFI_PASSWORD     - WiFi network password

Alternative Names (for compatibility):
  USER_PASSWORD, ROOT_PASSWORD, LUKS_PASSPHRASE, WIFI_PASSWORD

Functions:
  load_env_passwords       - Load all passwords from environment
  clear_env_passwords      - Securely clear environment passwords
  show_env_status          - Show password availability status
  validate_ci_environment  - Check CI/CD environment setup
  generate_env_template    - Create environment variable template

Usage Examples:

1. Direct export:
   export DEPLOY_USER_PASSWORD="secure_password"
   export DEPLOY_ROOT_PASSWORD="secure_password"
   source env_password_handler.sh
   load_env_passwords

2. CI/CD Pipeline:
   # Set secrets in CI/CD system
   # Run deployment with environment method

3. Template generation:
   ./env_password_handler.sh template my_passwords.sh
   # Edit my_passwords.sh with actual passwords
   source my_passwords.sh

Security Features:
- Password strength validation
- Weak password detection
- Secure environment cleanup
- CI/CD environment detection
- Alternative name support

EOF
}

# Main execution
main() {
    case "${1:-help}" in
        "load")
            load_env_passwords
            ;;
        "clear")
            clear_env_passwords
            ;;
        "status")
            show_env_status
            ;;
        "template")
            generate_env_template "${2:-env_password_template.sh}"
            ;;
        "validate-ci")
            validate_ci_environment
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Usage: $0 {load|clear|status|template|validate-ci|help}"
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi