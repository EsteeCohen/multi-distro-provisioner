#!/usr/bin/env bash
# setup_firewall.sh — Ubuntu firewall using ufw.
# Implemented in: feat/phase-3-firewall (Issue #4)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"

check_root

log_step "Phase 3: Firewall (ufw) — Ubuntu"
log_warn "Not yet implemented — coming in feat/phase-3-firewall"