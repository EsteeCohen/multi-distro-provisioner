#!/usr/bin/env bash
# utils.sh -- shared functions sourced by every other script.
#
# WHY a shared utils file?
#   Every script needs to print logs, detect the distro, and check for root.
#   Without utils.sh each script would copy-paste the same code. If you
#   want to change the log format you'd have to edit 8 files. With utils.sh
#   you change it once.
#
# HOW to use in other scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/../common/utils.sh"

# - set -euo pipefail -
# WHY these three flags together?
#   -e  -> exit immediately if any command fails (returns non-zero exit code)
#   -u  -> treat unset variables as errors (catches typos like $HOEM)
#   -o pipefail -> if any command in a pipe fails, the whole pipe fails
#                 without this: "failing_cmd | echo ok" would succeed
set -euo pipefail

# - Color codes -
# ANSI escape codes for terminal colors. \033 is the escape character.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'   # NC = No Color -- resets back to default

# - Logging functions -
# WHY prefix with a timestamp?
#   When provisioning takes 2 minutes, you want to know which step is slow.

log_info() {
    echo -e "${GREEN}[INFO]${NC}  $(date '+%H:%M:%S') $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $*"
}

log_error() {
    # Writes to stderr (>&2) so errors don't pollute piped output
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" >&2
}

log_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# - Root check -
# WHY check for root?
#   useradd, apt install, systemctl all require root. Failing 10 commands
#   in with "Permission denied" is confusing. Fail fast with a clear message.
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "This script must be run as root. Try: sudo $0"
        exit 1
    fi
}

# - Distro detection -
# WHY /etc/os-release?
#   It's the standard file for distro identification on all modern Linux
#   systems. Both Ubuntu and Fedora (and RHEL, Debian, etc.) ship it.
#   'source' reads it as shell variables, giving us $ID and $VERSION_ID.
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID}"   # returns: ubuntu, fedora, rhel, centos, etc.
    else
        log_error "Cannot detect distro: /etc/os-release not found"
        exit 1
    fi
}

# - Package manager helper -
# Returns the correct package manager command for the current distro
get_pkg_manager() {
    local distro
    distro="$(detect_distro)"
    case "${distro}" in
        ubuntu|debian)  echo "apt-get" ;;
        fedora)         echo "dnf" ;;
        rhel|centos)    echo "dnf" ;;
        *)
            log_error "Unsupported distro: ${distro}"
            exit 1
            ;;
    esac
}

# - Idempotency helper -
# WHY check if something is already installed before installing?
#   Running a script twice should produce the same result as running it once.
#   This property is called "idempotency" -- critical for automation.
is_installed() {
    command -v "$1" &>/dev/null
}

user_exists() {
    id "$1" &>/dev/null
}

service_enabled() {
    systemctl is-enabled "$1" &>/dev/null
}