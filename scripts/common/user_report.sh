#!/usr/bin/env bash
# user_report.sh ג€” prints a formatted report of all non-system users.
# Run manually: bash scripts/common/user_report.sh
#
# Closes #6
#
# WHY this script?
#   In a real environment you need to audit who has access to a machine,
#   what groups they belong to, and whether they have sudo.
#   This is a common sysadmin task and good bash practice.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "User Report ג€” $(hostname)"
echo "Generated: $(date)"
echo ""

# ג”€ג”€ printf for aligned output ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY printf instead of echo?
#   printf lets you control column width with format specifiers:
#   %-15s = left-align string, minimum 15 characters wide
#   This makes columns line up neatly.
printf "%-15s %-20s %-10s %-10s\n" "USERNAME" "GROUPS" "SUDO" "SHELL"
printf "%-15s %-20s %-10s %-10s\n" "--------" "------" "----" "-----"

# ג”€ג”€ Loop over users with UID >= 1000 ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY UID >= 1000?
#   Linux reserves UIDs 0-999 for system users (root, daemon, www-data, etc.)
#   Real human users start at UID 1000. We only want to report on those.
#
# /etc/passwd format: username:password:UID:GID:comment:home:shell
#   Field 1 = username
#   Field 3 = UID
#   Field 7 = shell
#
# awk -F: = use : as field separator
# $3 >= 1000 = only lines where UID (field 3) is 1000 or more
# $3 != 65534 = skip the "nobody" user (UID 65534)
# {print $1 ":" $7} = print username:shell

while IFS=: read -r username shell; do

    # Get all groups for this user
    # groups username = prints: "username : group1 group2 group3"
    # cut -d: -f2 = take everything after the colon
    # tr -s ' ' ',' = replace spaces with commas (for cleaner output)
    # sed 's/^,//' = remove leading comma if present
    user_groups=$(groups "${username}" 2>/dev/null \
        | cut -d: -f2 \
        | tr -s ' ' ',' \
        | sed 's/^,//')

    # Check if user has a sudoers file
    # WHY check /etc/sudoers.d/ directly?
    #   'sudo -l -U username' requires sudo itself to run.
    #   Checking the file is simpler and doesn't need elevated permissions.
    if [[ -f "/etc/sudoers.d/${username}" ]]; then
        sudo_status="YES"
    else
        sudo_status="no"
    fi

    printf "%-15s %-20s %-10s %-10s\n" \
        "${username}" \
        "${user_groups:0:19}" \
        "${sudo_status}" \
        "${shell}"

done < <(awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $7}' /etc/passwd)
# ג†‘ WHY "< <(...)"?
#   This is process substitution. It feeds the output of the awk command
#   into the while loop as if it were a file.
#   It's needed because piping (awk ... | while read) would run the while
#   loop in a subshell, where variable changes don't survive back to the
#   parent script.

echo ""

# ג”€ג”€ Docker group members ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
log_info "Docker group members:"
if getent group docker &>/dev/null; then
    # getent group docker prints: docker:x:998:devops,appuser
    # cut -d: -f4 = take the 4th field (member list)
    members=$(getent group docker | cut -d: -f4)
    if [[ -n "${members}" ]]; then
        echo "  ${members}" | tr ',' '\n' | sed 's/^/  - /'
    else
        echo "  (no members)"
    fi
else
    echo "  docker group does not exist yet"
fi

echo ""

# ג”€ג”€ /app directory ownership ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
log_info "/app directory:"
if [[ -d /app ]]; then
    # ls -ld = list directory itself (not contents), long format
    ls -ld /app
else
    echo "  /app does not exist"
fi