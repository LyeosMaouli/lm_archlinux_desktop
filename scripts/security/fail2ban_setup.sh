#!/bin/bash
# Fail2ban Setup Script
# Configures fail2ban for intrusion prevention

set -euo pipefail

if [[ -z "$SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
source "$SCRIPT_DIR/../internal/common.sh" || {
    echo "Error: Cannot load common.sh"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

log_info "Starting fail2ban setup"

# Install fail2ban
if ! command -v fail2ban-server >/dev/null 2>&1; then
    log_info "Installing fail2ban"
    pacman -S --noconfirm fail2ban
fi

# Create main configuration
log_info "Creating fail2ban configuration"

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600

# A host is banned if it has generated "maxretry" during the last "findtime" seconds
findtime = 600
maxretry = 3

# Destination email for notifications
destemail = root@localhost
sender = fail2ban@localhost

# Email action
mta = sendmail
protocol = tcp
chain = INPUT
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s

# SSH jail
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

# HTTP authentication failures
[apache-auth]
enabled = false
port = http,https
filter = apache-auth
logpath = /var/log/apache*/*error.log
maxretry = 6

# Nginx authentication failures
[nginx-http-auth]
enabled = false
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

# Block brute force attacks on common services
[postfix]
enabled = false
port = smtp,465,submission
filter = postfix
logpath = /var/log/mail.log

[dovecot]
enabled = false
port = pop3,pop3s,imap,imaps,submission,465,sieve
filter = dovecot
logpath = /var/log/mail.log

# Custom jail for failed login attempts
[auth-failures]
enabled = true
filter = auth-failures
logpath = /var/log/auth.log
maxretry = 5
bantime = 7200
findtime = 3600

# Block port scanners
[port-scan]
enabled = true
filter = port-scan
logpath = /var/log/syslog
maxretry = 1
bantime = 86400
findtime = 3600
EOF

# Create custom filters
log_info "Creating custom fail2ban filters"

# Auth failures filter
cat > /etc/fail2ban/filter.d/auth-failures.conf << 'EOF'
[Definition]
failregex = ^.*authentication failure.*rhost=<HOST>.*$
            ^.*Failed password for .* from <HOST>.*$
            ^.*Failed publickey for .* from <HOST>.*$
            ^.*Invalid user .* from <HOST>.*$
            ^.*Connection closed by <HOST>.*$

ignoreregex =
EOF

# Port scan filter
cat > /etc/fail2ban/filter.d/port-scan.conf << 'EOF'
[Definition]
failregex = ^.*kernel:.*IN=.*OUT=.*SRC=<HOST>.*DPT=.*$

ignoreregex =
EOF

# SSH brute force filter enhancement
cat > /etc/fail2ban/filter.d/sshd-enhanced.conf << 'EOF'
[Definition]
failregex = ^%(__prefix_line)s(?:error: PAM: )?[aA]uthentication (?:failure|error|failed) for .* from <HOST>( via \S+)?\s*$
            ^%(__prefix_line)s(?:error: )?Received disconnect from <HOST>: 3: .*: Auth fail$
            ^%(__prefix_line)sFailed \S+ for (?P<cond_inv>invalid user )?(?P<cond_user>\S+) from <HOST>(?: port \d+)?(?: ssh\d*)?(?P<cond_ip> \[preauth\])?$
            ^%(__prefix_line)sROOT LOGIN REFUSED.* FROM <HOST>$
            ^%(__prefix_line)s[iI](?:llegal|nvalid) user .*? from <HOST>$
            ^%(__prefix_line)sUser .+ from <HOST> not allowed because not listed in AllowUsers$
            ^%(__prefix_line)sauthentication failure; logname=\S* uid=\S* euid=\S* tty=\S* ruser=\S* rhost=<HOST>(?:\s+user=.*)?\s*$
            ^%(__prefix_line)spam_unix\(sshd:auth\):\s+authentication failure; logname=\S* uid=\S* euid=\S* tty=\S* ruser=\S* rhost=<HOST>(?:\s+user=.*)?\s*$

ignoreregex =
EOF

# Create action for UFW integration
cat > /etc/fail2ban/action.d/ufw.conf << 'EOF'
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = ufw insert 1 deny from <ip> to any
actionunban = ufw delete deny from <ip> to any

[Init]
EOF

# Update jail configuration to use UFW
cat >> /etc/fail2ban/jail.local << 'EOF'

# UFW integration
[DEFAULT]
banaction = ufw
EOF

# Create monitoring script
cat > /usr/local/bin/fail2ban-monitor.sh << 'EOF'
#!/bin/bash
# Fail2ban monitoring script

if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="/var/log/fail2ban-monitor.log"
fi
ALERT_EMAIL="${ADMIN_EMAIL:-root@localhost}"

# Check fail2ban status
check_fail2ban_status() {
    if ! systemctl is-active --quiet fail2ban; then
        echo "[$(date)] CRITICAL: fail2ban service is not running!" >> "$LOG_FILE"
        if command -v mail >/dev/null 2>&1; then
            echo "fail2ban service is down!" | mail -s "Fail2ban CRITICAL Alert" "$ALERT_EMAIL"
        fi
        return 1
    fi
}

# Report current bans
report_bans() {
    local banned_ips
    banned_ips=$(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr ',' '\n' | while read jail; do
        if [[ -n "$jail" ]]; then
            fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned:" | cut -d: -f2
        fi
    done | tr -d ' ' | sort -u | wc -l)
    
    if [[ $banned_ips -gt 0 ]]; then
        echo "[$(date)] INFO: Currently $banned_ips IP(s) banned" >> "$LOG_FILE"
    fi
}

# Check for high ban rates
check_ban_rate() {
    local recent_bans
    recent_bans=$(journalctl -u fail2ban --since "1 hour ago" | grep "Ban " | wc -l)
    
    if [[ $recent_bans -gt 20 ]]; then
        echo "[$(date)] WARNING: $recent_bans bans in the last hour" >> "$LOG_FILE"
        if command -v mail >/dev/null 2>&1; then
            echo "High ban rate detected: $recent_bans bans in the last hour" | mail -s "Fail2ban Alert" "$ALERT_EMAIL"
        fi
    fi
}

check_fail2ban_status
report_bans
check_ban_rate
EOF

chmod +x /usr/local/bin/fail2ban-monitor.sh

# Create systemd timer for monitoring
cat > /etc/systemd/system/fail2ban-monitor.timer << 'EOF'
[Unit]
Description=Fail2ban monitoring timer
Requires=fail2ban-monitor.service

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/fail2ban-monitor.service << 'EOF'
[Unit]
Description=Fail2ban monitoring service
After=fail2ban.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fail2ban-monitor.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
log_info "Enabling fail2ban services"
systemctl daemon-reload
systemctl enable fail2ban
systemctl start fail2ban
systemctl enable fail2ban-monitor.timer
systemctl start fail2ban-monitor.timer

# Display status
log_info "Fail2ban setup completed. Current status:"
fail2ban-client status | tee -a "$LOG_FILE"

log_info "Fail2ban setup completed successfully"
echo "Check fail2ban status with: fail2ban-client status"
echo "Monitor fail2ban logs with: journalctl -u fail2ban -f"