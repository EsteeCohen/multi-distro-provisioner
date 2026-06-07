#!/usr/bin/env bash
# install_nginx.sh -- installs nginx, deploys config, enables it via systemd.
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

# - 1. Detect distro and install nginx -
# WHY detect_distro here?
#   Ubuntu uses apt-get, Fedora uses dnf. Same goal, different tools.
#   detect_distro reads /etc/os-release and returns "ubuntu" or "fedora".
#
# WHY check is_installed first?
#   apt-get install on an already-installed package is slow -- it updates
#   the package list and rechecks everything. Skipping it keeps the
#   provisioner fast on re-runs (idempotency again).

distro="$(detect_distro)"
log_info "Detected distro: ${distro}"

if is_installed nginx; then
    log_info "nginx is already installed -- skipping"
else
    log_info "Installing nginx..."

    case "${distro}" in
        ubuntu|debian)
            # apt-get update -> refreshes the local package list from Ubuntu's servers
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

# - 2. Deploy our nginx configuration -
# WHY /etc/nginx/conf.d/?
#   nginx's main config file (/etc/nginx/nginx.conf) has this line:
#     include /etc/nginx/conf.d/*.conf;
#   It automatically loads every .conf file in that directory.
#   So we drop our config there instead of editing the main file.
#   This is the standard pattern -- never edit nginx.conf directly.
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

# Fedora's nginx.conf has a built-in server block with server_name _ on port 80.
# It takes priority over our conf.d/default.conf, so /health returns 404.
# Replace it with a minimal version that only loads conf.d  no built-in server block.
if [[ "${distro}" == "fedora" || "${distro}" == "rhel" || "${distro}" == "centos" ]]; then
    cat > /etc/nginx/nginx.conf <<'NGINXEOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
NGINXEOF
    log_info "  Replaced Fedora nginx.conf (removed conflicting default server block)"
fi

# - 3. Generate the status page and copy the dashboard -
# WHY a separate script?
#   The status page embeds live system data (distro, disk, IP, provision time).
#   Generating it in a dedicated script keeps install_nginx.sh readable.
#   dashboard.html is a side-by-side comparison page served at /dashboard.html.
DASHBOARD_SRC="${SCRIPT_DIR}/../../web/dashboard.html"
mkdir -p "${WEB_ROOT}"
bash "${SCRIPT_DIR}/generate_status_page.sh"
if [[ -f "${DASHBOARD_SRC}" ]]; then
    cp "${DASHBOARD_SRC}" "${WEB_ROOT}/dashboard.html"
    log_info "  dashboard.html copied to ${WEB_ROOT}"
fi

# - 4. Validate nginx configuration -
# WHY nginx -t before starting?
#   nginx -t runs a dry-run of the config parser.
#   If there's a syntax error in our config, nginx -t will catch it HERE
#   instead of silently failing to start later.
#   The script will exit (because of set -e) if nginx -t fails.
log_info "Validating nginx configuration"
nginx -t
log_info "  Configuration valid"

# - 5. Enable and start nginx via systemd -
# WHY two separate commands?
#   systemctl enable  -> tells systemd to start nginx automatically on every boot
#                       writes a symlink in /etc/systemd/system/multi-user.target.wants/
#   systemctl start   -> starts nginx RIGHT NOW in this session
#
#   Without enable: nginx starts now but not after a reboot.
#   Without start:  nginx will start next reboot but not now.
#   You almost always want both.
#
# WHY check service_enabled before enabling?
#   Same idempotency reason -- systemctl enable on an already-enabled
#   service is harmless but prints a warning. Clean is better.

log_info "Enabling nginx to start on boot"
if ! service_enabled nginx; then
    systemctl enable nginx
    log_info "  nginx enabled"
else
    log_info "  nginx already enabled"
fi

log_info "Starting / reloading nginx"
# WHY restart instead of start?
#   'start' is a no-op when nginx is already running, so a re-provision would
#   leave the old config loaded in memory even though we just wrote a new one.
#   'restart' ensures the running process always picks up the updated config.
systemctl restart nginx

# - 6. Verify nginx is running -
# systemctl is-active returns exit code 0 if running, non-zero if not.
# Because of set -e, the script exits here if nginx failed to start.
if systemctl is-active --quiet nginx; then
    log_info "nginx is running"
else
    log_error "nginx failed to start -- check: journalctl -u nginx"
    exit 1
fi

log_info "nginx setup complete. Test with: curl http://localhost"