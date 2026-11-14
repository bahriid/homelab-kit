#!/usr/bin/env bash
# caddy: shared reverse proxy in $HOMELAB_DIR/proxy.
. "$(dirname "$0")/../../lib/common.sh"
dir="$HOMELAB_DIR/proxy"
mkdir -p "$dir"
ensure_network web

if [ ! -f "$dir/Caddyfile" ]; then
  if [ "$PROXY_MODE" = tunnel ]; then
    cat > "$dir/Caddyfile" <<'EOF'
{
    # Behind Cloudflare Tunnel: TLS ends at Cloudflare, Caddy serves plain HTTP.
    auto_https off
    servers {
        trusted_proxies static private_ranges
    }
}
EOF
  else
    need ACME_EMAIL
    printf '{\n    email %s\n}\n' "$ACME_EMAIL" > "$dir/Caddyfile"
  fi
  log "created $dir/Caddyfile ($PROXY_MODE mode)"
fi

if [ "$PROXY_MODE" = tunnel ]; then ports='      - "80:80"            # LAN only; public traffic comes through the tunnel'
else ports='      - "80:80"
      - "443:443"
      - "443:443/udp"'; fi

cat > "$dir/docker-compose.yml" <<EOF
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
$ports
    volumes:
      - ./:/etc/caddy/:ro      # the folder, not the file (see MODULE.md)
      - caddy_data:/data
      - caddy_config:/config
    networks: [web]

networks:
  web:
    external: true
volumes:
  caddy_data:
  caddy_config:
EOF

(cd "$dir" && docker compose up -d)
log "caddy up in $PROXY_MODE mode"
