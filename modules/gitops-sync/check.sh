#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
systemctl is-active homelab-sync.timer >/dev/null || die "homelab-sync.timer not active"
[ "$(systemctl show -p Result --value homelab-sync.service)" = success ] || die "last homelab-sync run failed (journalctl -u homelab-sync)"
echo "ok   homelab-sync timer active, last run succeeded"
