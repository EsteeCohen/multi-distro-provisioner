# multi-distro-provisioner

Automated Linux infrastructure lab — provisions secure, configured environments
on both **Ubuntu 22.04** and **Fedora 39** from a single codebase.

Built as a deep-dive into system automation for RedHat certification preparation.

---

## What it does

Runs the same provisioning logic across two different Linux distros:

- Creates users with proper permissions and sudo delegation
- Installs and configures nginx as a systemd-managed web server
- Configures the firewall (ufw on Ubuntu, firewalld on Fedora)
- Installs Docker and adds users to the docker group
- Deploys custom systemd service units
- Sets up log monitoring with journalctl

## Quick Start

```bash
# Start both VMs
make up

# Provision Ubuntu
make provision-ubuntu

# Provision Fedora
make provision-fedora

# Provision both
make provision-all

# SSH into a VM
make ssh-ubuntu
make ssh-fedora

# Destroy everything
make down
```

## Requirements

- [Vagrant](https://www.vagrantup.com/) >= 2.3
- [VirtualBox](https://www.virtualbox.org/) >= 7.0

## Architecture

See [docs/architecture.md](docs/architecture.md) for full diagrams and tables.

```
Host Machine
├── ubuntu-node  (192.168.56.10)
│   ├── nginx    (port 80)
│   ├── Docker
│   └── ufw firewall
└── fedora-node  (192.168.56.11)
    ├── nginx    (port 80)
    ├── Docker
    └── firewalld firewall
```

## Project Structure

```
.
├── Vagrantfile
├── Makefile
├── CHECKLIST.md
├── docs/architecture.md
├── config/
│   ├── users.conf
│   └── nginx/default.conf
├── scripts/
│   ├── common/
│   │   ├── utils.sh
│   │   ├── create_users.sh
│   │   ├── install_nginx.sh
│   │   ├── setup_docker.sh
│   │   └── monitor_logs.sh
│   ├── ubuntu/
│   │   ├── provision.sh
│   │   └── setup_firewall.sh
│   └── fedora/
│       ├── provision.sh
│       └── setup_firewall.sh
└── systemd/
    ├── nginx-monitor.service
    └── log-alert.service
```

## Skills Demonstrated

| Skill                    | Tool/Command                          |
|--------------------------|---------------------------------------|
| User management          | useradd, usermod, /etc/sudoers.d/     |
| Package management       | apt (Ubuntu), dnf (Fedora)            |
| Web server               | nginx, systemctl                      |
| Firewall                 | ufw (Ubuntu), firewalld (Fedora)      |
| Containerization         | Docker Engine                         |
| Service management       | systemd unit files                    |
| Log analysis             | journalctl, grep, awk                 |
| Scripting                | Bash with error handling              |
| Automation               | Vagrant + shell provisioning          |
