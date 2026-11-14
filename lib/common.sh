# shellcheck shell=bash
# Shared helpers for module scripts. Source it: . "$(dirname "$0")/../../lib/common.sh"
set -euo pipefail

HOMELAB_DIR="${HOMELAB_DIR:-/srv/homelab}"
PROXY_MODE="${PROXY_MODE:-tunnel}"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# need VAR [VAR...]: fail with a clear message when an answer is missing.
need() { for v in "$@"; do [ -n "${!v:-}" ] || die "missing $v (see MODULE.md 'asks')"; done; }

# Run as root, or through sudo when we are not.
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

ensure_network() { docker network inspect "$1" >/dev/null 2>&1 || docker network create "$1" >/dev/null; }

# backup FILE: copy to FILE.bak-YYYYmmdd-HHMMSS before editing it.
backup() { [ -e "$1" ] && cp -a "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)" || true; }

# secret: a random 32-char password, letters and digits only.
secret() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

# env_set FILE KEY VALUE: add KEY=VALUE when KEY is missing. Existing values are kept.
env_set() {
  touch "$1"; chmod 600 "$1"
  grep -q "^$2=" "$1" || printf "%s='%s'\n" "$2" "$3" >> "$1"
}

# add_site HOST UPSTREAM: append a Caddy site block once, then reload Caddy.
add_site() {
  local file="$HOMELAB_DIR/proxy/Caddyfile" addr
  [ -f "$file" ] || die "Caddy not installed (run modules/caddy first)"
  if [ "$PROXY_MODE" = tunnel ]; then addr="http://$1"; else addr="$1"; fi
  if grep -q "^$addr {" "$file"; then log "$1 already in Caddyfile"; else
    backup "$file"
    printf '\n%s {\n    reverse_proxy %s\n}\n' "$addr" "$2" >> "$file"
    log "added $1 -> $2"
  fi
  docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
}

# timer UNIT "Description" "OnCalendar" "ExecStart": install a systemd service + timer pair.
timer() {
  as_root tee "/etc/systemd/system/$1.service" >/dev/null <<EOF
[Unit]
Description=$2
After=docker.service network-online.target

[Service]
Type=oneshot
ExecStart=$4
EOF
  as_root tee "/etc/systemd/system/$1.timer" >/dev/null <<EOF
[Unit]
Description=$2 (timer)

[Timer]
$3
Persistent=true

[Install]
WantedBy=timers.target
EOF
  as_root systemctl daemon-reload
  as_root systemctl enable --now "$1.timer" >/dev/null
}
