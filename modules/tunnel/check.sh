#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
[ "$(docker inspect -f '{{.State.Running}}' cloudflared 2>/dev/null)" = true ] || die "cloudflared not running"
docker logs cloudflared 2>&1 | grep "Registered tunnel connection" >/dev/null || die "no tunnel connection registered (docker logs cloudflared)"
echo "ok   cloudflared running and connected"
