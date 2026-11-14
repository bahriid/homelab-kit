#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
[ "$(docker inspect -f '{{.State.Health.Status}}' nextcloud 2>/dev/null)" = healthy ] || die "nextcloud not healthy (first boot can take a few minutes)"
[ "$(docker inspect -f '{{.State.Running}}' nextcloud-cron 2>/dev/null)" = true ] || die "nextcloud-cron not running"
echo "ok   nextcloud healthy, cron running"
