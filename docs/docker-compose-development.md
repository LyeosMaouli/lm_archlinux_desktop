# Docker Compose Development Environment

## Overview

The Docker Compose Development Environment is a **next-generation containerized development platform** for the Arch Linux Desktop Automation project. It provides a complete, isolated, and reproducible development ecosystem that eliminates environment inconsistencies and accelerates development workflows.

## 🎯 **Core Philosophy**

### Container-First Development
- **Consistency**: Identical environment across all development machines
- **Isolation**: Safe testing without affecting host systems
- **Reproducibility**: Version-controlled development environment
- **Scalability**: Easy addition of new services and tools

### Multi-Service Architecture
- **Separation of Concerns**: Each service handles specific functionality
- **Resource Optimization**: Efficient resource allocation per service
- **Development Flexibility**: Start only needed services
- **Testing Isolation**: Dedicated testing environments

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                Development Network (172.20.0.0/16)          │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Dev Container │ Documentation   │     Testing Services    │
│                 │    Server       │                         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │
│ │   Ansible   │ │ │   MkDocs    │ │ │  Isolated Testing   │ │
│ │   Python    │ │ │  HTTP       │ │ │    Environment      │ │
│ │   Testing   │ │ │  Server     │ │ │                     │ │
│ │   Tools     │ │ │             │ │ │  • Read-only mount  │ │
│ └─────────────┘ │ └─────────────┘ │ │  • Separate logs    │ │
│                 │                 │ │  • Clean state      │ │
├─────────────────┼─────────────────┼─────────────────────────┤
│  Support Services                 │    Optional Services    │
│                                   │                         │
│ ┌─────────────┐ ┌─────────────┐   │ ┌─────────────────────┐ │
│ │    Redis    │ │  PostgreSQL │   │ │   Additional        │ │
│ │   Caching   │ │  Database   │   │ │   Services          │ │
│ │   Queues    │ │  (Optional) │   │ │   (Future)          │ │
│ └─────────────┘ └─────────────┘   │ └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start Guide**

### Prerequisites

```bash
# Required software
docker --version          # Docker 20.10+
docker compose version    # Docker Compose 2.0+
git --version             # Git 2.30+

# Recommended system resources
# RAM: 4GB+ available
# Storage: 10GB+ free space
# CPU: 2+ cores
```

### 1. Basic Development Setup

```bash
# Clone the repository
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Start core development services
docker compose up -d dev docs redis

# Access development environment
docker compose exec dev bash

# Verify setup
dev-info
```

### 2. VSCode Dev Containers (Recommended)

```bash
# 1. Install VSCode and Dev Containers extension
# 2. Open project in VSCode
code lm_archlinux_desktop

# 3. Reopen in container
# Ctrl+Shift+P → "Dev Containers: Reopen in Container"

# 4. Development environment ready!
# All tools pre-configured and available
```

### 3. Full Development Stack

```bash
# Start all services including optional ones
docker compose --profile testing --profile database up -d

# Services now running:
# - Development container (dev)
# - Documentation server (docs) - http://localhost:8000
# - Redis cache (redis)
# - Testing environment (test)
# - PostgreSQL database (postgres)
```

## 📦 **Service Detailed Overview**

### 🔧 **Development Container (`dev`)**

**Purpose**: Primary development environment with complete toolchain

**Features**:
- **Base**: Arch Linux latest with development packages  
- **Languages**: Python 3.11+, Bash, Shell scripting
- **Automation**: Ansible, ansible-lint, molecule
- **Testing**: pytest, bats, shellcheck
- **Code Quality**: black, flake8, mypy, pre-commit
- **Modern Tools**: bat, exa, fd, ripgrep, fzf
- **Documentation**: sphinx, mkdocs, mkdocs-material

**Access Methods**:
```bash
# Interactive shell
docker compose exec dev bash

# Run specific commands
docker compose exec dev ./scripts/deploy.sh --help
docker compose exec dev ansible-playbook --version

# File operations
docker compose exec dev ls -la configs/ansible/roles/
```

