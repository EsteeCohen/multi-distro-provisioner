# multi-distro-provisioner

> Automated Linux infrastructure lab — provisions secure, configured environments on both **Ubuntu 22.04** and **Fedora 39** from a single codebase.

---

## The Story Behind This Project

Throughout my studies I worked exclusively with Ubuntu. It was the distro I knew, the one covered in courses, the one I was comfortable with. But the more I learned, the more I realized that in the real world — especially in enterprise environments — Ubuntu is just one option among many. RedHat, Fedora, CentOS, and RHEL dominate the server and cloud landscape. Knowing only one distro felt like knowing only one programming language.

So I asked myself: what's the best way to actually learn how different Linux distributions work? Reading about it wasn't enough. I needed to *build* something that runs on both — something that forces me to understand the differences, not just read about them.

That's what this project is. A provisioner that takes a fresh Linux VM and turns it into a fully configured, secure, production-ready machine — automatically — on both Ubuntu and Fedora. Every phase taught me something different: why `apt` and `dnf` behave differently, why `ufw` and `firewalld` have completely different models, how systemd is the common thread across all of them.

This is not just a portfolio project. It's how I actually learned Linux system administration.

---

## What It Does

Spins up two Linux VMs and runs the same provisioning logic on both:

| Phase | What runs | Ubuntu tool | Fedora tool |
|-------|-----------|-------------|-------------|
| 1 | User management | `useradd`, `sudoers.d` | same |
| 2 | Web server | `apt install nginx` | `dnf install nginx` |
| 3 | Firewall | `ufw` | `firewalld` |
| 4 | Docker | Docker apt repo | Docker dnf repo |
| 5 | Bash utilities | `health_check.sh`, `user_report.sh` | same |
| 6 | Log monitoring | `journalctl`, `grep`, `awk` | same |
| 7 | systemd services | `nginx-monitor.service`, `log-alert.timer` | same |

---

## Architecture

```
Your Laptop
├── ubuntu-node  (192.168.56.10 / localhost:8080)
│   ├── Users: devops (sudo), appuser
│   ├── nginx on port 80
│   ├── Docker Engine
│   ├── ufw firewall (ports 22, 80, 443)
│   ├── nginx-monitor.service (auto-restart nginx if down)
│   └── log-alert.timer (hourly log scan)
│
└── fedora-node  (192.168.56.11 / localhost:8081)
    ├── Users: devops (sudo), appuser
    ├── nginx on port 80
    ├── Docker Engine
    ├── firewalld (ssh, http, https services)
    ├── nginx-monitor.service
    └── log-alert.timer
```

---

## Requirements

- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) >= 2.3
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) >= 7.0
- `make` (Windows: `winget install GnuWin32.Make`)

---

## Quick Start

```bash
# Start both VMs (downloads boxes on first run, ~5-10 min)
make up

# Provision Ubuntu
make provision-ubuntu

# Provision Fedora
make provision-fedora

# Open a shell inside each VM
make ssh-ubuntu
make ssh-fedora

# Test nginx from your laptop
curl http://localhost:8080   # Ubuntu
curl http://localhost:8081   # Fedora

# Destroy everything
make down
```

---

## Inside a Provisioned VM

```bash
# Check all services are running
sudo bash /opt/provisioner/scripts/common/health_check.sh

# See all users, groups, and sudo permissions
sudo bash /opt/provisioner/scripts/common/user_report.sh

# Watch the nginx monitor service live
journalctl -u nginx-monitor -f

# Ubuntu: verify firewall
sudo ufw status numbered

# Fedora: verify firewall
sudo firewall-cmd --list-all

# Run the log monitor manually
sudo bash /opt/provisioner/scripts/common/monitor_logs.sh
```

---

## Project Structure

```
.
├── Vagrantfile                    # defines ubuntu-node and fedora-node
├── Makefile                       # shortcuts for all vagrant commands
├── CHECKLIST.md                   # phase-by-phase progress tracker
│
├── docs/
│   └── architecture.md            # diagrams, tables, design decisions
│
├── config/
│   ├── users.conf                 # user definitions (name:group:shell:sudo)
│   └── nginx/default.conf         # nginx virtual host configuration
│
├── scripts/
│   ├── common/                    # distro-agnostic scripts
│   │   ├── utils.sh               # logging, detect_distro, check_root
│   │   ├── create_users.sh        # reads users.conf, creates users
│   │   ├── install_nginx.sh       # installs and configures nginx
│   │   ├── setup_docker.sh        # installs Docker Engine
│   │   ├── setup_systemd.sh       # installs and enables service units
│   │   ├── nginx_monitor_loop.sh  # runs inside nginx-monitor.service
│   │   ├── monitor_logs.sh        # scans nginx logs, alerts on 5xx
│   │   ├── health_check.sh        # checks nginx, docker, firewall, users
│   │   └── user_report.sh         # prints user/group/sudo report
│   │
│   ├── ubuntu/
│   │   ├── provision.sh           # Ubuntu entry point (called by Vagrant)
│   │   └── setup_firewall.sh      # ufw configuration
│   │
│   └── fedora/
│       ├── provision.sh           # Fedora entry point
│       └── setup_firewall.sh      # firewalld configuration
│
└── systemd/
    ├── nginx-monitor.service      # always-running nginx health monitor
    ├── log-alert.service          # oneshot log scanner
    └── log-alert.timer            # triggers log-alert.service every hour
```

---

## Key Concepts Demonstrated

**Distro differences** — the same goal, achieved with different tools depending on whether you're on a Debian-based or RHEL-based system. Understanding this distinction is foundational for any Linux sysadmin or DevOps role.

**Idempotency** — every script is safe to run multiple times. Running `make provision-ubuntu` twice produces the same result as running it once. This is a core requirement for real automation.

**systemd** — custom `.service` and `.timer` unit files, installed and managed the correct way via `systemctl`. The nginx monitor restarts nginx automatically if it goes down. The log-alert timer runs every hour without cron.

**Security model** — `devops` gets sudo, `appuser` does not. Both get Docker group access. The `/app` directory is owned by `appuser`. Sudoers files are in `/etc/sudoers.d/` with `chmod 440`.

**CI with GitHub Actions** — every PR that touches `scripts/` triggers shellcheck, which lints all bash scripts before merge.

---

## What I Learned

- The difference between `apt` (Debian/Ubuntu) and `dnf` (Fedora/RHEL) goes deeper than syntax — they have different dependency resolution models and repository structures
- `ufw` is a simplified frontend over `iptables`; `firewalld` uses a zone-based model that maps better to enterprise network segmentation
- systemd timers are strictly better than cron for system services — they log to the journal, integrate with `systemctl status`, and handle missed runs via `Persistent=true`
- `set -euo pipefail` is not optional in serious bash scripts — without it, failures are silent
- Writing automation that works on two different distros forces you to understand both deeply, not just one superficially
