#!/usr/bin/env bash
. "$(dirname "$0")/../../lib/common.sh"
tailscale status >/dev/null 2>&1 || die "tailscale not logged in"
echo "ok   tailscale up at $(tailscale ip -4 | head -1)"