**Environment Variables**:
```bash
WORKSPACE_ROOT=/workspace           # Project root directory
ANSIBLE_CONFIG=/workspace/configs/ansible/ansible.cfg
ANSIBLE_ROLES_PATH=/workspace/configs/ansible/roles
ANSIBLE_INVENTORY=/workspace/configs/ansible/inventory
DEVELOPMENT_MODE=true              # Enable development features
LOG_LEVEL=3                        # Verbose logging
```

**Volume Mounts**:
- **Source Code**: `.:/workspace:cached` (bidirectional sync)
- **Dev Cache**: `dev-cache:/home/developer/.cache` (persistent)
- **Ansible Data**: `dev-ansible:/home/developer/.ansible` (persistent)
- **Local Data**: `dev-local:/home/developer/.local` (persistent)
- **Docker Socket**: `/var/run/docker.sock` (for testing)
- **SSH Keys**: `~/.ssh:/home/developer/.ssh:ro` (read-only)

**Ports**:
- **8080**: Development server
- **9000**: Testing server

**Resource Limits**:
- **Memory**: 2GB
- **CPU**: 2.0 cores

### 📚 **Documentation Server (`docs`)**

**Purpose**: Live documentation server with auto-reload capability

**Features**:
- **MkDocs Integration**: Automatic detection and serving
- **Fallback Mode**: Basic HTTP server if MkDocs unavailable
- **Live Reload**: Automatic refresh on documentation changes
- **Material Theme**: Modern, responsive documentation interface

**Access**:
- **URL**: http://localhost:8000
- **Health Check**: Built-in service monitoring

**Supported Formats**:
- **Markdown**: `.md` files with MkDocs processing
- **Static Files**: HTML, CSS, JavaScript, images
- **API Docs**: Generated documentation

**Configuration**:
```bash
# Start documentation server
docker compose up docs

# View logs
docker compose logs -f docs

# Rebuild documentation
docker compose exec docs mkdocs build
```

### 🧪 **Testing Environment (`test`)**

**Purpose**: Isolated testing environment for safe validation

**Features**:
- **Isolation**: Read-only source mount prevents contamination
- **Clean State**: Fresh environment for each test run
- **Comprehensive Testing**: Full deployment validation
- **Separate Logging**: Dedicated log volume for test results

**Activation**:
```bash
# Start testing environment (profile-based)
docker compose --profile testing up test

# Run tests
docker compose exec test ./scripts/testing/test_installation.sh
docker compose exec test molecule test

# View test logs
docker compose exec test cat /workspace/logs/test-results.log
```

**Test Categories**:
- **Unit Tests**: Individual component testing
- **Integration Tests**: Full deployment testing
- **Ansible Tests**: Playbook and role validation
- **Security Tests**: Security configuration validation

### 📊 **Redis Cache (`redis`)**

**Purpose**: High-performance caching and task queue system

**Features**:
- **Version**: Redis 7 Alpine (lightweight)
- **Persistence**: AOF (Append Only File) enabled
- **Memory Management**: 256MB limit with LRU eviction
- **Health Monitoring**: Built-in health checks

**Configuration**:
```bash
# Redis configuration
--appendonly yes                    # Persistence enabled
--maxmemory 256mb                  # Memory limit
--maxmemory-policy allkeys-lru     # Eviction policy

# Access Redis CLI
docker compose exec redis redis-cli

# Monitor Redis
docker compose exec redis redis-cli monitor
```

**Use Cases**:
- **Deployment Caching**: Cache Ansible facts and results
- **Task Queues**: Background job processing
- **Session Storage**: Development session management
- **Performance Optimization**: Reduce repeated operations

### 🗄️ **PostgreSQL Database (`postgres`)**

**Purpose**: Relational database for development data management

**Features**:
- **Version**: PostgreSQL 15 Alpine
- **Database**: `arch_automation_dev`
- **User**: `developer` / `devpassword`
- **Authentication**: SCRAM-SHA-256 encryption

**Activation**:
```bash
# Start with database profile
docker compose --profile database up postgres

# Connect to database
docker compose exec postgres psql -U developer -d arch_automation_dev

# Database operations
docker compose exec postgres pg_dump -U developer arch_automation_dev
```

