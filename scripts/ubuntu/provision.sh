#!/usr/bin/env bash
# provision.sh — Ubuntu entry point. Called by Vagrant on first boot.
#
# WHY a separate file per distro?
#   Ubuntu and Fedora use different package managers and firewall tools.
#   Each distro entry point calls the same common scripts, but uses its
#   own firewall script. The common/ scripts handle everything else.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/utils.sh"

check_root
log_step "Provisioning ubuntu-node"

bash "${SCRIPT_DIR}/../common/create_users.sh"
bash "${SCRIPT_DIR}/../common/install_nginx.sh"
bash "${SCRIPT_DIR}/setup_firewall.sh"
bash "${SCRIPT_DIR}/../common/setup_docker.sh"

log_info "Provisioning complete."