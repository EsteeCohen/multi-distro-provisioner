#!/usr/bin/env bash
# create_users.sh — reads config/users.conf and creates users on the system.
#
# Closes #2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Path to users.conf — two directories up from scripts/common/
CONFIG_FILE="${SCRIPT_DIR}/../../config/users.conf"

check_root
log_step "Phase 1: User Management"

# ── Read users.conf line by line ─────────────────────────────────────────────
#
# WHY this syntax?
#   IFS=:          → split each line by ":" instead of spaces
#   read -r        → read one line, -r means don't interpret backslashes
#   < "${CONFIG_FILE}" → feed the file into the while loop as input
#
# Each line in users.conf looks like:  devops:devops:/bin/bash:yes
# So: username=devops, group=devops, shell=/bin/bash, sudo_access=yes

while IFS=: read -r username group shell sudo_access; do

    # Skip blank lines and lines starting with # (comments)
    [[ -z "${username}" || "${username}" =~ ^# ]] && continue

    log_info "Processing user: ${username}"

    # ── 1. Create the group ───────────────────────────────────────────────────
    # WHY create the group first?
    #   useradd needs the group to already exist when you assign a user to it.
    #
    # getent group checks the system group database (like grep on /etc/group).
    # &>/dev/null throws away output — we only care if it succeeded or failed.
    if ! getent group "${group}" &>/dev/null; then
        groupadd "${group}"
        log_info "  Created group: ${group}"
    else
        log_info "  Group already exists: ${group}"
    fi

    # ── 2. Create the user ────────────────────────────────────────────────────
    # useradd flags:
    #   --create-home  → create /home/username (without this, no home directory)
    #   --gid          → primary group (the main group shown in ls -l)
    #   --shell        → which shell opens when the user logs in
    #
    # WHY check user_exists first?
    #   Running useradd on an existing user is an error. This makes the
    #   script idempotent — safe to run multiple times without breaking.
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

    # ── 3. Configure sudo access ──────────────────────────────────────────────
    # WHY /etc/sudoers.d/ instead of editing /etc/sudoers directly?
    #   /etc/sudoers.d/ is a directory sudo reads automatically.
    #   Each user gets their own file — cleaner and safer than editing
    #   the main sudoers file (a typo there can lock you out of sudo).
    #
    # chmod 440 = owner can read, group can read, others nothing.
    #   sudo REFUSES to read sudoers files with wrong permissions.
    #   This is a security feature — if anyone could write the file,
    #   they could grant themselves root access.
    #
    # Format: "username ALL=(ALL) NOPASSWD:ALL"
    #   username    → who this rule applies to
    #   ALL         → from any host/terminal
    #   (ALL)       → can run commands as any user (including root)
    #   NOPASSWD    → no password prompt
    #   ALL         → all commands
    sudoers_file="/etc/sudoers.d/${username}"
    if [[ "${sudo_access}" == "yes" ]]; then
        echo "${username} ALL=(ALL) NOPASSWD:ALL" > "${sudoers_file}"
        chmod 440 "${sudoers_file}"
        log_info "  Granted sudo to: ${username}"
    else
        # Remove sudo file if it exists (handles case where sudo was revoked)
        [[ -f "${sudoers_file}" ]] && rm -f "${sudoers_file}"
        log_info "  No sudo for: ${username}"
    fi

    # ── 4. Add to docker group (if it exists) ─────────────────────────────────
    # WHY check if docker group exists?
    #   Docker may not be installed yet at this phase.
    #   We add users here so when Docker IS installed (Phase 4),
    #   these users can already run docker commands without sudo.
    #
    # usermod -aG = modify user, Append to Group (don't remove existing groups)
    if getent group docker &>/dev/null; then
        usermod -aG docker "${username}"
        log_info "  Added ${username} to docker group"
    fi

done < "${CONFIG_FILE}"

# ── 5. Create /app directory ──────────────────────────────────────────────────
# WHY /app?
#   This is where the application files will live.
#   appuser owns it — so the app runs with limited permissions,
#   not as root. If the app is compromised, the attacker only has
#   appuser access, not root access.
#
# chmod 750:
#   7 = owner (appuser) can read, write, execute
#   5 = group can read and execute
#   0 = everyone else: no access
log_info "Setting up /app directory"
mkdir -p /app
chown appuser:appuser /app
chmod 750 /app
log_info "  /app created, owned by appuser"

log_info "User management complete."