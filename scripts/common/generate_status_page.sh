#!/usr/bin/env bash
# generate_status_page.sh -- generates /var/www/html/index.html with system info.
# Called by install_nginx.sh at provision time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

DISTRO="$(detect_distro)"
HOSTNAME_FULL="$(hostname -f)"
OS_PRETTY="$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
DISK_USAGE="$(df -h / | awk 'NR==2 {print $5}')"
PROVISION_TIME="$(date '+%Y-%m-%d %H:%M UTC')"
WEB_ROOT="/var/www/html"

if [[ "${DISTRO}" == "ubuntu" || "${DISTRO}" == "debian" ]]; then
    PRIMARY="#E95420"
    ACCENT="#77216F"
    DISTRO_LABEL="Ubuntu 22.04 LTS"
    FIREWALL_TYPE="ufw"
    PKG_MANAGER="apt"
    HOST_PORT="8080"
    VM_IP="192.168.56.10"
    FIREWALL_RULES='22/tcp (SSH)|80/tcp (HTTP)|443/tcp (HTTPS)'
else
    PRIMARY="#3C6EB4"
    ACCENT="#294172"
    DISTRO_LABEL="Fedora 39"
    FIREWALL_TYPE="firewalld"
    PKG_MANAGER="dnf"
    HOST_PORT="8081"
    VM_IP="192.168.56.11"
    FIREWALL_RULES='ssh|http|https|dhcpv6-client'
fi

mkdir -p "${WEB_ROOT}"

cat > "${WEB_ROOT}/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${HOSTNAME_FULL} -- multi-distro-provisioner</title>
<style>
  :root {
    --primary: ${PRIMARY};
    --accent:  ${ACCENT};
    --bg:      #0f1117;
    --surface: #1a1d27;
    --surface2:#252836;
    --border:  #2e3147;
    --text:    #e2e8f0;
    --muted:   #64748b;
    --green:   #22c55e;
    --red:     #ef4444;
    --yellow:  #f59e0b;
  }
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', -apple-system, sans-serif; background: var(--bg); color: var(--text); font-size: 14px; min-height: 100vh; }
  header { background: linear-gradient(135deg, var(--primary), var(--accent)); padding: 24px 28px; }
  header h1 { font-size: 1.6em; font-weight: 800; }
  header p  { margin-top: 5px; opacity: .85; font-size: .9em; }
  .status-bar {
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 10px 28px;
    display: flex; align-items: center; gap: 16px;
    font-size: .8em; color: var(--muted); flex-wrap: wrap;
  }
  .status-bar .sep { opacity: .3; }
  .hdot { width: 8px; height: 8px; border-radius: 50%; background: var(--muted); display: inline-block; margin-right: 4px; vertical-align: middle; }
  .hdot.online { background: var(--green); box-shadow: 0 0 6px var(--green); animation: pulse 2.5s infinite; }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.4} }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; padding: 22px 28px; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 16px; }
  .card-title { font-size: .68em; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; color: var(--muted); margin-bottom: 12px; }
  .row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid var(--border); gap: 8px; font-size: .85em; }
  .row:last-child { border-bottom: none; }
  .rkey { color: var(--muted); }
  .rval { font-family: 'Consolas','Monaco',monospace; font-size: .9em; text-align: right; }
  .badge { padding: 2px 8px; border-radius: 4px; font-size: .7em; font-weight: 700; font-family: monospace; flex-shrink: 0; }
  .badge.running { background: rgba(34,197,94,.12); color: var(--green); border: 1px solid rgba(34,197,94,.3); }
  .badge.waiting { background: rgba(245,158,11,.12); color: var(--yellow); border: 1px solid rgba(245,158,11,.3); }
  .tag { display: inline-block; padding: 3px 8px; margin: 2px; border-radius: 4px; background: var(--surface2); border: 1px solid var(--border); font-family: monospace; font-size: .76em; }
  .tags { margin-top: 8px; }
  .cmd-row { padding: 9px 0; border-bottom: 1px solid var(--border); }
  .cmd-row:last-child { border-bottom: none; }
  .cmd-label { font-size: .7em; color: var(--muted); margin-bottom: 4px; text-transform: uppercase; letter-spacing: .5px; }
  .cmd-val { font-family: 'Consolas','Monaco',monospace; font-size: .8em; word-break: break-all; line-height: 1.5; }
  .dashboard-link { display: inline-block; margin: 4px 28px 20px; padding: 7px 16px; background: var(--surface); border: 1px solid var(--border); border-radius: 6px; font-size: .82em; color: var(--text); text-decoration: none; transition: border-color .2s; }
  .dashboard-link:hover { border-color: var(--primary); }
  footer { padding: 16px 28px; color: var(--muted); font-size: .75em; border-top: 1px solid var(--border); }
