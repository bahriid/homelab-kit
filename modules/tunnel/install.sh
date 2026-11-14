#!/usr/bin/env bash
# tunnel: locally-managed Cloudflare Tunnel, all traffic to caddy:80.
. "$(dirname "$0")/../../lib/common.sh"
TUNNEL_NAME="${TUNNEL_NAME:-home}"
dir="$HOMELAB_DIR/tunnel"

if ! command -v cloudflared >/dev/null; then
  log "installing cloudflared"
  arch="$(dpkg --print-architecture)"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/cf.deb" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arch.deb"
  as_root dpkg -i "$tmp/cf.deb" >/dev/null
  rm -rf "$tmp"
fi

[ -s "$HOME/.cloudflared/cert.pem" ] || die "not logged in. Ask the person to run: cloudflared tunnel login  (then rerun this script)"

id="$(cloudflared tunnel list --name "$TUNNEL_NAME" -o json 2>/dev/null \
  | python3 -c 'import sys,json; d=json.load(sys.stdin) or []; print(d[0]["id"] if d else "")')"
if [ -z "$id" ]; then
  log "creating tunnel $TUNNEL_NAME"
  cloudflared tunnel create "$TUNNEL_NAME" >/dev/null
  id="$(cloudflared tunnel list --name "$TUNNEL_NAME" -o json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["id"])')"
fi

mkdir -p "$dir"
if [ ! -f "$dir/credentials.json" ]; then
  cp "$HOME/.cloudflared/$id.json" "$dir/credentials.json"
  # the cloudflared image runs as uid 65532 and must read it; nobody else may
  as_root chown 65532:65532 "$dir/credentials.json"
  as_root chmod 600 "$dir/credentials.json"
fi

cat > "$dir/config.yml" <<EOF
tunnel: $id
credentials-file: /etc/cloudflared/credentials.json
no-autoupdate: true
ingress:
  - service: http://caddy:80
EOF

cat > "$dir/docker-compose.yml" <<'EOF'
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./:/etc/cloudflared:ro
    networks: [web]

networks:
  web:
    external: true
EOF

(cd "$dir" && docker compose up -d)
printf '%s\n' "$TUNNEL_NAME" > "$dir/.tunnel-name"
log "tunnel $TUNNEL_NAME ($id) running. Route hosts with: bash modules/tunnel/route.sh <host>"
