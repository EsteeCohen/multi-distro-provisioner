#!/usr/bin/env bash
# health_check.sh ג€” checks the status of nginx, Docker, and the firewall.
# Run manually: sudo bash scripts/common/health_check.sh
#
# Closes #6

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# ג”€ג”€ Tracking variables ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY an array of failures?
#   We want to check EVERYTHING even if one thing fails,
#   then print a summary at the end. If we used set -e alone,
#   the script would stop at the first failure and skip the rest.
#   Collecting failures in an array lets us report the full picture.
FAILURES=()

log_step "System Health Check ג€” $(hostname)"
echo "Timestamp: $(date)"
echo ""

# ג”€ג”€ Helper: check a condition and record pass/fail ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY a function for this?
#   We run ~6 checks in the same format. Without a function we'd
#   copy-paste the if/else block 6 times. One function, called 6 times.
#
# $1 = check name (printed to user)
# $2 = command to run (its exit code determines pass/fail)
run_check() {
    local name="$1"
    local cmd="$2"

    # eval runs a string as a shell command
    # 2>/dev/null suppresses any error output from the command itself
    if eval "${cmd}" &>/dev/null; then
        echo -e "  ${GREEN}ג“${NC}  ${name}"
    else
        echo -e "  ${RED}ג—${NC}  ${name}"
        # Append to failures array
        # += on arrays appends a new element
        FAILURES+=("${name}")
    fi
}

# ג”€ג”€ 1. nginx checks ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
log_info "nginx"
run_check "nginx service is running"    "systemctl is-active nginx"
run_check "nginx config is valid"       "nginx -t"
run_check "nginx responds on port 80"   "curl -sf http://localhost/health"

# ג”€ג”€ 2. Docker checks ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
echo ""
log_info "Docker"
run_check "Docker daemon is running"    "systemctl is-active docker"
run_check "docker CLI works"            "docker info"
run_check "can pull and run a container" "docker run --rm hello-world"

# ג”€ג”€ 3. Firewall check ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
echo ""
log_info "Firewall"

# WHY detect distro here?
#   ufw and firewalld have different commands to check status.
#   We pick the right one based on the distro.
distro="$(detect_distro)"
case "${distro}" in
    ubuntu|debian)
        run_check "ufw is active" "ufw status | grep -q 'Status: active'"
        ;;
    fedora|rhel|centos)
        run_check "firewalld is active" "systemctl is-active firewalld"
        ;;
esac

# ג”€ג”€ 4. User checks ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
echo ""
log_info "Users"
run_check "devops user exists"  "id devops"
run_check "appuser user exists" "id appuser"
run_check "devops has sudo"     "sudo -l -U devops | grep -q NOPASSWD"

# ג”€ג”€ 5. Disk space warning ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
echo ""
log_info "Disk"

# df -h / = disk usage of root partition, human-readable
# awk 'NR==2' = take the second line (skip the header)
# awk '{print $5}' = print the 5th column (Use%)
# tr -d '%' = remove the % character
# WHY check disk? Docker images and logs fill up disks fast.
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ "${DISK_USAGE}" -lt 80 ]]; then
    echo -e "  ${GREEN}ג“${NC}  Disk usage: ${DISK_USAGE}%"
else
    echo -e "  ${RED}ג—${NC}  Disk usage: ${DISK_USAGE}% (WARNING: above 80%)"
    FAILURES+=("Disk usage above 80%")
fi

# ג”€ג”€ Summary ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
echo ""
echo "ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•ג•"

# ${#FAILURES[@]} = length of the FAILURES array
# If length is 0, all checks passed
if [[ "${#FAILURES[@]}" -eq 0 ]]; then
    echo -e "${GREEN}All checks passed.${NC}"
    exit 0
else
    echo -e "${RED}${#FAILURES[@]} check(s) failed:${NC}"
    # Loop over array elements
    # "${FAILURES[@]}" = expand all array elements
    for failure in "${FAILURES[@]}"; do
        echo -e "  ${RED}ג—${NC} ${failure}"
    done
    exit 1
fi