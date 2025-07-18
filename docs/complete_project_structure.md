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
