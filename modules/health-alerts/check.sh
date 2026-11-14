#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
systemctl is-active homelab-health.timer >/dev/null || die "homelab-health.timer not active"
[ "$(systemctl show -p Result --value homelab-health.service)" = success ] || die "last run failed (journalctl -u homelab-health)"
echo "ok   homelab-health timer active, last run succeeded"
