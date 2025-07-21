#!/bin/bash
#
# profiles.sh - Profile Management Utility
#
# Consolidates profile management functionality:
# - Profile selection and validation
# - Profile-specific configuration loading
# - Package list management per profile
# - Environment-specific settings
#
# Usage:
#   ./profiles.sh [COMMAND] [OPTIONS]
#   source profiles.sh && load_profile [profile_name]
#
# Commands:
#   list                 List available profiles
#   show PROFILE         Show profile details
#   validate PROFILE     Validate profile configuration
#   load PROFILE         Load profile configuration
#   packages PROFILE     Show profile package list
#   create PROFILE       Create new profile
#   help                 Show help
#

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../internal/common.sh
source "$SCRIPT_DIR/../internal/common.sh"

# Profile configuration
readonly PROFILES_DIR="$PROJECT_ROOT/configs/profiles"
readonly AVAILABLE_PROFILES=("work" "personal" "development")
readonly DEFAULT_PROFILE="work"

# Current profile state
CURRENT_PROFILE=""
declare -A PROFILE_CONFIG
declare -A PROFILE_PACKAGES

#
# Profile Discovery and Validation
#

# Get list of available profiles
get_available_profiles() {
    local profiles=()
    
    # Check built-in profiles
    for profile in "${AVAILABLE_PROFILES[@]}"; do
        if [[ -d "$PROFILES_DIR/$profile" ]]; then
            profiles+=("$profile")
        fi
    done
    
    # Check for custom profiles
    if [[ -d "$PROFILES_DIR" ]]; then
        while IFS= read -r -d '' profile_dir; do
            local profile_name
            profile_name=$(basename "$profile_dir")
            
            # Skip if already in built-in list
            local is_builtin=false
            for builtin in "${AVAILABLE_PROFILES[@]}"; do
                if [[ "$profile_name" == "$builtin" ]]; then
                    is_builtin=true
                    break
                fi
            done
            
            if [[ "$is_builtin" == "false" ]]; then
                profiles+=("$profile_name")
            fi
        done < <(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    
    printf '%s\n' "${profiles[@]}"
}

# Check if profile exists and is valid
validate_profile_exists() {
    local profile="$1"
    
    if [[ -z "$profile" ]]; then
        log_error "Profile name is required"
        return 1
    fi
    
    local profile_dir="$PROFILES_DIR/$profile"
    
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile directory not found: $profile_dir"
        return 1
    fi
    
    # Check for required files
    local required_files=(
        "$profile_dir/ansible/vars.yml"
        "$profile_dir/archinstall/user_configuration.json"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required profile file missing: $file"
            return 1
        fi
    done
    
    return 0
}

# Validate profile configuration
validate_profile_config() {
    local profile="$1"
    
    if ! validate_profile_exists "$profile"; then
        return 1
    fi
    
    log_info "Validating profile configuration: $profile"
    
    local profile_dir="$PROFILES_DIR/$profile"
    local validation_errors=()
    local validation_warnings=()
    
    # Validate Ansible vars file
    local ansible_vars="$profile_dir/ansible/vars.yml"
    if [[ -f "$ansible_vars" ]]; then
        # Check YAML syntax
        if command_exists python3; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$ansible_vars'))" 2>/dev/null; then
                validation_errors+=("Invalid YAML syntax in $ansible_vars")
            fi
        fi
        
        # Check for required variables
        local required_vars=("profile_name" "user_packages" "desktop_packages")
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}:" "$ansible_vars" 2>/dev/null; then
                validation_warnings+=("Missing recommended variable: $var in $ansible_vars")
            fi
        done
    fi
    
    # Validate archinstall configuration
    local archinstall_config="$profile_dir/archinstall/user_configuration.json"
    if [[ -f "$archinstall_config" ]]; then
        # Check JSON syntax
        if command_exists python3; then
            if ! python3 -c "import json; json.load(open('$archinstall_config'))" 2>/dev/null; then
                validation_errors+=("Invalid JSON syntax in $archinstall_config")
            fi
        fi
    fi
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Profile validation failed for '$profile':"
        for error in "${validation_errors[@]}"; do
            log_error "  ✗ $error"
        done
        
        if [[ ${#validation_warnings[@]} -gt 0 ]]; then
            log_warn "Additional warnings:"
            for warning in "${validation_warnings[@]}"; do
                log_warn "  ⚠ $warning"
            done
        fi
        
        return 1
    fi
    
    if [[ ${#validation_warnings[@]} -gt 0 ]]; then
        log_warn "Profile validation passed with warnings:"
        for warning in "${validation_warnings[@]}"; do
            log_warn "  ⚠ $warning"
        done
    fi
    
    log_info "✓ Profile '$profile' is valid"
    return 0
}

#
# Profile Configuration Loading
#

# Load profile configuration
load_profile() {
    local profile="$1"
    
    if [[ -z "$profile" ]]; then
        profile="$DEFAULT_PROFILE"
        log_info "Using default profile: $profile"
    fi
    
    if ! validate_profile_exists "$profile"; then
        log_error "Cannot load invalid profile: $profile"
        return 1
    fi
    
    log_info "Loading profile configuration: $profile"
    
    local profile_dir="$PROFILES_DIR/$profile"
    CURRENT_PROFILE="$profile"
    
    # Clear existing configuration
    PROFILE_CONFIG=()
    PROFILE_PACKAGES=()
    
    # Load basic profile information
    PROFILE_CONFIG["name"]="$profile"
    PROFILE_CONFIG["dir"]="$profile_dir"
    PROFILE_CONFIG["ansible_vars"]="$profile_dir/ansible/vars.yml"
    PROFILE_CONFIG["archinstall_config"]="$profile_dir/archinstall/user_configuration.json"
    
    # Load Ansible variables
    if [[ -f "${PROFILE_CONFIG[ansible_vars]}" ]]; then
        log_debug "Loading Ansible variables from ${PROFILE_CONFIG[ansible_vars]}"
        
        # Extract common configuration values
        while IFS=': ' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove quotes and trim whitespace
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'"'"']//;s/["'"'"']$//')
            
            case "$key" in
                profile_name) PROFILE_CONFIG["display_name"]="$value" ;;
                profile_description) PROFILE_CONFIG["description"]="$value" ;;
                profile_category) PROFILE_CONFIG["category"]="$value" ;;
                default_shell) PROFILE_CONFIG["shell"]="$value" ;;
                enable_aur) PROFILE_CONFIG["aur_enabled"]="$value" ;;
            esac
        done < <(grep -E '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:' "${PROFILE_CONFIG[ansible_vars]}" 2>/dev/null)
        
        # Load package lists
        load_profile_packages "$profile"
    fi
    
    # Load archinstall configuration
    if [[ -f "${PROFILE_CONFIG[archinstall_config]}" ]]; then
        log_debug "Loading archinstall configuration from ${PROFILE_CONFIG[archinstall_config]}"
        
        if command_exists python3; then
            # Extract key values from JSON
            local hostname
            hostname=$(python3 -c "
import json, sys
try:
    with open('${PROFILE_CONFIG[archinstall_config]}') as f:
        config = json.load(f)
    print(config.get('hostname', ''))
except:
    pass
" 2>/dev/null)
            
            if [[ -n "$hostname" ]]; then
                PROFILE_CONFIG["hostname"]="$hostname"
            fi
        fi
    fi
    
    # Set defaults for missing values
    PROFILE_CONFIG["display_name"]="${PROFILE_CONFIG[display_name]:-$(echo "$profile" | sed 's/.*/\L&/; s/[a-z]/\u&/')}"
    PROFILE_CONFIG["description"]="${PROFILE_CONFIG[description]:-"$profile profile configuration"}"
    PROFILE_CONFIG["category"]="${PROFILE_CONFIG[category]:-"general"}"
    PROFILE_CONFIG["shell"]="${PROFILE_CONFIG[shell]:-"bash"}"
    PROFILE_CONFIG["aur_enabled"]="${PROFILE_CONFIG[aur_enabled]:-"true"}"
    PROFILE_CONFIG["hostname"]="${PROFILE_CONFIG[hostname]:-"phoenix"}"
    
    log_info "Profile '$profile' loaded successfully"
    log_debug "Profile details: ${PROFILE_CONFIG[display_name]} (${PROFILE_CONFIG[category]})"
    
    return 0
}

# Load package lists from profile
load_profile_packages() {
    local profile="$1"
    local profile_dir="$PROFILES_DIR/$profile"
    local ansible_vars="$profile_dir/ansible/vars.yml"
    
    log_debug "Loading package lists for profile: $profile"
    
    # Initialize package arrays
    PROFILE_PACKAGES["base"]=""
    PROFILE_PACKAGES["user"]=""
    PROFILE_PACKAGES["desktop"]=""
    PROFILE_PACKAGES["aur"]=""
    PROFILE_PACKAGES["development"]=""
    
    if [[ ! -f "$ansible_vars" ]]; then
        log_warn "Ansible vars file not found: $ansible_vars"
        return 1
    fi
    
    # Parse YAML package lists (simplified parser)
    local current_section=""
    local in_list=false
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect package list sections
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*_packages):[[:space:]]*$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            in_list=true
            continue
        elif [[ "$line" =~ ^[a-zA-Z_] ]] && [[ "$in_list" == "true" ]]; then
            # End of current list
            in_list=false
            current_section=""
        fi
        
        # Extract package names from lists
        if [[ "$in_list" == "true" && "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ ]]; then
            local package="${BASH_REMATCH[1]}"
            # Remove quotes and comments
            package=$(echo "$package" | sed 's/['"'"'"]//g' | sed 's/#.*//' | xargs)
            
            if [[ -n "$package" ]]; then
                case "$current_section" in
                    base_packages) 
                        PROFILE_PACKAGES["base"]+="$package "
                        ;;
                    user_packages)
                        PROFILE_PACKAGES["user"]+="$package "
                        ;;
                    desktop_packages)
                        PROFILE_PACKAGES["desktop"]+="$package "
                        ;;
                    aur_packages)
                        PROFILE_PACKAGES["aur"]+="$package "
                        ;;
                    development_packages)
                        PROFILE_PACKAGES["development"]+="$package "
                        ;;
                esac
            fi
        fi
    done < "$ansible_vars"
    
    # Trim trailing spaces
    for key in "${!PROFILE_PACKAGES[@]}"; do
        PROFILE_PACKAGES["$key"]=$(echo "${PROFILE_PACKAGES[$key]}" | xargs)
    done
    
    log_debug "Loaded package lists:"
    for category in base user desktop aur development; do
        local count
        count=$(echo "${PROFILE_PACKAGES[$category]}" | wc -w)
        if [[ $count -gt 0 ]]; then
            log_debug "  $category: $count packages"
        fi
    done
    
    return 0
}

