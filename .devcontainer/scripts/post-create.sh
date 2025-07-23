#!/bin/bash
#
# post-create.sh - Post-create script for development container
#
# This script runs once after the container is created and performs
# initial setup for the development environment.
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
    log_info "Starting post-create setup for Arch Linux Desktop Automation development environment..."
    
    # Verify workspace
    if [[ ! -d "$WORKSPACE_ROOT" ]]; then
        log_error "Workspace directory not found: $WORKSPACE_ROOT"
        exit 1
    fi
    
    cd "$WORKSPACE_ROOT"
    
    # Set proper permissions
    log_info "Setting up workspace permissions..."
    sudo chown -R devuser:devuser "$WORKSPACE_ROOT" || true
    
    # Install Ansible Galaxy requirements
    if [[ -f "configs/ansible/requirements.yml" ]]; then
        log_info "Installing Ansible Galaxy requirements..."
        ansible-galaxy install -r configs/ansible/requirements.yml --force || {
            log_warn "Failed to install some Ansible Galaxy requirements"
        }
    fi
    
    # Install Python requirements
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing Python requirements..."
        pip install --user -r requirements.txt || {
            log_warn "Failed to install some Python requirements"
        }
    fi
    
    # Set up pre-commit hooks
    if command -v pre-commit >/dev/null 2>&1; then
        log_info "Setting up pre-commit hooks..."
        if [[ -f ".pre-commit-config.yaml" ]]; then
            pre-commit install || {
                log_warn "Failed to install pre-commit hooks"
            }
        else
            log_info "Creating basic pre-commit configuration..."
            cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-toml
      - id: check-xml
      - id: check-merge-conflict
      - id: check-case-conflict
      - id: check-executables-have-shebangs
      - id: check-shebang-scripts-are-executable
      
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.9.0
    hooks:
      - id: shellcheck
        args: [--severity=warning]
        
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.14.3
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$
        
  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black
        language_version: python3
EOF
            pre-commit install || {
                log_warn "Failed to install pre-commit hooks"
            }
        fi
    fi
    
    # Create development directories
    log_info "Creating development directories..."
    mkdir -p "$HOME/.cache/ansible" || true
    mkdir -p "$HOME/.ansible/tmp" || true
    mkdir -p "$WORKSPACE_ROOT/logs" || true
    mkdir -p "$WORKSPACE_ROOT/.dev" || true
    
    # Set up Ansible configuration
    if [[ -f "configs/ansible/ansible.cfg" ]]; then
        log_info "Validating Ansible configuration..."
        ansible-config validate configs/ansible/ansible.cfg || {
            log_warn "Ansible configuration validation failed"
        }
    fi
    
    # Set up Git configuration for development
    log_info "Setting up Git configuration for development..."
    git config --global --add safe.directory "$WORKSPACE_ROOT" || true
    
    # Set development-friendly Git settings if not already configured
    if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
        git config --global user.name "Development Container"
        git config --global user.email "dev@arch-automation.local"
        log_info "Set default Git user for development"
    fi
    
    # Create development shortcuts
    log_info "Creating development shortcuts..."
    cat > "$HOME/.local/bin/dev-test" << 'EOF'
#!/bin/bash
# Quick development test script
cd "${WORKSPACE_ROOT:-/workspace}"
./scripts/testing/test_installation.sh "$@"
EOF
    
    cat > "$HOME/.local/bin/dev-deploy" << 'EOF'
#!/bin/bash  
# Quick development deploy script
cd "${WORKSPACE_ROOT:-/workspace}"
./scripts/deploy.sh "$@"
EOF
    
    cat > "$HOME/.local/bin/dev-lint" << 'EOF'
#!/bin/bash
# Quick development linting
cd "${WORKSPACE_ROOT:-/workspace}"
echo "Running shellcheck..."
find scripts/ -name "*.sh" -exec shellcheck {} \;
echo "Running ansible-lint..."
ansible-lint configs/ansible/ || true
echo "Running yamllint..."
yamllint configs/ || true
EOF
    
    chmod +x "$HOME/.local/bin/dev-test"
    chmod +x "$HOME/.local/bin/dev-deploy" 
    chmod +x "$HOME/.local/bin/dev-lint"
    
    # Create development environment info
    cat > "$WORKSPACE_ROOT/.dev/environment-info.txt" << EOF
Arch Linux Desktop Automation - Development Environment
======================================================

Container: $(hostname)
User: $(whoami)
Workspace: $WORKSPACE_ROOT
Created: $(date)

Development Tools Available:
- Ansible $(ansible --version | head -1)
- Python $(python --version)
- Git $(git --version)
- Docker $(docker --version 2>/dev/null || echo "Docker not available")

Quick Commands:
- dev-test    : Run installation tests
- dev-deploy  : Run deployment script  
- dev-lint    : Run code linting
- deploy      : Alias for ./scripts/deploy.sh
- test-install: Alias for test script

Useful Directories:
- Logs: $WORKSPACE_ROOT/logs/
- Config: $WORKSPACE_ROOT/config/
- Scripts: $WORKSPACE_ROOT/scripts/
- Ansible: $WORKSPACE_ROOT/configs/ansible/

Development Features:
- Pre-commit hooks installed
- Ansible Galaxy requirements installed
- Python requirements installed
- Development aliases configured
- Code quality tools available

EOF
    
    log_info "Post-create setup completed successfully!"
    log_info "Development environment ready for Arch Linux Desktop Automation"
    
    # Show environment info
    echo
    echo -e "${BLUE}Development Environment Information:${NC}"
    cat "$WORKSPACE_ROOT/.dev/environment-info.txt"
}

main "$@"