**Initialization**:
```bash
# Custom initialization scripts
./dev/database/init/
├── 01-create-tables.sql
├── 02-insert-data.sql
└── 03-create-indexes.sql
```

**Connection Details**:
- **Host**: `localhost`
- **Port**: `5432`
- **Database**: `arch_automation_dev`
- **Username**: `developer`
- **Password**: `devpassword`
- **Connection String**: `postgresql://developer:devpassword@localhost:5432/arch_automation_dev`

## 🛠️ **Development Workflows**

### 🏃 **Daily Development Workflow**

```bash
# 1. Start development environment
docker compose up -d dev docs

# 2. Access development container
docker compose exec dev bash

# 3. Check environment status
dev-info

# 4. Work with code
cd /workspace
git status
git pull origin main

# 5. Run development tasks
./scripts/deploy.sh full --dry-run
ansible-lint configs/ansible/
pytest tests/

# 6. Documentation workflow
# Edit docs/*.md files
# Visit http://localhost:8000 to see changes

# 7. Cleanup
exit
docker compose down
```

### 🧪 **Testing Workflow**

```bash
# 1. Start testing environment
docker compose --profile testing up -d test

# 2. Run comprehensive tests
docker compose exec test ./scripts/testing/test_installation.sh

# 3. Ansible-specific tests
docker compose exec test ansible-lint configs/ansible/
docker compose exec test molecule test

# 4. Custom test scenarios
docker compose exec test bash
# Inside container:
./scripts/deploy.sh full --dry-run --profile development
./scripts/testing/auto_vm_test.sh

# 5. View test results
docker compose exec test cat /workspace/logs/test-results.log

# 6. Cleanup testing environment
docker compose --profile testing down
```

### 📝 **Documentation Workflow**

```bash
# 1. Start documentation server
docker compose up -d docs

# 2. Edit documentation files
# docs/*.md, README.md, CLAUDE.md

# 3. View live changes
# http://localhost:8000

# 4. Build documentation
docker compose exec docs mkdocs build

# 5. Validate documentation
docker compose exec dev yamllint docs/
docker compose exec dev find docs/ -name "*.md" -exec markdownlint {} \;
```

### 🔄 **Code Quality Workflow**

```bash
# 1. Pre-commit setup
docker compose exec dev pre-commit install

# 2. Run quality checks
docker compose exec dev dev-lint

# 3. Individual tools
docker compose exec dev black --check .
docker compose exec dev flake8 scripts/
docker compose exec dev shellcheck scripts/**/*.sh
docker compose exec dev ansible-lint configs/ansible/

# 4. Auto-fix issues
docker compose exec dev black .
docker compose exec dev pre-commit run --all-files
```

## 🎛️ **Advanced Configuration**

### 🔧 **Environment Customization**

**User Configuration**:
```bash
# .env file for personal settings
USER_UID=1000                      # Your user ID
USER_GID=1000                      # Your group ID  
USERNAME=developer                 # Container username

# Docker Compose override
cp docker-compose.override.yml.example docker-compose.override.yml
# Edit override file for personal customizations
```

**Resource Adjustments**:
```yaml
# docker-compose.override.yml
services:
  dev:
    mem_limit: 4g                  # Increase memory
    cpus: 4.0                      # Increase CPU cores
    ports:
      - "8081:8080"                # Different port mapping
```

### 🔌 **Service Profiles**

**Available Profiles**:
- **Default**: `dev`, `docs`, `redis`
- **testing**: Adds `test` service
- **database**: Adds `postgres` service  
- **full**: All services (testing + database)

**Profile Usage**:
```bash
# Minimal development
docker compose up -d

# With testing
docker compose --profile testing up -d

# With database
docker compose --profile database up -d

# Everything
docker compose --profile testing --profile database up -d

# Custom profile combinations
docker compose --profile full up -d
```

### 🚀 **Performance Optimization**

**Volume Caching**:
```yaml
volumes:
  # Cached mount for better performance
  - .:/workspace:cached
  
  # Delegated mount for write-heavy operations
  - ./logs:/workspace/logs:delegated
```

**Resource Monitoring**:
```bash
# Monitor resource usage
docker stats

# Service-specific monitoring
docker compose exec dev htop
docker compose exec dev iotop
docker compose exec redis redis-cli info memory
```