#
# Profile Information Functions
#

# Get profile configuration value
get_profile_config() {
    local key="$1"
    local default_value="$2"
    
    if [[ -v PROFILE_CONFIG[$key] ]]; then
        echo "${PROFILE_CONFIG[$key]}"
    else
        echo "$default_value"
    fi
}

# Get profile packages for category
get_profile_packages() {
    local category="$1"
    
    if [[ -v PROFILE_PACKAGES[$category] ]]; then
        echo "${PROFILE_PACKAGES[$category]}"
    else
        echo ""
    fi
}

# Show profile details
show_profile_details() {
    local profile="${1:-$CURRENT_PROFILE}"
    
    if [[ -z "$profile" ]]; then
        log_error "No profile specified or loaded"
        return 1
    fi
    
    if [[ "$profile" != "$CURRENT_PROFILE" ]]; then
        # Load profile temporarily
        load_profile "$profile" >/dev/null 2>&1
    fi
    
    echo "=========================================="
    echo "  Profile: $profile"
    echo "=========================================="
    echo "Name: $(get_profile_config "display_name" "Unknown")"
    echo "Description: $(get_profile_config "description" "No description")"
    echo "Category: $(get_profile_config "category" "general")"
    echo "Directory: $(get_profile_config "dir" "Unknown")"
    echo "Shell: $(get_profile_config "shell" "bash")"
    echo "AUR Enabled: $(get_profile_config "aur_enabled" "unknown")"
    echo "Hostname: $(get_profile_config "hostname" "phoenix")"
    echo
    
    echo "Package Counts:"
    local total_packages=0
    for category in base user desktop aur development; do
        local packages
        packages=$(get_profile_packages "$category")
        local count
        count=$(echo "$packages" | wc -w)
        
        if [[ $count -gt 0 ]]; then
            echo "  $category: $count packages"
            ((total_packages += count))
        fi
    done
    echo "  Total: $total_packages packages"
    echo
    
    echo "Configuration Files:"
    echo "  Ansible vars: ${PROFILE_CONFIG[ansible_vars]}"
    echo "  Archinstall config: ${PROFILE_CONFIG[archinstall_config]}"
    echo "=========================================="
}

