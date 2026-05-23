#!/usr/bin/env bash
# install_nginx.sh ג€” installs nginx, deploys config, enables it via systemd.
#
# Closes #3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

NGINX_CONF_SRC="${SCRIPT_DIR}/../../config/nginx/default.conf"
NGINX_CONF_DEST="/etc/nginx/conf.d/default.conf"
WEB_ROOT="/var/www/html"

check_root
log_step "Phase 2: nginx Installation & Configuration"

# ג”€ג”€ 1. Detect distro and install nginx ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY detect_distro here?
#   Ubuntu uses apt-get, Fedora uses dnf. Same goal, different tools.
#   detect_distro reads /etc/os-release and returns "ubuntu" or "fedora".
#
# WHY check is_installed first?
#   apt-get install on an already-installed package is slow ג€” it updates
#   the package list and rechecks everything. Skipping it keeps the
#   provisioner fast on re-runs (idempotency again).

distro="$(detect_distro)"
log_info "Detected distro: ${distro}"

if is_installed nginx; then
    log_info "nginx is already installed ג€” skipping"
else
    log_info "Installing nginx..."

    case "${distro}" in
        ubuntu|debian)
            # apt-get update ג†’ refreshes the local package list from Ubuntu's servers
            # Without this, apt-get might try to install an outdated version
            # or fail with "package not found"
            apt-get update -qq
            # -y = yes to all prompts (needed for non-interactive/automated installs)
            apt-get install -y nginx
            ;;
        fedora|rhel|centos)
            # dnf doesn't need a separate update step before install
            # -y = same as apt, auto-confirm
            dnf install -y nginx
            ;;
        *)
            log_error "Unsupported distro: ${distro}"
            exit 1
            ;;
    esac

    log_info "nginx installed successfully"
fi

# ג”€ג”€ 2. Deploy our nginx configuration ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY /etc/nginx/conf.d/?
#   nginx's main config file (/etc/nginx/nginx.conf) has this line:
#     include /etc/nginx/conf.d/*.conf;
#   It automatically loads every .conf file in that directory.
#   So we drop our config there instead of editing the main file.
#   This is the standard pattern ג€” never edit nginx.conf directly.
#
# WHY cp instead of editing in place?
#   Our config file lives in version control (config/nginx/default.conf).
#   We copy it into the VM. If we need to change nginx config,
#   we edit our repo file and re-provision.

log_info "Deploying nginx configuration"
cp "${NGINX_CONF_SRC}" "${NGINX_CONF_DEST}"
log_info "  Config copied to ${NGINX_CONF_DEST}"

# Ubuntu ships with a default site in sites-enabled/ that also listens on port 80.
# It acts as default_server and intercepts our /health requests (returning 404).
# Remove it so our conf.d/default.conf is the only server block on port 80.
if [[ "${distro}" == "ubuntu" || "${distro}" == "debian" ]]; then
    rm -f /etc/nginx/sites-enabled/default
    log_info "  Removed Ubuntu default site (sites-enabled/default)"
fi

# ג”€ג”€ 3. Create a simple index page ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY create an index.html?
#   Without it, nginx serves a blank page or the default distro page.
#   This page shows which machine you're on ג€” useful when testing both VMs.
#
# hostname -f = fully qualified domain name of the machine (ubuntu-node or fedora-node)
mkdir -p "${WEB_ROOT}"
cat > "${WEB_ROOT}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head><title>$(hostname -f)</title></head>
<body>
  <h1>$(hostname -f)</h1>
  <p>Distro: ${distro}</p>
  <p>Provisioned by multi-distro-provisioner</p>
</body>
</html>
EOF
log_info "  index.html created at ${WEB_ROOT}"

# ג”€ג”€ 4. Validate nginx configuration ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY nginx -t before starting?
#   nginx -t runs a dry-run of the config parser.
#   If there's a syntax error in our config, nginx -t will catch it HERE
#   instead of silently failing to start later.
#   The script will exit (because of set -e) if nginx -t fails.
log_info "Validating nginx configuration"
nginx -t
log_info "  Configuration valid"

# ג”€ג”€ 5. Enable and start nginx via systemd ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY two separate commands?
#   systemctl enable  ג†’ tells systemd to start nginx automatically on every boot
#                       writes a symlink in /etc/systemd/system/multi-user.target.wants/
#   systemctl start   ג†’ starts nginx RIGHT NOW in this session
#
#   Without enable: nginx starts now but not after a reboot.
#   Without start:  nginx will start next reboot but not now.
#   You almost always want both.
#
# WHY check service_enabled before enabling?
#   Same idempotency reason ג€” systemctl enable on an already-enabled
#   service is harmless but prints a warning. Clean is better.

log_info "Enabling nginx to start on boot"
if ! service_enabled nginx; then
    systemctl enable nginx
    log_info "  nginx enabled"
else
    log_info "  nginx already enabled"
fi

log_info "Starting nginx"
systemctl start nginx

# ג”€ג”€ 6. Verify nginx is running ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# systemctl is-active returns exit code 0 if running, non-zero if not.
# Because of set -e, the script exits here if nginx failed to start.
if systemctl is-active --quiet nginx; then
    log_info "nginx is running"
else
    log_error "nginx failed to start ג€” check: journalctl -u nginx"
    exit 1
fi

log_info "nginx setup complete. Test with: curl http://localhost"