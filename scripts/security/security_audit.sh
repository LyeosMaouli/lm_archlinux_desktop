#!/bin/bash
# Security Audit Script
# Performs comprehensive security assessment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="/var/log/security-audit-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$REPORT_FILE"
}

header() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=================================================================================" | tee -a "$REPORT_FILE"
    echo "  $1" | tee -a "$REPORT_FILE"
    echo "=================================================================================" | tee -a "$REPORT_FILE"
}

check_status() {
    local status="$1"
    local message="$2"
    
    if [[ "$status" == "PASS" ]]; then
        echo "[SUCCESS] PASS: $message" | tee -a "$REPORT_FILE"
    elif [[ "$status" == "FAIL" ]]; then
        echo "[ERROR] FAIL: $message" | tee -a "$REPORT_FILE"
    elif [[ "$status" == "WARN" ]]; then
        echo "[WARNING]  WARN: $message" | tee -a "$REPORT_FILE"
    else
        echo "ℹ️  INFO: $message" | tee -a "$REPORT_FILE"
    fi
}

log "Starting security audit"

header "SYSTEM INFORMATION"
log "Hostname: $(hostname)"
log "Kernel: $(uname -r)"
log "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
log "Uptime: $(uptime -p)"
log "Last boot: $(who -b | awk '{print $3, $4}')"

header "USER ACCOUNTS AUDIT"

# Check for accounts with UID 0
log "Checking for accounts with UID 0..."
uid_0_accounts=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
if [[ "$uid_0_accounts" == "root" ]]; then
    check_status "PASS" "Only root account has UID 0"
else
    check_status "FAIL" "Multiple accounts with UID 0: $uid_0_accounts"
fi

# Check for accounts without passwords
log "Checking for accounts without passwords..."
no_password=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null | wc -l)
if [[ $no_password -eq 0 ]]; then
    check_status "PASS" "No accounts without passwords"
else
    check_status "FAIL" "$no_password accounts without passwords"
fi

# Check for inactive users
log "Checking for user activity..."
while IFS=: read -r username _ uid _ _ home shell; do
    if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
        last_login=$(last -1 "$username" 2>/dev/null | head -1 | awk '{print $4, $5, $6}')
        if [[ -z "$last_login" || "$last_login" == "wtmp" ]]; then
            check_status "WARN" "User $username has never logged in"
        fi
    fi
done < /etc/passwd

header "PASSWORD POLICY AUDIT"

# Check password aging
log "Checking password aging policies..."
max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
min_days=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')
warn_days=$(grep "^PASS_WARN_AGE" /etc/login.defs | awk '{print $2}')

if [[ $max_days -le 90 ]]; then
    check_status "PASS" "Password max age: $max_days days"
else
    check_status "WARN" "Password max age too high: $max_days days"
fi

if [[ $min_days -ge 1 ]]; then
    check_status "PASS" "Password min age: $min_days days"
else
    check_status "WARN" "Password min age too low: $min_days days"
fi

header "SSH CONFIGURATION AUDIT"

# Check SSH configuration
log "Auditing SSH configuration..."

if systemctl is-active --quiet sshd; then
    check_status "INFO" "SSH service is running"
    
    # Check SSH settings
    ssh_config="/etc/ssh/sshd_config"
    
    # Root login
    if grep -q "^PermitRootLogin no" "$ssh_config"* 2>/dev/null; then
        check_status "PASS" "Root login disabled"
    else
        check_status "FAIL" "Root login not properly disabled"
    fi
    
    # Password authentication
    if grep -q "^PasswordAuthentication no" "$ssh_config"* 2>/dev/null; then
        check_status "PASS" "Password authentication disabled"
    else
        check_status "WARN" "Password authentication enabled"
    fi
    
    # Protocol version
    if grep -q "^Protocol 2" "$ssh_config"* 2>/dev/null; then
        check_status "PASS" "SSH Protocol 2 enforced"
    else
        check_status "INFO" "SSH Protocol setting not explicitly set"
    fi
else
    check_status "INFO" "SSH service is not running"
fi

header "FIREWALL AUDIT"

# Check UFW status
log "Checking firewall status..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        check_status "PASS" "UFW firewall is active"
        
        # Check default policies
        if ufw status verbose | grep -q "Default: deny (incoming)"; then
            check_status "PASS" "Default incoming policy is deny"
        else
            check_status "FAIL" "Default incoming policy is not deny"
        fi
        
        if ufw status verbose | grep -q "Default: allow (outgoing)"; then
            check_status "PASS" "Default outgoing policy is allow"
        else
            check_status "WARN" "Default outgoing policy is not allow"
        fi
    else
        check_status "FAIL" "UFW firewall is not active"
    fi
else
    check_status "FAIL" "UFW firewall is not installed"
fi

# Check fail2ban
if systemctl is-active --quiet fail2ban; then
    check_status "PASS" "Fail2ban is running"
    
    # Check jail status
    active_jails=$(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr ',' '\n' | wc -l)
    if [[ $active_jails -gt 0 ]]; then
        check_status "PASS" "$active_jails fail2ban jails active"
    else
        check_status "WARN" "No fail2ban jails active"
    fi
else
    check_status "WARN" "Fail2ban is not running"
fi

header "FILE PERMISSIONS AUDIT"

# Check critical file permissions
log "Checking critical file permissions..."