</style>
</head>
<body>

<header>
  <h1>${HOSTNAME_FULL}</h1>
  <p>${DISTRO_LABEL} &nbsp;&middot;&nbsp; multi-distro-provisioner &nbsp;&middot;&nbsp; host port ${HOST_PORT}</p>
</header>

<div class="status-bar">
  <span><span class="hdot online" id="h-dot"></span><span id="h-status">nginx: checking&hellip;</span></span>
  <span class="sep">|</span>
  <span>IP: ${VM_IP}</span>
  <span class="sep">|</span>
  <span>Disk: ${DISK_USAGE}</span>
  <span class="sep">|</span>
  <span>Provisioned: ${PROVISION_TIME}</span>
</div>

<div class="grid">

  <div class="card">
    <div class="card-title">Services</div>
    <div class="row"><span class="rkey">nginx</span>                  <span class="badge running">running</span></div>
    <div class="row"><span class="rkey">docker</span>                 <span class="badge running">running</span></div>
    <div class="row"><span class="rkey">nginx-monitor.service</span> <span class="badge running">running</span></div>
    <div class="row"><span class="rkey">log-alert.timer</span>       <span class="badge waiting">waiting</span></div>
  </div>

  <div class="card">
    <div class="card-title">Firewall &mdash; ${FIREWALL_TYPE}</div>
    <div class="tags">
HTML

IFS='|' read -ra _rules <<< "${FIREWALL_RULES}"
for _r in "${_rules[@]}"; do
    _r="$(echo "${_r}" | xargs)"
    printf '      <span class="tag">%s</span>\n' "${_r}" >> "${WEB_ROOT}/index.html"
done

cat >> "${WEB_ROOT}/index.html" <<HTML
    </div>
  </div>

  <div class="card">
    <div class="card-title">Users</div>
    <div class="row"><span class="rkey">devops</span>  <span class="rval">sudo &middot; docker group</span></div>
    <div class="row"><span class="rkey">appuser</span> <span class="rval">docker group &middot; /app</span></div>
    <div class="row"><span class="rkey">sudoers</span> <span class="rval">/etc/sudoers.d/devops</span></div>
  </div>

  <div class="card">
    <div class="card-title">System</div>
    <div class="row"><span class="rkey">distro</span>          <span class="rval">${OS_PRETTY}</span></div>
    <div class="row"><span class="rkey">package manager</span> <span class="rval">${PKG_MANAGER}</span></div>
    <div class="row"><span class="rkey">provisioner</span>     <span class="rval">/opt/provisioner</span></div>
  </div>

  <div class="card">
    <div class="card-title">Useful Commands (run inside VM)</div>
    <div class="cmd-row">
      <div class="cmd-label">health check</div>
      <div class="cmd-val">sudo bash /opt/provisioner/scripts/common/health_check.sh</div>
    </div>
    <div class="cmd-row">
      <div class="cmd-label">user report</div>
      <div class="cmd-val">sudo bash /opt/provisioner/scripts/common/user_report.sh</div>
    </div>
    <div class="cmd-row">
      <div class="cmd-label">monitor logs</div>
      <div class="cmd-val">journalctl -u nginx-monitor -f</div>
    </div>
  </div>

</div>

<a class="dashboard-link" href="/dashboard.html">View full comparison dashboard &rarr;</a>

<footer>multi-distro-provisioner &nbsp;&middot;&nbsp; Provisioned ${PROVISION_TIME}</footer>

<script>
async function checkHealth() {
  const dot    = document.getElementById('h-dot');
  const status = document.getElementById('h-status');
  try {
    const ctrl = new AbortController();
    const t    = setTimeout(() => ctrl.abort(), 5000);
    const res  = await fetch('/health', { signal: ctrl.signal, cache: 'no-store' });
    clearTimeout(t);
    if (res.ok) {
      dot.classList.add('online');
      status.textContent = 'nginx: online';
    } else {
      dot.style.background = '#ef4444';
      status.textContent = 'nginx: HTTP ' + res.status;
    }
  } catch(e) {
    dot.style.background = '#ef4444';
    status.textContent = 'nginx: ' + (e.name === 'AbortError' ? 'timeout' : 'unreachable');
  }
}
checkHealth();
setInterval(checkHealth, 30000);
</script>
</body>
</html>
HTML

log_info "  Status page generated at ${WEB_ROOT}/index.html"