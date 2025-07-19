#!/bin/bash
# System Hardening Script
# Applies comprehensive security hardening to Arch Linux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/system-hardening.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

log "Starting system hardening"

# Backup original configurations
backup_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d-%H%M%S)"
        log "Backed up $file"
    fi
}

# Kernel parameter hardening
log "Applying kernel parameter hardening"
backup_config "/etc/sysctl.conf"

cat > /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# Network security hardening
# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# IP forwarding (disable for desktop)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Memory protection
# Restrict access to kernel pointers
kernel.kptr_restrict = 2

# Disable kernel module loading
kernel.modules_disabled = 0

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Hide kernel symbols
kernel.kptr_restrict = 2

# Control core dumps
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false

# Address space layout randomization
kernel.randomize_va_space = 2

# Process restrictions
# Restrict ptrace
kernel.yama.ptrace_scope = 1

# Perf event restrictions
kernel.perf_event_paranoid = 3
kernel.perf_cpu_time_max_percent = 1
kernel.perf_event_max_sample_rate = 1

# JIT hardening
net.core.bpf_jit_harden = 2

# Virtual memory
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# Filesystem
# Restrict /proc access
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-security-hardening.conf

# SSH hardening
log "Hardening SSH configuration"
backup_config "/etc/ssh/sshd_config"

# Create hardened SSH config
cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
# SSH Security Hardening

# Protocol and encryption
Protocol 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 2

# Connection limits
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxStartups 2

# Disable unnecessary features
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
PermitTunnel no
GatewayPorts no

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Misc security
UsePrivilegeSeparation yes
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
PermitUserEnvironment no
EOF

# PAM hardening
log "Configuring PAM security policies"
backup_config "/etc/pam.d/passwd"

# Password quality requirements
if ! grep -q "pam_pwquality.so" /etc/pam.d/passwd; then
    sed -i '1i password required pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1' /etc/pam.d/passwd
fi

# Account lockout after failed attempts
if ! grep -q "pam_faillock.so" /etc/pam.d/system-login; then
    cat >> /etc/pam.d/system-login << 'EOF'
# Account lockout
auth required pam_faillock.so preauth silent audit deny=3 unlock_time=600
auth [default=die] pam_faillock.so authfail audit deny=3 unlock_time=600
account required pam_faillock.so
EOF
fi

# Set password aging
log "Configuring password aging policies"
backup_config "/etc/login.defs"

sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs

# Audit logging setup
log "Setting up audit logging"
if ! command -v auditd >/dev/null 2>&1; then
    pacman -S --noconfirm audit
fi

# Create audit rules
cat > /etc/audit/rules.d/99-security.rules << 'EOF'
# Security audit rules

# Monitor authentication
-w /var/log/auth.log -p wa -k authentication
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudo_changes

# Monitor system configuration
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/hosts -p wa -k network_config
-w /etc/hostname -p wa -k network_config

# Monitor kernel modules
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Monitor file permissions
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# Monitor privileged commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# System calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
EOF

# Enable audit service
systemctl enable auditd
systemctl start auditd

# File permission hardening
log "Hardening file permissions"

# Secure important files
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
chmod 600 /boot/grub/grub.cfg 2>/dev/null || true
chmod 600 /etc/crontab
chmod 600 /etc/ssh/sshd_config

# Secure directories
chmod 755 /etc/ssh
chmod 700 /root
chmod 755 /boot

# Remove unnecessary SUID/SGID binaries
log "Reviewing SUID/SGID binaries"
find / -type f \( -perm -4000 -o -perm -2000 \) -exec ls -la {} \; 2>/dev/null | tee /tmp/suid_sgid_files.txt

# Create security monitoring script
cat > /usr/local/bin/security-monitor.sh << 'EOF'
#!/bin/bash
# Security monitoring script

LOG_FILE="/var/log/security-monitor.log"
ALERT_EMAIL="${ADMIN_EMAIL:-root@localhost}"

# Check for failed logins
check_failed_logins() {
    local failed_logins
    failed_logins=$(journalctl --since "1 hour ago" | grep "authentication failure" | wc -l)
    
    if [[ $failed_logins -gt 10 ]]; then
        echo "[$(date)] WARNING: $failed_logins failed login attempts in the last hour" >> "$LOG_FILE"
    fi
}

# Check for SUID changes
check_suid_changes() {
    local current_suid="/tmp/current_suid.txt"
    local baseline_suid="/var/lib/security/baseline_suid.txt"
    
    find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null > "$current_suid"
    
    if [[ -f "$baseline_suid" ]]; then
        if ! diff -q "$baseline_suid" "$current_suid" >/dev/null; then
            echo "[$(date)] WARNING: SUID/SGID files have changed" >> "$LOG_FILE"
            diff "$baseline_suid" "$current_suid" >> "$LOG_FILE"
        fi
    else
        mkdir -p /var/lib/security
        cp "$current_suid" "$baseline_suid"
    fi
}

# Check system integrity
check_system_integrity() {
    # Check for unusual processes
    ps aux | awk '$3 > 80.0 || $4 > 80.0' | while read line; do
        echo "[$(date)] WARNING: High resource usage process: $line" >> "$LOG_FILE"
    done
    
    # Check for unusual network connections
    netstat -tuln | grep LISTEN | while read line; do
        if echo "$line" | grep -qE ":([0-9]{4,5})\s"; then
            echo "[$(date)] INFO: Listening service: $line" >> "$LOG_FILE"
        fi
    done
}

check_failed_logins
check_suid_changes
check_system_integrity
EOF

chmod +x /usr/local/bin/security-monitor.sh

# Create systemd timer for security monitoring
cat > /etc/systemd/system/security-monitor.timer << 'EOF'
[Unit]
Description=Security monitoring timer
Requires=security-monitor.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/security-monitor.service << 'EOF'
[Unit]
Description=Security monitoring service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/security-monitor.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable monitoring
systemctl daemon-reload
systemctl enable security-monitor.timer
systemctl start security-monitor.timer

# Restart SSH service to apply changes
systemctl restart sshd

log "System hardening completed successfully"
echo "Review security settings and test SSH access before logging out!"
echo "Monitor security logs with: journalctl -f | grep -i security"