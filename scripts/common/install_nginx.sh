#!/usr/bin/env bash
# install_nginx.sh — installs and configures nginx using the correct package manager.
# Implemented in: feat/phase-2-nginx (Issue #3)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_root

log_step "Phase 2: nginx Installation"
log_warn "Not yet implemented — coming in feat/phase-2-nginx"