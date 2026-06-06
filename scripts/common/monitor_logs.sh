#!/usr/bin/env bash
# monitor_logs.sh -- parses nginx logs and alerts when error rate is too high.
# Can be run manually or as a systemd service (see systemd/log-alert.service).
#
# Closes #7
#
# WHY log monitoring?
#   A server can be "running" (process is alive) but still broken
#   (returning errors to every user). Health checks catch the first case.
#   Log monitoring catches the second -- it reads what nginx actually returned.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# - Configuration -
# How far back to look for errors (journalctl --since format)
LOOKBACK="1 hour ago"

# Alert if more than this many 5xx errors found in the lookback window
ERROR_THRESHOLD=10

# Where to write our monitor output
LOG_DIR="/var/log/app"
LOG_FILE="${LOG_DIR}/monitor.log"

check_root
log_step "Phase 6: Log Monitoring"

# - Create log directory -
# WHY /var/log/app/?
#   /var/log/ is the standard Linux location for log files.
#   We create a subdirectory so our logs don't mix with system logs.
mkdir -p "${LOG_DIR}"
chown appuser:appuser "${LOG_DIR}" 2>/dev/null || true

# - Helper: write to both terminal and log file -
# tee writes to both stdout (terminal) and a file at the same time
# -a = append mode (don't overwrite the file)
write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

write_log "=== Monitor run started on $(hostname) ==="

# - 1. Check nginx service state via systemd -
# WHY check systemd first, before logs?
#   If nginx is down, there are no access logs to parse.
#   Fail fast with a clear message.
write_log "Checking nginx service status"

if ! systemctl is-active --quiet nginx; then
    write_log "CRITICAL: nginx is not running -- attempting restart"
    systemctl restart nginx

    if systemctl is-active --quiet nginx; then
        write_log "INFO: nginx restarted successfully"
    else
        write_log "CRITICAL: nginx failed to restart -- manual intervention needed"
        # journalctl -u nginx -n 20 = last 20 lines of nginx logs
        journalctl -u nginx -n 20 --no-pager >> "${LOG_FILE}"
        exit 1
    fi
else
    write_log "INFO: nginx is active"
fi

# - 2. Count HTTP 5xx errors in nginx access log -
# WHY grep for 5xx?
#   HTTP status codes:
#     2xx = success (200 OK, 201 Created)
#     3xx = redirect (301 Moved, 304 Not Modified)
#     4xx = client error (404 Not Found, 403 Forbidden)
#     5xx = SERVER error (500 Internal Server Error, 502 Bad Gateway)
#   5xx errors mean YOUR server is broken, not the client's fault.
#   A spike in 5xx errors means something is wrong and needs attention.
#
# journalctl flags:
#   -u nginx        = only show logs from the nginx unit
#   --since "..."   = only logs from this time onwards
#   --no-pager      = don't use interactive pager (needed for scripts)
#   -o short        = short output format (one line per entry)

write_log "Scanning nginx logs since '${LOOKBACK}'"

# We capture the output in a variable first so we can both count and display it
# grep -c counts matching lines; if no matches, grep exits 1 so we use || true
# to prevent set -e from stopping the script
NGINX_LOGS=$(journalctl -u nginx --since "${LOOKBACK}" --no-pager -o short 2>/dev/null || true)

# grep -E = extended regex
# ' 5[0-9]{2} ' = space, then 5xx status code, then space
# This matches lines like: "GET /page HTTP/1.1" 500
ERROR_COUNT=$(echo "${NGINX_LOGS}" | grep -cE ' 5[0-9]{2} ' || true)

write_log "INFO: Found ${ERROR_COUNT} HTTP 5xx errors in the last hour"

# - 3. Alert if error rate exceeds threshold -
# WHY a threshold instead of alerting on every error?
#   One 500 error might be a fluke -- a user hit a broken URL.
#   Ten 500 errors in an hour means something is wrong systemically.
#   Thresholds reduce noise and focus alerts on real problems.
if [[ "${ERROR_COUNT}" -gt "${ERROR_THRESHOLD}" ]]; then
    write_log "ALERT: Error count ${ERROR_COUNT} exceeds threshold ${ERROR_THRESHOLD}"

    # Show the actual error lines for debugging
    write_log "--- Recent 5xx errors ---"
    echo "${NGINX_LOGS}" | grep -E ' 5[0-9]{2} ' | tail -20 >> "${LOG_FILE}"
    write_log "--- End of errors ---"

    # Exit code 2 = warning/alert (convention: 0=ok, 1=error, 2=warning)
    exit 2
fi

# - 4. Show recent nginx error log entries -
# /var/log/nginx/error.log is where nginx writes its own error messages
# (different from access.log which logs every request)
write_log "Recent nginx error log entries:"

NGINX_ERROR_LOG="/var/log/nginx/error.log"
if [[ -f "${NGINX_ERROR_LOG}" ]]; then
    # tail -n 10 = last 10 lines
    # grep -v = invert match (exclude lines matching the pattern)
    # We exclude "notice" level which is informational, not a problem
    tail -n 50 "${NGINX_ERROR_LOG}" \
        | grep -vE '\[notice\]' \
        | tail -n 10 \
        >> "${LOG_FILE}" || true
else
    write_log "INFO: ${NGINX_ERROR_LOG} not found (nginx may log via journald only)"
fi

# - 5. Disk space check -
# WHY check disk in a log monitor?
#   Logs fill up disks. A full disk causes nginx to fail writing logs,
#   which causes errors, which creates more logs... it's a bad cycle.
DISK_USAGE=$(df -h /var/log | awk 'NR==2 {print $5}' | tr -d '%')
write_log "INFO: /var/log disk usage: ${DISK_USAGE}%"

if [[ "${DISK_USAGE}" -gt 85 ]]; then
    write_log "WARN: /var/log is ${DISK_USAGE}% full -- consider log rotation"
fi

write_log "=== Monitor run complete ==="
write_log "Full log available at: ${LOG_FILE}"