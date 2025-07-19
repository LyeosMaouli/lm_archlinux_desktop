# Security Scripts

This directory contains security automation scripts for system hardening, monitoring, and auditing.

## Scripts Overview

### 🔥 firewall_setup.sh
Configures UFW firewall with secure defaults and desktop-appropriate rules.

**Features:**
- Restrictive default policies (deny incoming, allow outgoing)
- SSH access with rate limiting
- Desktop service allowances (HTTP/HTTPS, DNS, NTP)
- Attack vector blocking
- Automated monitoring setup

**Usage:**
```bash
sudo ./firewall_setup.sh
```

### 🛡️ fail2ban_setup.sh
Sets up fail2ban for intrusion prevention and automated threat response.

**Features:**
- SSH brute force protection
- Custom filters for authentication failures
- UFW integration for automatic blocking
- Rate limiting and monitoring
- Email notifications for high activity

**Usage:**
```bash
sudo ./fail2ban_setup.sh
```

### 🔒 system_hardening.sh
Applies comprehensive system-level security hardening.

**Features:**
- Kernel parameter security tuning
- SSH hardening configuration
- PAM security policies
- Password aging enforcement
- Audit logging setup
- File permission hardening
- SUID/SGID review

**Usage:**
```bash
sudo ./system_hardening.sh
```

### 🔍 security_audit.sh
Performs comprehensive security assessment and reporting.

**Features:**
- User account audit
- Password policy verification
- SSH configuration review
- Firewall status check
- File permission analysis
- Network security assessment
- System integrity verification
- Detailed reporting with pass/fail status

**Usage:**
```bash
sudo ./security_audit.sh
```

## Security Architecture

This security framework implements defense in depth:

1. **Network Security**: UFW firewall + fail2ban
2. **Access Control**: SSH hardening + PAM policies
3. **System Hardening**: Kernel parameters + file permissions
4. **Monitoring**: Audit logging + automated checks
5. **Assessment**: Regular security audits

## Integration with Ansible

These scripts are designed to work with the Ansible security role:

- `configs/ansible/roles/system_hardening/`
- `configs/ansible/playbooks/security.yml`

## Monitoring and Alerting

Automated monitoring includes:

- **firewall-monitor.sh**: UFW activity monitoring
- **fail2ban-monitor.sh**: Intrusion attempt tracking
- **security-monitor.sh**: General security monitoring

All monitoring scripts run via systemd timers and can send email alerts.

## Configuration Files

Key configuration locations:
- `/etc/sysctl.d/99-security-hardening.conf`
- `/etc/ssh/sshd_config.d/99-hardening.conf`
- `/etc/fail2ban/jail.local`
- `/etc/audit/rules.d/99-security.rules`

## Usage Guidelines

1. **Test First**: Run scripts in a test environment
2. **Backup**: Scripts automatically backup configurations
3. **Review**: Check SSH access before logging out
4. **Monitor**: Watch logs after implementation
5. **Audit**: Run security audits regularly

## Security Considerations

- Scripts require root privileges
- SSH hardening may lock out users if misconfigured
- Firewall changes take effect immediately
- Audit logs may grow large over time

## Compliance

These scripts help achieve compliance with:
- CIS (Center for Internet Security) benchmarks
- NIST security frameworks
- General security best practices

## Troubleshooting

### SSH Issues
```bash
# Check SSH configuration
sudo sshd -t
sudo systemctl status sshd

# View SSH logs
sudo journalctl -u sshd -f
```

### Firewall Issues
```bash
# Check UFW status
sudo ufw status verbose

# View firewall logs
sudo journalctl -u ufw -f
```

### Fail2ban Issues
```bash
# Check fail2ban status
sudo fail2ban-client status

# View fail2ban logs
sudo journalctl -u fail2ban -f
```

## Customization

Scripts can be customized by modifying variables at the top of each file or by creating configuration files in `/etc/security/`.

## Support

For issues or questions:
1. Check system logs: `journalctl -f`
2. Review security audit output
3. Verify configurations are syntactically correct
4. Test in isolated environment first