critical_files=(
    "/etc/passwd:644"
    "/etc/shadow:640"
    "/etc/group:644"
    "/etc/gshadow:640"
    "/etc/sudoers:440"
    "/etc/ssh/sshd_config:600"
    "/boot/grub/grub.cfg:600"
)

for file_perm in "${critical_files[@]}"; do
    file="${file_perm%:*}"
    expected_perm="${file_perm#*:}"
    
    if [[ -f "$file" ]]; then
        actual_perm=$(stat -c "%a" "$file")
        if [[ "$actual_perm" == "$expected_perm" ]]; then
            check_status "PASS" "$file has correct permissions ($actual_perm)"
        else
            check_status "FAIL" "$file has incorrect permissions ($actual_perm, expected $expected_perm)"
        fi
    else
        check_status "INFO" "$file does not exist"
    fi
done

header "SUID/SGID AUDIT"

# Check for unusual SUID/SGID files
log "Checking for SUID/SGID files..."
suid_count=$(find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
check_status "INFO" "Found $suid_count SUID/SGID files"

# List unusual SUID files
unusual_suid=$(find / -type f -perm -4000 2>/dev/null | grep -vE "(sudo|su|ping|mount|umount|passwd|chsh|chfn|newgrp|gpasswd)" || true)
if [[ -n "$unusual_suid" ]]; then
    check_status "WARN" "Unusual SUID files found:"
    echo "$unusual_suid" | while read file; do
        echo "  - $file" | tee -a "$REPORT_FILE"
    done
fi

header "NETWORK SECURITY AUDIT"

# Check listening services
log "Checking listening services..."
listening_services=$(netstat -tuln 2>/dev/null | grep LISTEN | wc -l)
check_status "INFO" "$listening_services services listening on network"

# List all listening services
netstat -tuln 2>/dev/null | grep LISTEN | while read line; do
    echo "  $line" | tee -a "$REPORT_FILE"
done

# Check for promiscuous network interfaces
log "Checking for promiscuous network interfaces..."
promiscuous=$(ip link show | grep PROMISC | wc -l)
if [[ $promiscuous -eq 0 ]]; then
    check_status "PASS" "No promiscuous network interfaces"
else
    check_status "WARN" "$promiscuous promiscuous network interfaces found"
fi

header "SYSTEM INTEGRITY AUDIT"

# Check for world-writable files
log "Checking for world-writable files..."
world_writable=$(find / -type f -perm -002 2>/dev/null | grep -v "/proc/" | grep -v "/sys/" | wc -l)
if [[ $world_writable -eq 0 ]]; then
    check_status "PASS" "No world-writable files found"
else
    check_status "WARN" "$world_writable world-writable files found"
fi

# Check for files without owner
log "Checking for orphaned files..."
orphaned_files=$(find / -nouser -o -nogroup 2>/dev/null | grep -v "/proc/" | grep -v "/sys/" | wc -l)
if [[ $orphaned_files -eq 0 ]]; then
    check_status "PASS" "No orphaned files found"
else
    check_status "WARN" "$orphaned_files orphaned files found"
fi

header "KERNEL SECURITY AUDIT"

# Check kernel parameters
log "Checking security-relevant kernel parameters..."

security_params=(
    "net.ipv4.ip_forward:0"
    "net.ipv4.conf.all.rp_filter:1"
    "net.ipv4.conf.all.accept_redirects:0"
    "net.ipv4.conf.all.send_redirects:0"
    "kernel.dmesg_restrict:1"
    "kernel.kptr_restrict:2"
)

for param_value in "${security_params[@]}"; do
    param="${param_value%:*}"
    expected="${param_value#*:}"
    
    if [[ -f "/proc/sys/${param//./\/}" ]]; then
        actual=$(cat "/proc/sys/${param//./\/}")
        if [[ "$actual" == "$expected" ]]; then
            check_status "PASS" "$param = $actual"
        else
            check_status "WARN" "$param = $actual (expected $expected)"
        fi
    else
        check_status "INFO" "$param parameter not available"
    fi
done

header "AUDIT LOGGING"

# Check audit service
if systemctl is-active --quiet auditd; then
    check_status "PASS" "Audit daemon is running"
    
    # Check audit rules
    audit_rules=$(auditctl -l 2>/dev/null | wc -l)
    if [[ $audit_rules -gt 0 ]]; then
        check_status "PASS" "$audit_rules audit rules configured"
    else
        check_status "WARN" "No audit rules configured"
    fi
else
    check_status "WARN" "Audit daemon is not running"
fi

header "SUMMARY"

total_pass=$(grep -c "[SUCCESS] PASS" "$REPORT_FILE")
total_fail=$(grep -c "[ERROR] FAIL" "$REPORT_FILE")
total_warn=$(grep -c "[WARNING]  WARN" "$REPORT_FILE")

log "Security audit completed"
log "Results: $total_pass PASS, $total_fail FAIL, $total_warn WARN"

if [[ $total_fail -gt 0 ]]; then
    log "CRITICAL: $total_fail security issues found that require immediate attention"
    exit 1
elif [[ $total_warn -gt 0 ]]; then
    log "WARNING: $total_warn security issues found that should be reviewed"
    exit 2
else
    log "All security checks passed"
    exit 0
fi

echo ""
echo "Full report saved to: $REPORT_FILE"