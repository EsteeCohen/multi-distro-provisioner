#!/usr/bin/env bash
# setup_firewall.sh ג€” configures firewalld on Fedora.
#
# Closes #4
#
# WHY firewalld on Fedora?
#   Fedora, RHEL, and CentOS all use firewalld as the default firewall.
#   This is RHCSA exam material ג€” you must know firewall-cmd.
#   firewalld uses the concept of "zones" which ufw does not have.
#
# WHAT is a zone?
#   A zone is a named trust level. Each network interface belongs to one zone.
#   The default zone is "public" ג€” which assumes untrusted networks.
#   Rules you add go into a zone, not globally.
#
#   Common zones:
#     public  ג†’ untrusted network (internet-facing) ג€” we use this
#     trusted ג†’ all connections accepted (LAN)
#     drop    ג†’ all incoming dropped silently

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"

check_root
log_step "Phase 3: Firewall (firewalld) ג€” Fedora"

# ג”€ג”€ 1. Install firewalld if missing ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
if ! is_installed firewall-cmd; then
    log_info "Installing firewalld"
    dnf install -y firewalld
fi

# ג”€ג”€ 2. Enable and start firewalld ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY enable --now as one command?
#   systemctl enable --now = enable (survives reboot) + start (runs now)
#   It's shorthand for running both commands separately.
#
# Unlike ufw, firewalld is a daemon (background service) that must be
# running before you can configure rules with firewall-cmd.
log_info "Enabling and starting firewalld"
systemctl enable --now firewalld

# ג”€ג”€ 3. Allow SSH ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY --add-service instead of --add-port?
#   firewalld ships with predefined service definitions in /usr/lib/firewalld/services/
#   'ssh' is already defined there as port 22/tcp.
#   Using service names is more readable and portable.
#
# WHY --permanent?
#   firewall-cmd has two modes:
#     without --permanent ג†’ rule is active NOW but lost after reload/reboot
#     with --permanent    ג†’ rule is saved to disk and survives forever
#   Always use --permanent for rules you want to keep.
#
# WHY --zone=public?
#   Explicitly targeting the public zone (default for external interfaces).
#   Being explicit is better than relying on the default.
log_info "Allowing SSH"
firewall-cmd --zone=public --add-service=ssh --permanent

# ג”€ג”€ 4. Allow HTTP and HTTPS ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
log_info "Allowing HTTP and HTTPS"
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent

# ג”€ג”€ 5. Reload firewalld ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY reload after adding --permanent rules?
#   --permanent writes rules to disk but does NOT activate them immediately.
#   --reload reads those disk rules and activates them in the running firewall.
#   Without reload, your rules are saved but not yet enforced.
log_info "Reloading firewalld to apply rules"
firewall-cmd --reload

# ג”€ג”€ 6. Show final state ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# --list-all shows everything: zone, interfaces, services, ports, rules
log_info "Firewall rules active:"
firewall-cmd --zone=public --list-all

log_info "Firewall (firewalld) setup complete."