# List all packages for profile
list_profile_packages() {
    local profile="${1:-$CURRENT_PROFILE}"
    local category="${2:-all}"
    
    if [[ -z "$profile" ]]; then
        log_error "No profile specified or loaded"
        return 1
    fi
    
    if [[ "$profile" != "$CURRENT_PROFILE" ]]; then
        load_profile "$profile" >/dev/null 2>&1
    fi
    
    echo "Packages for profile: $profile"
    echo "=========================================="
    
    if [[ "$category" == "all" ]]; then
        for cat in base user desktop aur development; do
            local packages
            packages=$(get_profile_packages "$cat")
            if [[ -n "$packages" ]]; then
                echo
                echo "$cat packages:"
                echo "$packages" | tr ' ' '\n' | sed 's/^/  - /'
            fi
        done
    else
        local packages
        packages=$(get_profile_packages "$category")
        if [[ -n "$packages" ]]; then
            echo
            echo "$category packages:"
            echo "$packages" | tr ' ' '\n' | sed 's/^/  - /'
        else
            echo "No packages found for category: $category"
        fi
    fi
    
    echo "=========================================="
}

#
# Profile Creation Functions
#

# Create new profile from template
create_profile() {
    local profile="$1"
    local template="${2:-work}"
    
    if [[ -z "$profile" ]]; then
        log_error "Profile name is required"
        return 1
    fi
    
    # Validate profile name
    if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid profile name. Use only letters, numbers, underscores, and hyphens."
        return 1
    fi
    
    local profile_dir="$PROFILES_DIR/$profile"
    
    if [[ -d "$profile_dir" ]]; then
        log_error "Profile already exists: $profile"
        return 1
    fi
    
    # Validate template profile
    if ! validate_profile_exists "$template"; then
        log_error "Template profile not found: $template"
        return 1
    fi
    
    log_info "Creating new profile '$profile' from template '$template'"
    
    # Create profile directory structure
    ensure_dir "$profile_dir/ansible"
    ensure_dir "$profile_dir/archinstall"
    
    # Copy template files
    local template_dir="$PROFILES_DIR/$template"
    
    if ! cp "$template_dir/ansible/vars.yml" "$profile_dir/ansible/vars.yml"; then
        log_error "Failed to copy Ansible vars file"
        return 1
    fi
    
    if ! cp "$template_dir/archinstall/user_configuration.json" "$profile_dir/archinstall/user_configuration.json"; then
        log_error "Failed to copy archinstall configuration"
        return 1
    fi
    
    # Update profile-specific values
    sed -i "s/profile_name:.*/profile_name: \"$profile\"/" "$profile_dir/ansible/vars.yml" 2>/dev/null || true
    sed -i "s/profile_description:.*/profile_description: \"Custom $profile profile\"/" "$profile_dir/ansible/vars.yml" 2>/dev/null || true
    
    # Update JSON configuration
    if command_exists python3; then
        python3 -c "
import json
try:
    with open('$profile_dir/archinstall/user_configuration.json', 'r') as f:
        config = json.load(f)
    
    # Update hostname to be profile-specific
    config['hostname'] = '${profile}-arch'
    
    with open('$profile_dir/archinstall/user_configuration.json', 'w') as f:
        json.dump(config, f, indent=2)
except Exception as e:
    pass
" 2>/dev/null
    fi
    
    log_info "Profile '$profile' created successfully"
    log_info "Profile directory: $profile_dir"
    log_info "Edit the configuration files to customize the profile:"
    log_info "  - $profile_dir/ansible/vars.yml"
    log_info "  - $profile_dir/archinstall/user_configuration.json"
    
    return 0
}