**Build Optimization**:
```bash
# Multi-stage build for smaller images
docker compose build --no-cache

# Parallel builds
docker compose build --parallel

# BuildKit features
DOCKER_BUILDKIT=1 docker compose build
```

## 🔒 **Security Considerations**

### 🛡️ **Container Security**

**Principle of Least Privilege**:
- Non-root user for development operations
- Read-only mounts where appropriate
- Limited capability grants
- Network isolation

**Sensitive Data Handling**:
```bash
# SSH keys mounted read-only
~/.ssh:/home/developer/.ssh:ro

# Environment-based secrets
DEPLOY_USER_PASSWORD=${DEPLOY_PASSWORD}

# Encrypted configuration files
./scripts/utils/passwords.sh create-file dev-passwords.enc
```

**Network Security**:
- Isolated development network (`172.20.0.0/16`)
- No exposure of internal services
- Controlled port mappings
- Health check monitoring

### 🔐 **Development Security Best Practices**

**Secret Management**:
```bash
# Never commit secrets to version control
echo "*.env" >> .gitignore
echo "dev-passwords.enc" >> .gitignore

# Use environment variables
export DEPLOY_USER_PASSWORD="secure_password"
docker compose up -d
```

**Docker Socket Access**:
```yaml
# Controlled Docker socket mounting for testing
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  
# Security implications:
# - Container can control Docker daemon
# - Only for development/testing
# - Never in production environments
```

## 🐛 **Troubleshooting Guide**

### 🚨 **Common Issues**

**Container Won't Start**:
```bash
# Check Docker daemon
sudo systemctl status docker
sudo systemctl start docker

# Check for resource constraints
docker system df
docker system prune

# Rebuild without cache
docker compose build --no-cache dev
```

**Port Conflicts**:
```bash
# Check port usage
netstat -tulpn | grep -E ':(8000|8080|9000|5432|6379)'

# Kill conflicting processes
sudo lsof -ti:8080 | xargs kill -9

# Use different ports
# Edit docker-compose.override.yml
```

**Permission Issues**:
```bash
# Fix user ID mismatch
export USER_UID=$(id -u)
export USER_GID=$(id -g)
docker compose down
docker compose build dev
docker compose up -d dev

# Fix volume permissions
docker compose exec dev sudo chown -R developer:developer /workspace
```

**Volume Issues**:
```bash
# Reset all volumes
docker compose down -v
docker volume prune -f

# Inspect volume contents
docker volume inspect arch-desktop-dev-cache
docker run --rm -v arch-desktop-dev-cache:/volume alpine ls -la /volume
```

**Memory/Performance Issues**:
```bash
# Monitor resource usage
docker stats --no-stream

# Increase resource limits
# Edit docker-compose.yml or override file

# Clean up system resources
docker system prune -af
```

### 🔍 **Debugging Techniques**

**Container Debugging**:
```bash
# Access container directly
docker compose exec dev bash

# Check container logs
docker compose logs dev
docker compose logs --tail=50 -f dev

# Inspect container configuration
docker compose exec dev env
docker compose exec dev ps aux
```

**Service Health Checks**:
```bash
# Check service health
docker compose ps
docker compose exec dev python -c "import ansible; print('OK')"
docker compose exec redis redis-cli ping
docker compose exec postgres pg_isready -U developer
```

**Network Debugging**:
```bash
# Check network connectivity
docker compose exec dev ping docs
docker compose exec dev curl -I http://docs:8000
docker compose exec dev nslookup redis

# Inspect network configuration
docker network inspect arch-desktop-dev-network
```

## 📈 **Performance Monitoring**

### 📊 **Metrics Collection**

**Resource Monitoring**:
```bash
# Real-time stats
docker stats

# Historical data
docker compose exec dev htop
docker compose exec dev iotop -o

# Memory usage
docker compose exec dev free -h
docker compose exec redis redis-cli info memory
```

**Application Performance**:
```bash
# Ansible performance
docker compose exec dev time ansible-playbook --check local.yml

# Deployment timing
docker compose exec dev ./scripts/deploy.sh full --dry-run --verbose

# Test execution time
docker compose exec test time ./scripts/testing/test_installation.sh
```

