#!/usr/bin/env bash
# health-alerts: Telegram alerts for quiet failures. Run with sudo.
. "$(dirname "$0")/../../lib/common.sh"
[ "$(id -u)" -eq 0 ] || die "run with sudo (sudo -E keeps TG_TOKEN from your shell)"
conf=/etc/homelab-health.env
touch "$conf"; chmod 600 "$conf"
# shellcheck disable=SC1090
. "$conf"
need TG_TOKEN TG_CHAT

{
  printf 'TG_TOKEN=%q\n' "$TG_TOKEN"
  printf 'TG_CHAT=%q\n' "$TG_CHAT"
  printf 'HEALTH_MOUNTS=%q\n' "${HEALTH_MOUNTS:-}"
  printf 'DISK_MAX=%q\n' "${DISK_MAX:-90}"
  printf 'BACKUP_LOG=%q\n' "${BACKUP_LOG:-/var/log/homelab-backup.log}"
} > "$conf"

install -m 755 "$(dirname "$0")/homelab-health" /usr/local/bin/homelab-health
timer homelab-health "Check for quiet failures and alert Telegram" "OnBootSec=5min
OnUnitActiveSec=10min" /usr/local/bin/homelab-health
log "checking every 10 minutes. Test: sudo homelab-health --test"