#
# Profile Export Functions
#

# Export profile environment variables
export_profile_vars() {
    local profile="${1:-$CURRENT_PROFILE}"
    
    if [[ -z "$profile" ]]; then
        log_error "No profile specified or loaded"
        return 1
    fi
    
    if [[ "$profile" != "$CURRENT_PROFILE" ]]; then
        load_profile "$profile" >/dev/null 2>&1
    fi
    
    # Export common profile variables
    export DEPLOY_PROFILE="$profile"
    export DEPLOY_HOSTNAME="$(get_profile_config "hostname" "phoenix")"
    export DEPLOY_SHELL="$(get_profile_config "shell" "bash")"
    export DEPLOY_AUR_ENABLED="$(get_profile_config "aur_enabled" "true")"
    
    # Export package lists
    export DEPLOY_BASE_PACKAGES="$(get_profile_packages "base")"
    export DEPLOY_USER_PACKAGES="$(get_profile_packages "user")"
    export DEPLOY_DESKTOP_PACKAGES="$(get_profile_packages "desktop")"
    export DEPLOY_AUR_PACKAGES="$(get_profile_packages "aur")"
    export DEPLOY_DEV_PACKAGES="$(get_profile_packages "development")"
    
    # Export configuration file paths
    export DEPLOY_ANSIBLE_VARS="${PROFILE_CONFIG[ansible_vars]}"
    export DEPLOY_ARCHINSTALL_CONFIG="${PROFILE_CONFIG[archinstall_config]}"
    
    log_info "Profile environment variables exported for: $profile"
}

