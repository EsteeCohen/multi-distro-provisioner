#!/usr/bin/env bash
# nginx_monitor_loop.sh -- runs inside nginx-monitor.service.
# Checks nginx every 30 seconds. Restarts it if the /health endpoint fails.
#
# WHY a separate script instead of ExecStart=systemctl restart nginx?
#   A service's ExecStart runs ONCE. To keep checking on a schedule,
#   we need a loop. This script IS the loop -- systemd keeps it running,
#   and Restart=always in the unit file restarts it if it ever crashes.

set -euo pipefail

source "/opt/provisioner/scripts/common/utils.sh"

CHECK_INTERVAL=30   # seconds between checks
HEALTH_URL="http://localhost/health"
MAX_FAILURES=3      # restart nginx after this many consecutive failures

consecutive_failures=0

log_info "nginx-monitor started. Checking every ${CHECK_INTERVAL}s"

# - Main loop -
# WHY 'while true'?
#   This script is meant to run forever as a service. The loop never exits
#   on its own. systemd stops it when you run 'systemctl stop nginx-monitor'.
while true; do

    # curl flags:
    #   -s  = silent (no progress bar)
    #   -f  = fail on HTTP errors (exit non-zero if status >= 400)
    #   -m5 = timeout after 5 seconds (don't wait forever for a hung server)
    #   -o /dev/null = throw away the response body (we only care about exit code)
    if curl -sf -m5 -o /dev/null "${HEALTH_URL}"; then
        # Check passed -- reset failure counter
        if [[ "${consecutive_failures}" -gt 0 ]]; then
            log_info "nginx recovered after ${consecutive_failures} failed check(s)"
        fi
        consecutive_failures=0
    else
        (( consecutive_failures++ )) || true
        # WHY '|| true'?
        #   (( n++ )) returns exit code 1 when n was 0 (because 0 is falsy in arithmetic).
        #   set -e would stop the script here. '|| true' prevents that.
        log_warn "nginx health check failed (${consecutive_failures}/${MAX_FAILURES})"

        if [[ "${consecutive_failures}" -ge "${MAX_FAILURES}" ]]; then
            log_error "nginx is down -- restarting"
            systemctl restart nginx

            if systemctl is-active --quiet nginx; then
                log_info "nginx restarted successfully"
                consecutive_failures=0
            else
                log_error "nginx failed to restart -- check: journalctl -u nginx"
            fi
        fi
    fi

    # sleep keeps the loop from running continuously and burning CPU
    sleep "${CHECK_INTERVAL}"
done