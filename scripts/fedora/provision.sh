#!/usr/bin/env bash
# provision.sh ג€” Fedora entry point. Called by Vagrant on first boot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"

check_root
log_step "Provisioning fedora-node"

bash "${SCRIPT_DIR}/../common/create_users.sh"
bash "${SCRIPT_DIR}/../common/install_nginx.sh"
bash "${SCRIPT_DIR}/setup_firewall.sh"
bash "${SCRIPT_DIR}/../common/setup_docker.sh"
bash "${SCRIPT_DIR}/../common/setup_systemd.sh"

log_info "Provisioning complete."