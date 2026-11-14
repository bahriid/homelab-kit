#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
systemctl is-enabled homelab-backup.timer >/dev/null 2>&1 || die "homelab-backup.timer not enabled"
last="$(as_root tail -1 /var/log/homelab-backup.log 2>/dev/null || true)"
[ -n "$last" ] || die "no backup has run yet (sudo systemctl start homelab-backup.service)"
case "$last" in *" ok") ;; *) die "last backup failed: $last (journalctl -u homelab-backup)";; esac
age=$(( $(date +%s) - $(date -d "${last%% *}" +%s) ))
[ "$age" -lt 129600 ] || die "last backup is older than 36 hours: $last"
echo "ok   last backup $last"