#
# Command Line Interface
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    
    case "${1:-help}" in
        list)
            echo "Available profiles:"
            get_available_profiles | sed 's/^/  - /'
            ;;
        show)
            if [[ -n "$2" ]]; then
                show_profile_details "$2"
            else
                echo "Usage: $0 show <profile_name>"
                exit 1
            fi
            ;;
        validate)
            if [[ -n "$2" ]]; then
                validate_profile_config "$2"
            else
                echo "Usage: $0 validate <profile_name>"
                exit 1
            fi
            ;;
        load)
            if [[ -n "$2" ]]; then
                load_profile "$2"
                export_profile_vars "$2"
            else
                echo "Usage: $0 load <profile_name>"
                exit 1
            fi
            ;;
        packages)
            if [[ -n "$2" ]]; then
                list_profile_packages "$2" "$3"
            else
                echo "Usage: $0 packages <profile_name> [category]"
                exit 1
            fi
            ;;
        create)
            if [[ -n "$2" ]]; then
                create_profile "$2" "$3"
            else
                echo "Usage: $0 create <new_profile_name> [template_profile]"
                exit 1
            fi
            ;;
        export)
            if [[ -n "$2" ]]; then
                load_profile "$2"
                export_profile_vars "$2"
                echo "Profile environment variables exported"
            else
                echo "Usage: $0 export <profile_name>"
                exit 1
            fi
            ;;
        help|*)
            cat << EOF
Profile Management Utility

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  list                     List available profiles
  show PROFILE             Show profile details and configuration
  validate PROFILE         Validate profile configuration files
  load PROFILE             Load profile configuration
  packages PROFILE [CAT]   Show profile packages (all categories or specific)
  create PROFILE [TMPL]    Create new profile from template
  export PROFILE           Export profile as environment variables
  help                     Show this help

Available Profiles:
$(get_available_profiles | sed 's/^/  - /')

Package Categories:
  base                     Base system packages
  user                     User application packages
  desktop                  Desktop environment packages
  aur                      AUR packages
  development              Development tools
  all                      All categories (default)

Examples:
  $0 list                  # List all profiles
  $0 show work             # Show work profile details
  $0 validate personal     # Validate personal profile
  $0 packages work desktop # Show desktop packages for work profile
  $0 create myprofile work # Create new profile from work template
  $0 export development    # Export development profile variables

Profile Structure:
  profiles/PROFILE/
    ├── ansible/vars.yml              # Ansible variables
    └── archinstall/user_configuration.json  # Installation config

EOF
            ;;
    esac
fi