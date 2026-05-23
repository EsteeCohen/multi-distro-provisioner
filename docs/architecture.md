# Architecture & Design

## What We're Building

A provisioner that takes a **fresh Linux VM** and turns it into a **configured, secure, production-ready machine** — automatically.
The same logic runs on both Ubuntu and Fedora, showing that you understand the differences between distros.

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Laptop (Host)                        │
│                                                              │
│  ┌──────────────┐         ┌──────────────────────────────┐  │
│  │   Makefile   │────────▶│        Vagrantfile           │  │
│  │ (entry point)│         │  (defines the VMs)           │  │
│  └──────────────┘         └──────────────────────────────┘  │
│                                      │                       │
│                    ┌─────────────────┴──────────────┐        │
│                    ▼                                ▼        │
│           ┌────────────────┐             ┌──────────────────┐│
│           │  ubuntu-node   │             │  fedora-node     ││
│           │  192.168.56.10 │             │  192.168.56.11   ││
│           │                │             │                  ││
│           │ ┌────────────┐ │             │ ┌──────────────┐ ││
│           │ │   nginx    │ │             │ │    nginx     │ ││
│           │ │  (port 80) │ │             │ │  (port 80)   │ ││
│           │ └────────────┘ │             │ └──────────────┘ ││
│           │ ┌────────────┐ │             │ ┌──────────────┐ ││
│           │ │   Docker   │ │             │ │    Docker    │ ││
│           │ └────────────┘ │             │ └──────────────┘ ││
│           │ ┌────────────┐ │             │ ┌──────────────┐ ││
│           │ │    ufw     │ │             │ │  firewalld   │ ││
│           │ │ (firewall) │ │             │ │  (firewall)  │ ││
│           │ └────────────┘ │             │ └──────────────┘ ││
│           └────────────────┘             └──────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Provisioning Flow (runs on every VM)

The provisioner runs top-to-bottom. Each step builds on the previous one.

```
START (fresh VM)
      │
      ▼
┌─────────────────────┐
│  1. DETECT DISTRO   │  ← reads /etc/os-release to know if we're on Ubuntu or Fedora
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  2. CREATE USERS    │  ← creates devops + appuser with specific permissions
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  3. INSTALL nginx   │  ← apt install OR dnf install depending on distro
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  4. FIREWALL RULES  │  ← ufw (Ubuntu) OR firewalld (Fedora), open port 80/443
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  5. INSTALL DOCKER  │  ← add docker repo, install, add user to docker group
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  6. SYSTEMD SETUP   │  ← enable nginx + our custom monitor.service
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  7. LOG MONITORING  │  ← set up journalctl filters + custom log parser
└─────────┬───────────┘
          │
          ▼
       DONE ✓
```

---

## 3. Distro Comparison Table

This is the core knowledge you need for RedHat certification:
every command has an equivalent, but the tool names differ.

| Task                   | Ubuntu / Debian           | Fedora / RHEL / CentOS       |
|------------------------|---------------------------|-------------------------------|
| Package manager        | `apt`                     | `dnf`                        |
| Install a package      | `apt install nginx`       | `dnf install nginx`          |
| Update packages        | `apt update && apt upgrade`| `dnf update`                |
| Firewall tool          | `ufw`                     | `firewalld` (with `firewall-cmd`) |
| Open a port            | `ufw allow 80/tcp`        | `firewall-cmd --add-port=80/tcp --permanent` |
| Reload firewall        | `ufw reload`              | `firewall-cmd --reload`      |
| Service manager        | `systemctl` (same)        | `systemctl` (same)           |
| Enable a service       | `systemctl enable nginx`  | `systemctl enable nginx`     |
| View logs              | `journalctl -u nginx`     | `journalctl -u nginx` (same) |
| Identify distro        | `/etc/os-release`         | `/etc/os-release`            |
| Add user               | `adduser` or `useradd`    | `useradd`                    |
| Sudoers directory      | `/etc/sudoers.d/`         | `/etc/sudoers.d/`            |
| Docker install source  | `apt.docker.com`          | `dnf.docker.com`             |

