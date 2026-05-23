#!/usr/bin/env bash
# setup_docker.sh — installs Docker Engine and adds users to the docker group.
# Implemented in: feat/phase-4-docker (Issue #5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_root

log_step "Phase 4: Docker Installation"
log_warn "Not yet implemented — coming in feat/phase-4-docker"