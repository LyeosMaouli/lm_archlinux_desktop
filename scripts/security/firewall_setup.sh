#!/bin/bash
# UFW Firewall Setup Script
# Configures secure firewall rules for Arch Linux desktop

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/firewall-setup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

log "Starting UFW firewall setup"

# Install UFW if not present
if ! command -v ufw >/dev/null 2>&1; then
    log "Installing UFW firewall"
    pacman -S --noconfirm ufw
fi

# Reset UFW to defaults
log "Resetting UFW to defaults"
ufw --force reset

# Set default policies (deny incoming, allow outgoing)
log "Setting default policies"
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward

# Allow SSH (be careful with this)
read -p "Allow SSH access? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter SSH port (default 22): " ssh_port
    ssh_port=${ssh_port:-22}
    log "Allowing SSH on port $ssh_port"
    ufw allow "$ssh_port"/tcp comment "SSH"
fi

# Allow common desktop services
log "Configuring desktop service rules"

# Allow loopback
ufw allow in on lo
ufw allow out on lo

# Allow DHCP client
ufw allow out 67/udp comment "DHCP client"
ufw allow out 68/udp comment "DHCP client"

# Allow DNS
ufw allow out 53/udp comment "DNS"
ufw allow out 53/tcp comment "DNS over TCP"

# Allow NTP
ufw allow out 123/udp comment "NTP"

# Allow HTTP/HTTPS
ufw allow out 80/tcp comment "HTTP"
ufw allow out 443/tcp comment "HTTPS"

# Allow common secure ports
ufw allow out 993/tcp comment "IMAPS"
ufw allow out 995/tcp comment "POP3S"
ufw allow out 465/tcp comment "SMTPS"
ufw allow out 587/tcp comment "SMTP submission"

# Block common attack vectors
log "Configuring attack prevention rules"

# Rate limiting for SSH
if [[ -n "${ssh_port:-}" ]]; then
    ufw limit "$ssh_port"/tcp comment "SSH rate limit"
fi

# Block known malicious ports
MALICIOUS_PORTS=(135 137 138 139 445 1433 1434 3389)
for port in "${MALICIOUS_PORTS[@]}"; do
    ufw deny "$port" comment "Block malicious port $port"
done

# Configure advanced settings
log "Configuring advanced UFW settings"

# Enable logging
ufw logging medium

# Configure rate limiting
cat > /etc/ufw/before.rules << 'EOF'
# Rate limiting rules
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]

# Don't delete these required lines
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT

# Quickly process packets for which we already have a connection
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Drop INVALID packets
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP

# Rate limit SSH connections
-A ufw-before-input -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
-A ufw-before-input -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j ufw-logging-deny
-A ufw-before-input -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

# Allow ping
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

# Don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
EOF

# Apply IPv6 rules if enabled
if [[ -f /proc/net/if_inet6 ]]; then
    log "Configuring IPv6 rules"
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
fi

# Enable UFW
log "Enabling UFW firewall"
ufw --force enable

# Configure automatic startup
systemctl enable ufw
systemctl start ufw

# Display status
log "UFW setup completed. Current status:"
ufw status verbose | tee -a "$LOG_FILE"

# Create monitoring script
cat > /usr/local/bin/firewall-monitor.sh << 'EOF'
#!/bin/bash
# UFW monitoring script

LOG_FILE="/var/log/ufw-monitor.log"
ALERT_EMAIL="${ADMIN_EMAIL:-root@localhost}"

# Check for suspicious activity
check_blocked_attempts() {
    local recent_blocks
    recent_blocks=$(journalctl -u ufw --since "1 hour ago" | grep "BLOCK" | wc -l)
    
    if [[ $recent_blocks -gt 50 ]]; then
        echo "[$(date)] WARNING: $recent_blocks blocked attempts in the last hour" >> "$LOG_FILE"
        if command -v mail >/dev/null 2>&1; then
            echo "High number of blocked attempts detected: $recent_blocks" | mail -s "UFW Alert" "$ALERT_EMAIL"
        fi
    fi
}

# Check UFW status
check_ufw_status() {
    if ! ufw status | grep -q "Status: active"; then
        echo "[$(date)] CRITICAL: UFW is not active!" >> "$LOG_FILE"
        if command -v mail >/dev/null 2>&1; then
            echo "UFW firewall is not active!" | mail -s "UFW CRITICAL Alert" "$ALERT_EMAIL"
        fi
    fi
}

check_blocked_attempts
check_ufw_status
EOF

chmod +x /usr/local/bin/firewall-monitor.sh

log "Firewall setup completed successfully"
echo "Review the firewall rules with: ufw status verbose"
echo "Monitor firewall logs with: journalctl -u ufw -f"