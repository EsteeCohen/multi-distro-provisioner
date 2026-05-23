#!/usr/bin/env bash
# setup_firewall.sh ג€” configures ufw (Uncomplicated Firewall) on Ubuntu.
#
# Closes #4
#
# WHY ufw on Ubuntu?
#   Ubuntu ships with ufw as the default firewall frontend.
#   ufw sits on top of iptables (the actual kernel firewall engine)
#   and gives you a simpler interface. On RHEL/Fedora, firewalld does
#   the same job but with a completely different command set.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"

check_root
log_step "Phase 3: Firewall (ufw) ג€” Ubuntu"

# ג”€ג”€ 1. Install ufw if missing ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# ufw is usually pre-installed on Ubuntu but may be missing in minimal images
if ! is_installed ufw; then
    log_info "Installing ufw"
    apt-get install -y ufw
fi

# ג”€ג”€ 2. Set default policies ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY set defaults before allowing anything?
#   A firewall works by matching rules top-to-bottom.
#   The default policy is what happens when NO rule matches.
#
#   default deny incoming = block all inbound traffic unless explicitly allowed
#   default allow outgoing = let the VM reach the internet freely
#
#   CRITICAL: Always set defaults BEFORE enabling the firewall.
#   If you enable first with no rules, you lock yourself out of SSH.
log_info "Setting default policies"
ufw default deny incoming
ufw default allow outgoing

# ג”€ג”€ 3. Allow SSH ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY SSH first, always?
#   If you enable the firewall without allowing SSH, you lose access
#   to the machine permanently (or until you get console access).
#   This is the most common mistake when configuring firewalls remotely.
#
# 'ufw allow ssh' is a shortcut for 'ufw allow 22/tcp'
# ufw knows common service names from /etc/services
log_info "Allowing SSH (port 22)"
ufw allow ssh

# ג”€ג”€ 4. Allow HTTP and HTTPS ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# Port 80  = HTTP  (unencrypted web traffic)
# Port 443 = HTTPS (encrypted web traffic)
# Both use TCP protocol (reliable, connection-based)
log_info "Allowing HTTP (port 80) and HTTPS (port 443)"
ufw allow 80/tcp
ufw allow 443/tcp

# ג”€ג”€ 5. Enable the firewall ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY --force?
#   Without --force, ufw asks "Command may disrupt existing ssh connections.
#   Proceed with operation (y|n)?" ג€” this blocks automated scripts.
#   --force answers yes automatically.
#
# ufw status after enabling should show: Status: active
log_info "Enabling ufw"
ufw --force enable

# ג”€ג”€ 6. Reload to apply all rules ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
ufw reload

# ג”€ג”€ 7. Show final state ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# 'numbered' shows rules with index numbers ג€” useful for deleting specific rules
log_info "Firewall rules active:"
ufw status numbered

log_info "Firewall (ufw) setup complete."