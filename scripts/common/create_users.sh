#!/usr/bin/env bash
# create_users.sh - reads config/users.conf and creates users on the system.
#
# Closes #2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

CONFIG_FILE="${SCRIPT_DIR}/../../config/users.conf"

check_root
log_step "Phase 1: User Management"

# WHY mapfile instead of "while read < file"?
#   "while read ... done < file" connects the file to stdin (fd 0).
#   Commands inside the loop (useradd, groupadd) can accidentally
#   consume bytes from that same stdin, skipping lines.
#   mapfile reads the whole file into an array FIRST, so the file
#   is fully closed before any user-creation commands run.
mapfile -t lines < "${CONFIG_FILE}"

for line in "${lines[@]}"; do

    # Skip blank lines and comment lines
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # Parse fields by splitting on ":" using a herestring (<<<)
    # This avoids any stdin conflict
    IFS=: read -r username group shell sudo_access <<< "${line}"

    [[ -z "${username}" ]] && continue

    log_info "Processing user: ${username}"

    # 1. Create the group first - useradd requires the group to exist
    if ! getent group "${group}" &>/dev/null; then
        groupadd "${group}"
        log_info "  Created group: ${group}"
    else
        log_info "  Group already exists: ${group}"
    fi

    # 2. Create the user
    # --create-home  creates /home/username
    # --gid          sets primary group
    # --shell        sets login shell
    if ! user_exists "${username}"; then
        useradd \
            --create-home \
            --gid "${group}" \
            --shell "${shell}" \
            "${username}"
        log_info "  Created user: ${username}"
    else
        log_info "  User already exists: ${username}"
    fi

    # 3. Configure sudo access via /etc/sudoers.d/
    # chmod 440 is required - sudo refuses files with wrong permissions
    sudoers_file="/etc/sudoers.d/${username}"
    if [[ "${sudo_access}" == "yes" ]]; then
        echo "${username} ALL=(ALL) NOPASSWD:ALL" > "${sudoers_file}"
        chmod 440 "${sudoers_file}"
        log_info "  Granted sudo to: ${username}"
    else
        [[ -f "${sudoers_file}" ]] && rm -f "${sudoers_file}"
        log_info "  No sudo for: ${username}"
    fi

    # 4. Add to docker group if it already exists
    if getent group docker &>/dev/null; then
        usermod -aG docker "${username}"
        log_info "  Added ${username} to docker group"
    fi

done

# 5. Create /app directory owned by appuser
log_info "Setting up /app directory"
mkdir -p /app

if user_exists "appuser"; then
    chown appuser:appuser /app
    chmod 750 /app
    log_info "  /app created, owned by appuser"
else
    log_warn "  appuser not found - /app created without chown"
fi

log_info "User management complete."