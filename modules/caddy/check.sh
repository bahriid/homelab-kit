#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
[ "$(docker inspect -f '{{.State.Running}}' caddy 2>/dev/null)" = true ] || die "caddy not running"
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || die "Caddyfile invalid"
echo "ok   caddy running, Caddyfile valid"
