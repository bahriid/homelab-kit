#!/usr/bin/env bash
# backup-restic: nightly restic backup of the stack. Run with sudo.
. "$(dirname "$0")/../../lib/common.sh"
[ "$(id -u)" -eq 0 ] || die "run with sudo"
need RESTIC_REPOSITORY
BACKUP_PATHS="${BACKUP_PATHS:-$HOMELAB_DIR}"

command -v restic >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -q restic

[ -s /root/.restic-pass ] || ( umask 077; secret > /root/.restic-pass )

# keep any credentials the agent or person already put in the file (B2_*, AWS_*, ...)
conf=/etc/homelab-backup.env
touch "$conf"; chmod 600 "$conf"
sed -i '/^\(RESTIC_REPOSITORY\|BACKUP_PATHS\|BACKUP_VOLUMES\)=/d' "$conf"
{
  printf 'RESTIC_REPOSITORY=%q\n' "$RESTIC_REPOSITORY"
  printf 'BACKUP_PATHS=%q\n' "$BACKUP_PATHS"
  printf 'BACKUP_VOLUMES=%q\n' "${BACKUP_VOLUMES:-_data\$|caddy_data}"
} >> "$conf"

export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE=/root/.restic-pass
set -a; . "$conf"; set +a
if ! restic cat config >/dev/null 2>&1; then
  case "$RESTIC_REPOSITORY" in /*) mkdir -p "$RESTIC_REPOSITORY";; esac
  restic init >/dev/null
  log "initialised restic repository at $RESTIC_REPOSITORY"
fi

install -m 755 "$(dirname "$0")/homelab-backup" /usr/local/bin/homelab-backup

requires=""
case "$RESTIC_REPOSITORY" in /*) requires="RequiresMountsFor=$RESTIC_REPOSITORY";; esac
cat > /etc/systemd/system/homelab-backup.service <<EOF
[Unit]
Description=Nightly restic backup of the homelab stack
After=docker.service
$requires

[Service]
Type=oneshot
Environment=HOME=/root
ExecStart=/usr/local/bin/homelab-backup
EOF
cat > /etc/systemd/system/homelab-backup.timer <<'EOF'
[Unit]
Description=Run homelab-backup nightly

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now homelab-backup.timer >/dev/null
log "nightly backup at 03:30. Run one now: sudo systemctl start homelab-backup.service"
warn "copy /root/.restic-pass into a password manager (sudo cat /root/.restic-pass, run it yourself)"
