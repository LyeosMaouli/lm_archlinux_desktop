# Development Environment

This directory contains development environment configuration and helper scripts for the Arch Linux Desktop Automation project.

## Quick Start

### Using VSCode Dev Containers

1. Install the "Dev Containers" extension in VSCode
2. Open this project in VSCode
3. Press `Ctrl+Shift+P` and select "Dev Containers: Reopen in Container"
4. Wait for the development environment to build and start

### Using Docker Compose

```bash
# Start the development environment
docker compose up -d dev

# Access the development container
docker compose exec dev bash

# Run tests
docker compose exec dev ./scripts/testing/test_installation.sh

# Start documentation server
docker compose up docs
# Access at http://localhost:8000

# Start testing environment
docker compose --profile testing up test
```

## Development Services

### Main Development Container (`dev`)

- **Purpose**: Primary development environment with all tools
- **Access**: `docker compose exec dev bash`
- **Ports**: 8080 (dev server), 9000 (testing)
- **Features**: Ansible, Python, testing tools, code quality tools

### Documentation Server (`docs`)

- **Purpose**: Serves project documentation
- **Access**: http://localhost:8000
- **Auto-reload**: Yes (when using MkDocs)

### Testing Environment (`test`)

- **Purpose**: Isolated testing environment
- **Access**: `docker compose exec test bash`
- **Features**: Read-only source mount, separate log volume

### Redis (`redis`)

- **Purpose**: Caching and task queues for development
- **Access**: `redis://localhost:6379`
- **Data**: Persistent in named volume

### PostgreSQL (`postgres`)

- **Purpose**: Database for development (optional)
- **Access**: `postgresql://developer:devpassword@localhost:5432/arch_automation_dev`
- **Profile**: `database` (start with `--profile database`)

## Development Commands

### Inside Development Container

```bash
# Quick deployment test
dev-deploy --dry-run full

# Run comprehensive tests
dev-test

# Code quality checks
dev-lint

# Show environment information
dev-info

# Standard project commands
./scripts/deploy.sh help
./scripts/testing/test_installation.sh
```

### Docker Compose Commands

```bash
# Start all services
docker compose up -d

# Start with specific profiles
docker compose --profile testing --profile database up -d

# View logs
docker compose logs -f dev

# Rebuild development image
docker compose build dev

# Clean up everything
docker compose down -v
docker compose build --no-cache
```

## Directory Structure

```
dev/
├── README.md                 # This file
├── database/                 # Database initialization scripts
│   └── init/                 # PostgreSQL init scripts
├── scripts/                  # Development helper scripts
│   ├── setup-dev.sh         # Development environment setup
│   ├── run-tests.sh         # Test runner
│   └── quality-check.sh     # Code quality checks
└── config/                   # Development configuration
    ├── pre-commit-config.yaml
    └── dev-settings.json
```

## Environment Variables

The development environment supports these variables:

```bash
# User configuration
USER_UID=1000                 # Your user ID
USER_GID=1000                 # Your group ID
USERNAME=developer            # Container username

# Development settings
WORKSPACE_ROOT=/workspace     # Workspace directory
DEVELOPMENT_MODE=true         # Enable development features
LOG_LEVEL=3                   # Logging verbosity

# Ansible configuration
ANSIBLE_CONFIG=/workspace/configs/ansible/ansible.cfg
ANSIBLE_ROLES_PATH=/workspace/configs/ansible/roles
ANSIBLE_INVENTORY=/workspace/configs/ansible/inventory
```

## Features

### Code Quality

- **Pre-commit hooks**: Automatic code formatting and linting
- **Shellcheck**: Shell script analysis
- **Ansible-lint**: Ansible playbook validation
- **Black**: Python code formatting
- **Yamllint**: YAML file validation

### Testing

- **Molecule**: Ansible role testing framework
- **Pytest**: Python testing framework
- **Bats**: Bash testing framework
- **Integration tests**: Full deployment testing

### Development Tools

- **Modern CLI tools**: bat, exa, fd, ripgrep, fzf
- **Git integration**: Pre-configured with aliases
- **Documentation**: MkDocs with Material theme
- **Debugging**: GDB, strace, performance profiling tools

## Troubleshooting

### Container Won't Start

```bash
# Check Docker daemon
sudo systemctl status docker

# Check for port conflicts
netstat -tulpn | grep -E ':(8000|8080|9000|5432|6379)'

# Rebuild without cache
docker compose build --no-cache dev
```

### Permission Issues

```bash
# Set proper user IDs
export USER_UID=$(id -u)
export USER_GID=$(id -g)
docker compose build dev
```

### Missing Tools

```bash
# Reinstall development packages
docker compose exec dev sudo pacman -S --needed base-devel
```

### Volume Issues

```bash
# Reset all volumes
docker compose down -v
docker volume prune
```

## Contributing

When contributing to the development environment:

1. Test changes in isolation
2. Update documentation
3. Verify all profiles work
4. Check resource usage
5. Update version numbers

## Security Notes

- Development containers run with elevated privileges for debugging
- SSH keys are mounted read-only
- Database uses development passwords (not for production)
- Docker socket is mounted for testing (security implications)

## Performance Tips

- Use volume caching for better performance
- Limit resource usage in docker compose.yml
- Use multi-stage builds to reduce image size
- Clean up unused volumes regularly