---

## 4. User & Permissions Model

```
┌─────────────────────────────────────────────┐
│              Users on each VM               │
│                                             │
│  ┌─────────────┐      ┌──────────────────┐  │
│  │   devops    │      │    appuser       │  │
│  │             │      │                  │  │
│  │ • sudo ALL  │      │ • no sudo        │  │
│  │ • in docker │      │ • in docker group│  │
│  │   group     │      │ • owns /app dir  │  │
│  │ • SSH login │      │ • runs nginx     │  │
│  └─────────────┘      └──────────────────┘  │
│                                             │
│  Permission model:                          │
│  /app/          → owned by appuser:appuser  │
│  /etc/nginx/    → owned by root:root        │
│  /var/log/app/  → owned by appuser:appuser  │
└─────────────────────────────────────────────┘
```

---

## 5. Script Directory Structure

```
multi-distro-provisioner/
│
├── Vagrantfile               ← defines Ubuntu + Fedora VMs
├── Makefile                  ← run everything from here
├── CHECKLIST.md              ← project progress tracker
│
├── docs/
│   └── architecture.md       ← this file
│
├── config/
│   ├── users.conf            ← list of users to create (name:group:shell)
│   └── nginx/
│       └── default.conf      ← nginx site configuration
│
├── scripts/
│   ├── common/               ← distro-agnostic scripts
│   │   ├── utils.sh          ← logging, color output, detect_distro()
│   │   ├── create_users.sh   ← reads config/users.conf, creates users
│   │   ├── install_nginx.sh  ← installs + configures nginx
│   │   ├── setup_docker.sh   ← installs docker engine
│   │   └── monitor_logs.sh   ← parses and watches logs
│   │
│   ├── ubuntu/
│   │   ├── provision.sh      ← Ubuntu entry point (calls common scripts)
│   │   └── setup_firewall.sh ← ufw-specific rules
│   │
│   └── fedora/
│       ├── provision.sh      ← Fedora entry point (calls common scripts)
│       └── setup_firewall.sh ← firewalld-specific rules
│
└── systemd/
    ├── nginx-monitor.service ← watches nginx, restarts if down
    └── log-alert.service     ← scans logs and sends alerts
```

---

## 6. systemd Service Model

systemd is the init system — it's what starts everything when Linux boots.
A `.service` file is a plain text file that tells systemd HOW to run your program.

```
┌────────────────────────────────────────────────┐
│           systemd unit lifecycle               │
│                                                │
│   installed ──▶ enabled ──▶ started ──▶ active │
│       ▲                         │              │
│       │     (on failure)        ▼              │
│       └─────────── Restart=on-failure ─────────┘
│                                                │
│  Key commands:                                 │
│   systemctl enable  → start on boot           │
│   systemctl start   → start now               │
│   systemctl status  → see current state        │
│   journalctl -u X   → see logs for unit X     │
└────────────────────────────────────────────────┘
```

---

## 7. Firewall Rules Table

| Rule            | Ubuntu (ufw)                          | Fedora (firewalld)                            |
|-----------------|---------------------------------------|-----------------------------------------------|
| Enable firewall | `ufw enable`                          | `systemctl enable --now firewalld`            |
| Allow SSH       | `ufw allow 22/tcp`                    | `firewall-cmd --add-service=ssh --permanent`  |
| Allow HTTP      | `ufw allow 80/tcp`                    | `firewall-cmd --add-service=http --permanent` |
| Allow HTTPS     | `ufw allow 443/tcp`                   | `firewall-cmd --add-service=https --permanent`|
| Show rules      | `ufw status numbered`                 | `firewall-cmd --list-all`                     |
| Reload          | `ufw reload`                          | `firewall-cmd --reload`                       |
| Default deny    | `ufw default deny incoming`           | (deny is the default zone behavior)           |
