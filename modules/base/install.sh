#!/usr/bin/env bash
# base: harden a fresh Ubuntu/Debian host and install Docker. Run with sudo.
. "$(dirname "$0")/../../lib/common.sh"
[ "$(id -u)" -eq 0 ] || die "run with sudo"

DEPLOY_USER="${DEPLOY_USER:-${SUDO_USER:-}}"
need DEPLOY_USER
id "$DEPLOY_USER" >/dev/null 2>&1 || die "user $DEPLOY_USER does not exist"

log "packages + automatic security updates"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q ca-certificates curl unattended-upgrades openssl
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null

log "SSH: keys only"
keys="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)/.ssh/authorized_keys"
if [ -s "$keys" ]; then
  cat > /etc/ssh/sshd_config.d/00-homelab.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
X11Forwarding no
EOF
  sshd -t && systemctl reload ssh
else
  warn "$keys is empty: left SSH password login ON so nobody gets locked out. Add a key, then rerun."
fi

if ! command -v docker >/dev/null; then
  log "Docker"
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$DEPLOY_USER"
ensure_network web
ensure_network db

if [ -n "${TZ:-}" ]; then timedatectl set-timezone "$TZ"; fi
echo 'vm.swappiness=10' > /etc/sysctl.d/99-homelab.conf
sysctl -q --system

mkdir -p "$HOMELAB_DIR"
chown "$DEPLOY_USER": "$HOMELAB_DIR"

log "done. $DEPLOY_USER: log out and back in for the docker group."
