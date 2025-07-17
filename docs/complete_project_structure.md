# Complete Arch Linux Hyprland Automation Project Structure

```
lm_archlinux_desktop/
├── README.md
├── LICENSE
├── .gitignore
├── requirements.txt
├── Makefile
├── CHANGELOG.md
├── docs/
│   ├── README.md
│   ├── installation-guide.md
│   ├── troubleshooting.md
│   ├── configuration-reference.md
│   ├── security-guide.md
│   └── contributing.md
├── configs/
│   ├── archinstall/
│   │   ├── user_configuration.json
│   │   ├── user_credentials.json
│   │   ├── hardware_profiles/
│   │   │   ├── intel_laptop.json
│   │   │   ├── amd_desktop.json
│   │   │   └── nvidia_workstation.json
│   │   └── post_install_hooks/
│   │       ├── base_setup.sh
│   │       ├── tpm2_setup.sh
│   │       └── ansible_bootstrap.sh
│   ├── ansible/
│   │   ├── ansible.cfg
│   │   ├── requirements.yml
│   │   ├── inventory/
│   │   │   ├── localhost.yml
│   │   │   ├── production.yml
│   │   │   └── development.yml
│   │   ├── group_vars/
│   │   │   ├── all/
│   │   │   │   ├── vars.yml
│   │   │   │   └── vault.yml
│   │   │   ├── desktops/
│   │   │   │   └── vars.yml
│   │   │   └── laptops/
│   │   │       └── vars.yml
│   │   ├── host_vars/
│   │   │   └── phoenix/
│   │   │       ├── vars.yml
│   │   │       └── vault.yml
│   │   ├── playbooks/
│   │   │   ├── site.yml
│   │   │   ├── bootstrap.yml
│   │   │   ├── desktop.yml
│   │   │   ├── security.yml
│   │   │   ├── maintenance.yml
│   │   │   └── validate.yml
│   │   ├── roles/
│   │   │   ├── base_system/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   ├── pacman.conf
│   │   │   │   │   └── mirrorlist
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── packages.yml
│   │   │   │   │   ├── services.yml
│   │   │   │   │   └── locale.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── locale.conf.j2
│   │   │   │   │   ├── vconsole.conf.j2
│   │   │   │   │   └── zram-generator.conf.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── users_security/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   └── ssh_banner
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── users.yml
│   │   │   │   │   ├── sudo.yml
│   │   │   │   │   ├── ssh.yml
│   │   │   │   │   └── pam.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── sudoers.j2
│   │   │   │   │   ├── sshd_config.j2
│   │   │   │   │   └── login.defs.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── hyprland_desktop/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   ├── wallpapers/
│   │   │   │   │   │   ├── default.jpg
│   │   │   │   │   │   └── dark.jpg
│   │   │   │   │   └── fonts/
│   │   │   │   │       └── JetBrainsMono.ttf
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── packages.yml
│   │   │   │   │   ├── hyprland.yml
│   │   │   │   │   ├── waybar.yml
│   │   │   │   │   ├── audio.yml
│   │   │   │   │   ├── sddm.yml
│   │   │   │   │   └── xdg.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── hyprland/
│   │   │   │   │   │   ├── hyprland.conf.j2
│   │   │   │   │   │   ├── hyprlock.conf.j2
│   │   │   │   │   │   └── hypridle.conf.j2
│   │   │   │   │   ├── waybar/
│   │   │   │   │   │   ├── config.jsonc.j2
│   │   │   │   │   │   └── style.css.j2
│   │   │   │   │   ├── wofi/
│   │   │   │   │   │   ├── config.j2
│   │   │   │   │   │   └── style.css.j2
│   │   │   │   │   ├── kitty/
│   │   │   │   │   │   └── kitty.conf.j2
│   │   │   │   │   ├── mako/
│   │   │   │   │   │   └── config.j2
│   │   │   │   │   ├── sddm/
│   │   │   │   │   │   └── sddm.conf.j2
│   │   │   │   │   └── xdg/
│   │   │   │   │       └── hyprland-portals.conf.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── aur_packages/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   └── yay_config.json
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── yay.yml
│   │   │   │   │   ├── packages.yml
│   │   │   │   │   └── security.yml
│   │   │   │   ├── templates/
│   │   │   │   │   └── makepkg.conf.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── system_hardening/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   ├── audit.rules
│   │   │   │   │   └── blacklist.conf
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── kernel.yml
│   │   │   │   │   ├── firewall.yml
│   │   │   │   │   ├── audit.yml
│   │   │   │   │   ├── fail2ban.yml
│   │   │   │   │   └── selinux.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── sysctl.d/
│   │   │   │   │   │   └── 99-security.conf.j2
│   │   │   │   │   ├── nftables.conf.j2
│   │   │   │   │   ├── fail2ban/
│   │   │   │   │   │   └── jail.local.j2
│   │   │   │   │   └── audit/
│   │   │   │   │       └── auditd.conf.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── power_management/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   └── power_profiles.conf
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── tlp.yml
│   │   │   │   │   ├── thermald.yml
│   │   │   │   │   ├── cpupower.yml
│   │   │   │   │   └── hibernation.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── tlp.conf.j2
│   │   │   │   │   └── cpupower.conf.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── development_tools/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   └── vscode_extensions.txt
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── languages.yml
│   │   │   │   │   ├── editors.yml
│   │   │   │   │   └── tools.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── gitconfig.j2
│   │   │   │   │   └── vscode_settings.json.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   ├── monitoring/
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files/
│   │   │   │   │   └── prometheus.yml
│   │   │   │   ├── handlers/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── meta/
│   │   │   │   │   └── main.yml
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── metrics.yml
│   │   │   │   │   └── alerts.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── health_check.sh.j2
│   │   │   │   │   └── system_monitor.service.j2
│   │   │   │   └── vars/
│   │   │   │       └── main.yml
│   │   │   └── user_environment/
│   │   │       ├── defaults/
│   │   │       │   └── main.yml
│   │   │       ├── files/
│   │   │       │   ├── bashrc
│   │   │       │   └── vimrc
│   │   │       ├── handlers/
│   │   │       │   └── main.yml
│   │   │       ├── meta/
│   │   │       │   └── main.yml
│   │   │       ├── tasks/
│   │   │       │   ├── main.yml
│   │   │       │   ├── dotfiles.yml
│   │   │       │   ├── shell.yml
│   │   │       │   └── themes.yml
│   │   │       ├── templates/
│   │   │       │   ├── bashrc.j2
│   │   │       │   ├── zshrc.j2
│   │   │       │   └── starship.toml.j2
│   │   │       └── vars/
│   │   │           └── main.yml
│   │   └── filters/
│   │       └── custom_filters.py
│   └── profiles/
│       ├── work/
│       │   ├── archinstall/
│       │   │   └── user_configuration.json
│       │   └── ansible/
│       │       └── vars.yml
│       ├── personal/
│       │   ├── archinstall/
│       │   │   └── user_configuration.json
│       │   └── ansible/
│       │       └── vars.yml
│       └── development/
│           ├── archinstall/
│           │   └── user_configuration.json
│           └── ansible/
│               └── vars.yml
├── scripts/
│   ├── bootstrap/
│   │   ├── bootstrap.sh
│   │   ├── prepare_usb.sh
│   │   ├── validate_hardware.sh
│   │   ├── network_setup.sh
│   │   └── first_boot_setup.sh
│   ├── deployment/
│   │   ├── master_deploy.sh
│   │   ├── ansible_pull.sh
│   │   ├── create_deployment_usb.sh
│   │   ├── profile_manager.sh
│   │   └── rollback.sh
│   ├── maintenance/
│   │   ├── backup_system.sh
│   │   ├── update_system.sh
│   │   ├── health_check.sh
│   │   ├── log_rotation.sh
│   │   └── cleanup.sh
│   ├── security/
│   │   ├── security_audit.sh
│   │   ├── setup_tpm2.sh
│   │   ├── firewall_test.sh
│   │   └── generate_keys.sh
│   ├── utilities/
│   │   ├── config_backup.sh
│   │   ├── package_manager.sh
│   │   ├── service_manager.sh
│   │   └── log_analyzer.sh
│   └── testing/
│       ├── test_installation.sh
│       ├── test_desktop.sh
│       ├── test_security.sh
│       └── integration_tests.sh
├── templates/
│   ├── systemd/
│   │   ├── services/
│   │   │   ├── first-boot-setup.service.j2
│   │   │   ├── automation-pull.service.j2
│   │   │   ├── health-check.service.j2
│   │   │   └── backup.service.j2
│   │   ├── timers/
│   │   │   ├── automation-pull.timer.j2
│   │   │   ├── health-check.timer.j2
│   │   │   └── backup.timer.j2
│   │   └── targets/
│   │       └── desktop.target.j2
│   ├── configs/
│   │   ├── environment.j2
│   │   ├── locale.conf.j2
│   │   └── hostname.j2
│   ├── udev/
│   │   └── rules.d/
│   │       └── 99-custom.rules.j2
│   └── dbus/
│       └── session.conf.j2
├── files/
│   ├── wallpapers/
│   │   ├── default.jpg
│   │   ├── dark.jpg
│   │   └── light.jpg
│   ├── fonts/
│   │   ├── JetBrainsMono/
│   │   │   └── JetBrainsMono-Regular.ttf
│   │   └── NerdFonts/
│   │       └── FiraCode-Regular.ttf
│   ├── themes/
│   │   ├── gtk/
│   │   │   └── Adwaita-dark/
│   │   └── icons/
│   │       └── Papirus/
│   ├── keymaps/
│   │   ├── us.map
│   │   └── fr.map
│   ├── certificates/
│   │   └── ca-certificates.crt
│   └── scripts/
│       ├── autostart/
│       │   └── desktop_startup.sh
│       └── helpers/
│           └── display_manager.sh
├── tests/
│   ├── unit/
│   │   ├── test_roles.py
│   │   ├── test_configs.py
│   │   └── test_scripts.py
│   ├── integration/
│   │   ├── test_full_deployment.py
│   │   ├── test_security.py
│   │   └── test_desktop.py
│   ├── fixtures/
│   │   ├── test_data/
│   │   └── mock_configs/
│   ├── ansible/
│   │   ├── test_playbook.yml
│   │   └── test_inventory.yml
│   └── validation/
│       ├── validate_archinstall.py
│       ├── validate_ansible.py
│       └── validate_system.py
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   │       └── system.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── system.json
│   │   │   └── desktop.json
│   │   └── datasources/
│   │       └── prometheus.yml
│   └── scripts/
│       ├── collect_metrics.sh
│       └── alert_handler.sh
├── backup/
│   ├── configs/
│   │   └── .gitkeep
│   ├── user_data/
│   │   └── .gitkeep
│   └── logs/
│       └── .gitkeep
├── logs/
│   ├── installation/
│   │   └── .gitkeep
│   ├── deployment/
│   │   └── .gitkeep
│   ├── maintenance/
│   │   └── .gitkeep
│   └── security/
│       └── .gitkeep
├── tools/
│   ├── ansible-lint.yml
│   ├── pre-commit-config.yaml
│   ├── editorconfig
│   └── gitattributes
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── security-scan.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
├── .vscode/
│   ├── settings.json
│   ├── extensions.json
│   └── tasks.json
└── misc/
    ├── examples/
    │   ├── custom_roles/
    │   └── advanced_configs/
    ├── contrib/
    │   └── community_scripts/
    └── legacy/
        └── old_configs/
```