### 📋 **Performance Benchmarks**

**Expected Performance Metrics**:
- **Container Startup**: < 30 seconds
- **Documentation Build**: < 5 seconds
- **Ansible Lint**: < 15 seconds
- **Full Deployment Check**: < 2 minutes
- **Test Suite**: < 5 minutes

**Optimization Targets**:
- **Memory Usage**: < 2GB per development container
- **Build Time**: < 5 minutes for full rebuild
- **Volume Sync**: < 1 second for file changes

## 🔄 **Maintenance and Updates**

### 🔧 **Regular Maintenance**

**Daily Tasks**:
```bash
# Pull latest images
docker compose pull

# Clean up unused resources
docker system prune

# Update dependencies
docker compose exec dev pip install --upgrade -r requirements.txt
```

**Weekly Tasks**:
```bash
# Rebuild development images
docker compose build --no-cache

# Update base images
docker pull archlinux:latest
docker pull redis:7-alpine
docker pull postgres:15-alpine

# Backup persistent volumes
docker run --rm -v arch-desktop-dev-cache:/source -v $(pwd)/backups:/backup alpine tar czf /backup/dev-cache-$(date +%Y%m%d).tar.gz -C /source .
```

**Monthly Tasks**:
```bash
# Security updates
docker compose exec dev sudo pacman -Syu

# Clean up old data
docker volume prune
docker image prune -a

# Review resource usage
docker system df
```

### 🚀 **Version Updates**

**Updating Docker Compose Configuration**:
```bash
# Backup current configuration
cp docker-compose.yml docker-compose.yml.backup

# Test new configuration
docker compose config

# Gradual rollout
docker compose up -d dev
# Verify dev service
docker compose up -d docs
# Verify all services
```

**Updating Development Tools**:
```bash
# Update Dockerfile.dev
# Test build process
docker compose build --no-cache dev

# Update requirements.txt
docker compose exec dev pip list --outdated
docker compose exec dev pip install --upgrade package_name
```

## 🎓 **Best Practices**

### 👨‍💻 **Development Best Practices**

**Container Usage**:
- Use containers for all development work
- Keep host system clean
- Mount SSH keys read-only
- Use volume caching for performance

**Code Quality**:
- Run linters before commits
- Use pre-commit hooks
- Test in isolated environment
- Document changes thoroughly

**Resource Management**:
- Monitor resource usage regularly
- Clean up unused containers/volumes
- Use appropriate resource limits
- Optimize Docker images

### 🔄 **Workflow Best Practices**

**Daily Development**:
1. Start with `docker compose up -d dev docs`
2. Work within development container
3. Use documentation server for reference
4. Test changes in isolated environment
5. Clean up when finished

**Collaboration**:
- Share docker-compose.override.yml templates
- Document custom configurations
- Use consistent environment variables
- Version control all configurations

**Testing Strategy**:
- Test in clean environments
- Use read-only mounts for testing
- Separate test data from development data
- Automate testing workflows

## 📚 **Additional Resources**

### 📖 **Documentation Links**

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Arch Linux Container Documentation](https://wiki.archlinux.org/title/Docker)
- [VSCode Dev Containers](https://code.visualstudio.com/docs/remote/containers)
- [Ansible in Containers](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#running-ansible-inside-docker)

### 🔗 **Project-Specific Documentation**

- [Installation Guide](./installation-guide.md)
- [Password Management](./password-management.md)
- [Development Instructions](./development-instructions.md)
- [VirtualBox Testing Guide](./virtualbox-testing-guide.md)

### 🛠️ **Tool Documentation**

- **Development Container**: See `/dev/README.md`
- **DevContainer Configuration**: See `/.devcontainer/README.md`
- **Testing Framework**: See `/scripts/testing/README.md`
- **Security Setup**: See `/scripts/security/README.md`

---

**Next Steps**: After setting up your Docker Compose development environment, consider exploring:
- [DevContainer Setup](./.devcontainer/README.md) for VSCode integration
- [Testing Guide](./virtualbox-testing-guide.md) for comprehensive testing
- [Deployment Guide](./installation-guide.md) for production deployment