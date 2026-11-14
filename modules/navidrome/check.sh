#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
[ "$(docker inspect -f '{{.State.Health.Status}}' navidrome 2>/dev/null)" = healthy ] || die "navidrome not healthy"
echo "ok   navidrome healthy"
