#!/usr/bin/env bash
# setup_systemd.sh -- installs and enables the custom systemd service units.
#
# Closes #8

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

REPO_ROOT="${SCRIPT_DIR}/../.."
SYSTEMD_DIR="/etc/systemd/system"
PROVISIONER_DIR="/opt/provisioner"

check_root
log_step "Phase 7: systemd Services"

# - 1. Install the provisioner scripts into /opt -
# WHY /opt?
#   /opt is for optional/add-on software not managed by the package manager.
#   Our scripts aren't system scripts -- they belong in /opt, not /usr/bin.
#   systemd unit files reference absolute paths, so scripts must be installed
#   at a known location inside the VM.
log_info "Installing provisioner scripts to ${PROVISIONER_DIR}"
mkdir -p "${PROVISIONER_DIR}/scripts/common"
cp -r "${REPO_ROOT}/scripts/." "${PROVISIONER_DIR}/scripts/"
chmod +x "${PROVISIONER_DIR}"/scripts/common/*.sh
chmod +x "${PROVISIONER_DIR}"/scripts/ubuntu/*.sh
chmod +x "${PROVISIONER_DIR}"/scripts/fedora/*.sh

# - 2. Install the monitor loop script to /usr/local/bin -
# WHY /usr/local/bin?
#   The nginx-monitor.service unit references /usr/local/bin/nginx-monitor-loop.sh
#   /usr/local/bin is in $PATH and is the correct place for locally-installed executables.
log_info "Installing nginx-monitor-loop.sh"
cp "${REPO_ROOT}/scripts/common/nginx_monitor_loop.sh" \
   /usr/local/bin/nginx-monitor-loop.sh
chmod +x /usr/local/bin/nginx-monitor-loop.sh

# - 3. Copy unit files to /etc/systemd/system/ -
# WHY /etc/systemd/system/?
#   systemd looks for unit files in several places. In priority order:
#     /etc/systemd/system/    -> admin-managed (our files go here)
#     /run/systemd/system/    -> runtime generated
#     /lib/systemd/system/    -> package-installed (nginx's own unit is here)
#
#   Files in /etc/systemd/system/ take precedence over /lib/systemd/system/
#   so you can override a package's unit file by placing yours here.
log_info "Installing systemd unit files"
cp "${REPO_ROOT}/systemd/nginx-monitor.service" "${SYSTEMD_DIR}/"
cp "${REPO_ROOT}/systemd/log-alert.service"     "${SYSTEMD_DIR}/"
cp "${REPO_ROOT}/systemd/log-alert.timer"       "${SYSTEMD_DIR}/"

# - 4. daemon-reload -
# WHY daemon-reload?
#   systemd reads unit files into memory at startup.
#   If you add or modify a unit file, systemd doesn't know until you reload.
#   daemon-reload rescans all unit files -- ALWAYS run this after copying units.
#   Without it, systemctl enable/start will use the old (or missing) definition.
log_info "Reloading systemd daemon"
systemctl daemon-reload

# - 5. Enable and start services -
log_info "Enabling and starting nginx-monitor"
systemctl enable nginx-monitor.service
systemctl restart nginx-monitor.service

# For the log monitor, we enable the TIMER (not the service directly)
# The timer will trigger the service on its own schedule
log_info "Enabling log-alert timer"
systemctl enable log-alert.timer
systemctl start  log-alert.timer

# - 6. Show status of everything -
# WHY show status at the end?
#   Gives immediate visual confirmation that everything started correctly.
#   'is-active' is machine-readable; 'status' is human-readable.
echo ""
log_info "Service status:"
systemctl status nginx-monitor.service --no-pager -l || true
echo ""
systemctl status log-alert.timer --no-pager -l || true

# List all active timers -- good way to verify timers are working
echo ""
log_info "Active timers:"
systemctl list-timers --no-pager

log_info "systemd setup complete."
log_info "Useful commands:"
log_info "  journalctl -u nginx-monitor -f    # follow monitor logs live"
log_info "  journalctl -u log-alert           # see log-alert runs"
log_info "  systemctl list-timers             # see all timer schedules"