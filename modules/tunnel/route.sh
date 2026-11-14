#!/usr/bin/env bash
# route.sh <host>: CNAME <host> to this tunnel, then confirm over DNS-over-HTTPS.
. "$(dirname "$0")/../../lib/common.sh"
host="${1:-}"; [ -n "$host" ] || die "usage: route.sh <host>"
name="$(cat "$HOMELAB_DIR/tunnel/.tunnel-name" 2>/dev/null || echo "${TUNNEL_NAME:-home}")"

cloudflared tunnel route dns "$name" "$host"

for _ in 1 2 3 4 5 6; do
  ans="$(curl -s "https://cloudflare-dns.com/dns-query?name=$host&type=A" -H 'accept: application/dns-json')"
  if printf '%s' "$ans" | grep '"Status":0' >/dev/null && printf '%s' "$ans" | grep '"Answer"' >/dev/null; then
    log "$host resolves (proxied by Cloudflare)"; exit 0
  fi
  sleep 5
done
die "$host does not resolve yet. Check the Cloudflare dashboard: the record may have landed in another zone (see MODULE.md)."
