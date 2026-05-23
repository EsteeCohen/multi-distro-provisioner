#!/usr/bin/env bash
# setup_docker.sh ג€” installs Docker Engine from Docker's official repository.
#
# Closes #5
#
# WHY not just "apt install docker.io"?
#   Linux distros ship their own packaged version of Docker, which is often
#   months behind. Docker's official repo always has the latest stable version.
#   In production you always install from the official source.
#
# WHY do we need a GPG key?
#   When you download a package, how do you know it hasn't been tampered with?
#   Docker signs their packages with a GPG key. Your system checks that signature
#   before installing. If the signature doesn't match, apt/dnf refuses to install.
#   This protects against supply chain attacks (malicious packages).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_root
log_step "Phase 4: Docker Installation"

distro="$(detect_distro)"
log_info "Detected distro: ${distro}"

# ג”€ג”€ Already installed? ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
if is_installed docker; then
    log_info "Docker is already installed ג€” skipping"
    docker --version
else
    case "${distro}" in

        # ג”€ג”€ Ubuntu ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
        ubuntu|debian)
            log_info "Installing Docker on Ubuntu"

            # Step 1: Install tools needed to add the Docker repo
            # ca-certificates ג†’ allows curl to verify HTTPS certificates
            # curl            ג†’ downloads files from the internet
            # gnupg           ג†’ handles GPG key import
            log_info "Installing prerequisites"
            apt-get update -qq
            apt-get install -y ca-certificates curl gnupg

            # Step 2: Add Docker's GPG key
            # WHY /etc/apt/keyrings/?
            #   This directory is the modern standard place for repo GPG keys.
            #   apt will use this key to verify packages from Docker's repo.
            log_info "Adding Docker GPG key"
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            # Step 3: Add Docker's apt repository
            # WHY this format?
            #   /etc/apt/sources.list.d/ is where you put extra repos.
            #   Each line tells apt: "look here for packages, and verify
            #   them with this GPG key, for this architecture and distro version."
            #
            # $(dpkg --print-architecture)  ג†’ e.g. "amd64"
            # $(. /etc/os-release && echo "$VERSION_CODENAME") ג†’ e.g. "jammy"
            log_info "Adding Docker apt repository"
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
                | tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Step 4: Install Docker Engine
            # docker-ce              ג†’ Docker Community Edition (the main engine)
            # docker-ce-cli          ג†’ the "docker" command you type in the terminal
            # containerd.io          ג†’ the container runtime docker-ce runs on top of
            # docker-buildx-plugin   ג†’ for building multi-platform images
            # docker-compose-plugin  ג†’ docker compose v2
            log_info "Installing Docker Engine"
            apt-get update -qq
            apt-get install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin
            ;;

        # ג”€ג”€ Fedora ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
        fedora|rhel|centos)
            log_info "Installing Docker on Fedora"

            # dnf-plugins-core provides the "dnf config-manager" command
            # which is used to add new repositories
            log_info "Installing prerequisites"
            dnf install -y dnf-plugins-core

            # Add Docker's official Fedora repository
            log_info "Adding Docker dnf repository"
            dnf config-manager --add-repo \
                https://download.docker.com/linux/fedora/docker-ce.repo

            # Install Docker Engine (same packages, different package manager)
            log_info "Installing Docker Engine"
            dnf install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin
            ;;

        *)
            log_error "Unsupported distro: ${distro}"
            exit 1
            ;;
    esac
fi

# ג”€ג”€ Enable and start Docker daemon ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY is Docker a "daemon"?
#   A daemon is a background process that runs continuously.
#   The Docker daemon (dockerd) manages containers, images, networks, and volumes.
#   When you run "docker run nginx", your docker CLI talks to dockerd via a socket.
#
# /var/run/docker.sock is the Unix socket file ג€” the communication channel
# between the docker CLI and the dockerd daemon.
log_info "Enabling Docker daemon"
systemctl enable docker
systemctl start docker

if systemctl is-active --quiet docker; then
    log_info "Docker daemon is running"
else
    log_error "Docker daemon failed to start ג€” check: journalctl -u docker"
    exit 1
fi

# ג”€ג”€ Add users to the docker group ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY a docker group?
#   By default, only root can talk to /var/run/docker.sock.
#   Adding a user to the "docker" group gives them access to that socket,
#   which means they can run docker commands without sudo.
#
# WHY is this a security consideration?
#   Anyone in the docker group can effectively get root access by running:
#   docker run -v /:/host alpine chroot /host
#   This is why we only add trusted users (devops, appuser) ג€” not everyone.
log_info "Adding users to docker group"

for user in devops appuser; do
    if user_exists "${user}"; then
        # usermod -aG = modify user, Append to supplementary Group
        # -a is critical: without it, usermod REPLACES all groups instead of adding
        usermod -aG docker "${user}"
        log_info "  Added ${user} to docker group"
    else
        log_warn "  User ${user} does not exist yet ג€” skipping"
    fi
done

# ג”€ג”€ Smoke test ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
# WHY hello-world?
#   This is the official Docker test image. It:
#   1. Pulls the image from Docker Hub (tests internet + Docker Hub access)
#   2. Creates a container
#   3. Prints a message
#   4. Exits
#   If this works, Docker is fully functional.
log_info "Running Docker smoke test"
docker run --rm hello-world && log_info "Docker smoke test passed"

log_info "Docker installation complete."
log_warn "NOTE: Users must log out and back in for docker group membership to take effect"