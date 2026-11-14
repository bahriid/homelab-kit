#!/usr/bin/env bash
# navidrome: music server behind Caddy, admin created before the host goes public.
. "$(dirname "$0")/../../lib/common.sh"
need MUSIC_HOST
MUSIC_DIR="${MUSIC_DIR:-/srv/music}"
ADMIN_USER="${ADMIN_USER:-admin}"
dir="$HOMELAB_DIR/navidrome"
mkdir -p "$dir"
[ -d "$MUSIC_DIR" ] || as_root mkdir -p "$MUSIC_DIR"

extra=""
if [ -n "${EXTRA_LIBRARY:-}" ]; then
  [ -d "$EXTRA_LIBRARY" ] || as_root mkdir -p "$EXTRA_LIBRARY"
  extra="      - $EXTRA_LIBRARY:/music-extra:ro"
fi

cat > "$dir/docker-compose.yml" <<EOF
services:
  app:
    image: deluan/navidrome:latest
    container_name: navidrome
    restart: unless-stopped
    environment:
      ND_MUSICFOLDER: /music
      ND_SCANSCHEDULE: 1h
      ND_REVERSEPROXYWHITELIST: 172.16.0.0/12
    volumes:
      - navidrome_data:/data
      - $MUSIC_DIR:/music:ro
$extra
    networks: [web]
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:4533/ping"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  web:
    external: true
volumes:
  navidrome_data:
EOF
(cd "$dir" && docker compose up -d)

# Navidrome makes the first visitor admin: claim it now, from inside the docker network.
pw_file="$dir/.admin-password"
if [ ! -s "$pw_file" ]; then
  for _ in $(seq 1 30); do
    docker exec navidrome wget -q -O /dev/null http://localhost:4533/ping 2>/dev/null && break; sleep 2
  done
  pw="$(secret)"
  ( umask 077; printf '%s\n' "$pw" > "$pw_file" )
  body=$(printf '{"username":"%s","password":"%s"}' "$ADMIN_USER" "$pw")
  if docker exec navidrome wget -q -O /dev/null --header 'Content-Type: application/json' \
       --post-data "$body" http://localhost:4533/auth/createAdmin 2>/dev/null; then
    log "admin '$ADMIN_USER' created; password in $pw_file"
  else
    rm -f "$pw_file"
    warn "could not create admin (already exists?). If nobody created it, do it in the browser NOW, before routing the host."
  fi
fi

add_site "$MUSIC_HOST" navidrome:4533
log "navidrome at $MUSIC_HOST (route it with modules/tunnel/route.sh if you use the tunnel)"