## Key File Contents

### Root Configuration Files

**requirements.txt**
```txt
ansible>=8.0.0
ansible-core>=2.15.0
jinja2>=3.1.0
PyYAML>=6.0
cryptography>=41.0.0
passlib>=1.7.4
```

**Makefile**
```makefile
.PHONY: install test deploy clean

install:
	pip install -r requirements.txt
	ansible-galaxy collection install -r configs/ansible/requirements.yml

test:
	ansible-playbook --syntax-check configs/ansible/playbooks/site.yml
	python -m pytest tests/

deploy:
	./scripts/deployment/master_deploy.sh full

clean:
	rm -rf logs/*
	rm -rf backup/configs/*
	rm -rf backup/user_data/*

validate:
	ansible-lint configs/ansible/playbooks/
	python tests/validation/validate_system.py

usb:
	sudo ./scripts/bootstrap/prepare_usb.sh

health:
	./scripts/maintenance/health_check.sh
```

**.gitignore**
```gitignore
# Sensitive files
configs/ansible/group_vars/all/vault.yml
configs/ansible/host_vars/*/vault.yml
configs/archinstall/user_credentials.json
*.key
*.pem
*.p12

# Logs
logs/
*.log

# Backup files
backup/configs/*
backup/user_data/*
!backup/*/.gitkeep

# Temporary files
*.tmp
*.temp
.cache/
.ansible/

# IDE files
.vscode/settings.json
.idea/

# OS files
.DS_Store
Thumbs.db

# Build artifacts
build/
dist/
*.iso
*.img
```

