#!/usr/bin/env bash
# create_users.sh — reads config/users.conf and creates users on the system.
# Implemented in: feat/phase-1-users (Issue #2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_root

log_step "Phase 1: User Management"
log_warn "Not yet implemented — coming in feat/phase-1-users"