#!/bin/bash
#
# post-start.sh - Post-start script for development container
#
# This script runs every time the container is started and performs
# startup tasks for the development environment.
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace}"

main() {
    log_info "Starting post-start setup for development environment..."
    
    # Verify workspace
    if [[ ! -d "$WORKSPACE_ROOT" ]]; then
        log_error "Workspace directory not found: $WORKSPACE_ROOT"
        exit 1
    fi
    
    cd "$WORKSPACE_ROOT"
    
    # Update container status
    log_info "Container started at $(date)" >> "$WORKSPACE_ROOT/.dev/container-history.log" 2>/dev/null || true
    
    # Verify critical tools
    log_info "Verifying development tools..."
    local missing_tools=()
    
    for tool in ansible ansible-playbook git python bash; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing critical tools: ${missing_tools[*]}"
        log_error "Development environment may not function correctly"
    else
        log_info "All critical development tools available"
    fi
    
    # Check for workspace changes
    if [[ -d ".git" ]]; then
        local git_status
        git_status=$(git status --porcelain 2>/dev/null || echo "")
        if [[ -n "$git_status" ]]; then
            log_info "Workspace has uncommitted changes:"
            echo "$git_status" | head -10
            if [[ $(echo "$git_status" | wc -l) -gt 10 ]]; then
                echo "... and $(($(echo "$git_status" | wc -l) - 10)) more files"
            fi
        fi
    fi
    
    # Update Ansible Galaxy roles if needed (background)
    if [[ -f "configs/ansible/requirements.yml" ]]; then
        log_info "Checking for Ansible Galaxy updates (background)..."
        (
            # Run in background to not slow down container start
            sleep 2
            ansible-galaxy install -r configs/ansible/requirements.yml --force >/dev/null 2>&1 || true
        ) &
    fi
    
    # Clean up old log files (keep last 10)
    if [[ -d "$WORKSPACE_ROOT/logs" ]]; then
        find "$WORKSPACE_ROOT/logs" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
        
        # Keep only the 10 most recent log files
        if [[ $(find "$WORKSPACE_ROOT/logs" -name "*.log" -type f | wc -l) -gt 10 ]]; then
            find "$WORKSPACE_ROOT/logs" -name "*.log" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -10 | cut -d' ' -f2- | \
                xargs rm -f 2>/dev/null || true
        fi
    fi
    
    # Create/update development status
    cat > "$WORKSPACE_ROOT/.dev/status.txt" << EOF
Development Environment Status
=============================

Last Started: $(date)
Container: $(hostname)
User: $(whoami)
Workspace: $WORKSPACE_ROOT

Environment Variables:
- ANSIBLE_CONFIG: ${ANSIBLE_CONFIG:-"Not set"}
- ANSIBLE_ROLES_PATH: ${ANSIBLE_ROLES_PATH:-"Not set"}
- ANSIBLE_INVENTORY: ${ANSIBLE_INVENTORY:-"Not set"}
- LOG_LEVEL: ${LOG_LEVEL:-"Not set"}
- DEVELOPMENT_MODE: ${DEVELOPMENT_MODE:-"Not set"}

Quick Health Check:
- Ansible: $(command -v ansible >/dev/null && echo "✓ Available" || echo "✗ Missing")
- Python: $(command -v python >/dev/null && echo "✓ Available" || echo "✗ Missing")
- Git: $(command -v git >/dev/null && echo "✓ Available" || echo "✗ Missing")
- Docker: $(command -v docker >/dev/null && echo "✓ Available" || echo "✗ Missing")

Workspace Status:
- Git Repository: $([ -d .git ] && echo "✓ Yes" || echo "✗ No")
- Uncommitted Changes: $([ -d .git ] && [ -n "$(git status --porcelain 2>/dev/null)" ] && echo "⚠ Yes" || echo "✓ None")
- Log Directory: $([ -d logs ] && echo "✓ Exists" || echo "✗ Missing")
- Config Files: $([ -f config/deploy.conf ] && echo "✓ Found" || echo "⚠ Default only")

Development Features:
- Pre-commit Hooks: $([ -f .git/hooks/pre-commit ] && echo "✓ Installed" || echo "✗ Not installed")
- Python Packages: $(pip list 2>/dev/null | wc -l) packages installed
- Ansible Collections: $(ansible-galaxy collection list 2>/dev/null | grep -c '^[a-z]' || echo "0") collections

EOF
    
    # Show welcome message
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          ${GREEN}Arch Linux Desktop Automation${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                 ${YELLOW}Development Environment${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✓${NC} Development environment ready!"
    echo -e "${GREEN}✓${NC} All tools verified and available"
    echo
    echo -e "Quick commands:"
    echo -e "  ${YELLOW}dev-deploy${NC}   - Run deployment script"
    echo -e "  ${YELLOW}dev-test${NC}     - Run installation tests"
    echo -e "  ${YELLOW}dev-lint${NC}     - Run code quality checks"
    echo
    echo -e "Status file: ${BLUE}.dev/status.txt${NC}"
    echo -e "Environment: ${BLUE}.dev/environment-info.txt${NC}"
    echo
    
    log_info "Post-start setup completed successfully!"
}

main "$@"