### Essential Configuration Files

**configs/ansible/ansible.cfg**
```ini
[defaults]
inventory = inventory/localhost.yml
roles_path = ./roles
collections_paths = ./collections
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache
fact_caching_timeout = 3600
forks = 50
pipelining = True
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer
ask_vault_pass = True
vault_password_file = ~/.ansible_vault_pass

[inventory]
enable_plugins = yaml, ini, auto

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

**configs/ansible/requirements.yml**
```yaml
---
collections:
  - name: community.general
    version: ">=8.0.0"
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.crypto
    version: ">=2.0.0"
  - name: kewlfft.aur
    version: ">=0.11.0"
  - name: community.archlinux
    version: ">=0.3.0"
```

**configs/ansible/group_vars/all/vars.yml**
```yaml
---
# System Configuration
system_hostname: phoenix
system_user: lyeosmaouli
system_locale: en_US.UTF-8
system_timezone: Europe/Paris
keyboard_layout: us

# Hardware Configuration
gpu_driver: intel
audio_system: pipewire
network_manager: NetworkManager

# Security Configuration
encryption_enabled: true
tpm2_enabled: true
firewall_enabled: true
audit_enabled: true
selinux_enabled: false

# Desktop Configuration
desktop_environment: hyprland
display_manager: sddm
terminal_emulator: kitty
file_manager: thunar
web_browser: firefox

# Development Configuration
development_tools_enabled: true
aur_enabled: true
docker_enabled: true
```

### Key Script Files

**scripts/bootstrap/bootstrap.sh** (Main bootstrap script)
**scripts/deployment/master_deploy.sh** (Master deployment orchestrator)
**scripts/maintenance/health_check.sh** (System health monitoring)
**scripts/security/security_audit.sh** (Security validation)

## Usage Instructions

### Initial Setup
```bash
# Clone repository
git clone https://github.com/LyeosMaouli/lm_archlinux_desktop.git
cd lm_archlinux_desktop

# Install dependencies
make install

# Customize configuration
cp configs/profiles/work/ansible/vars.yml configs/ansible/group_vars/all/vars.yml
vim configs/archinstall/user_configuration.json

# Create encrypted credentials
ansible-vault create configs/ansible/group_vars/all/vault.yml
```

### Full Deployment
```bash
# Create deployment USB
make usb

# Deploy complete system
make deploy

# Validate installation
make validate

# Check system health
make health
```

### Maintenance
```bash
# Update system
./scripts/maintenance/update_system.sh

# Backup system
./scripts/maintenance/backup_system.sh

# Security audit
./scripts/security/security_audit.sh
```

This structure provides a complete, production-ready automation system with proper separation of concerns, comprehensive testing, monitoring, and maintenance capabilities.