#!/usr/bin/env bash
# nextcloud: Nextcloud + own Postgres + Redis + cron container, behind Caddy.
. "$(dirname "$0")/../../lib/common.sh"
need CLOUD_HOST
CLOUD_DATA="${CLOUD_DATA:-/srv/nextcloud-data}"
dir="$HOMELAB_DIR/nextcloud"
mkdir -p "$dir"
ensure_network web

[ -d "$CLOUD_DATA" ] || as_root mkdir -p "$CLOUD_DATA"
as_root chown 33:33 "$CLOUD_DATA"     # www-data inside the image

env="$dir/.env"
env_set "$env" POSTGRES_DB nextcloud
env_set "$env" POSTGRES_USER nextcloud
env_set "$env" POSTGRES_PASSWORD "$(secret)"
env_set "$env" POSTGRES_HOST nextcloud-db
env_set "$env" NEXTCLOUD_ADMIN_USER admin
env_set "$env" NEXTCLOUD_ADMIN_PASSWORD "$(secret)"

mounts=""
for m in ${EXTRA_MOUNTS:-}; do mounts+="      - $m:$m"$'\n'; done

app_env="    environment:
      REDIS_HOST: nextcloud-redis
      TRUSTED_PROXIES: 172.16.0.0/12
      OVERWRITEPROTOCOL: https
      OVERWRITEHOST: $CLOUD_HOST
      NEXTCLOUD_TRUSTED_DOMAINS: $CLOUD_HOST
      PHP_UPLOAD_LIMIT: 16G
      PHP_MEMORY_LIMIT: 1G"
vols="    volumes:
      - nextcloud_html:/var/www/html
      - $CLOUD_DATA:/var/www/html/data
${mounts}"

cat > "$dir/docker-compose.yml" <<EOF
services:
  app:
    image: nextcloud:31-apache
    container_name: nextcloud
    restart: unless-stopped
    env_file: .env
$app_env
$vols
    networks: [web, default]
    depends_on: [db, redis]
    healthcheck:
      test: ["CMD", "curl", "-fsS", "-H", "Host: $CLOUD_HOST", "http://localhost/status.php"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 3m

  cron:
    image: nextcloud:31-apache
    container_name: nextcloud-cron
    restart: unless-stopped
    entrypoint: /cron.sh
    env_file: .env
$app_env
$vols
    depends_on: [app]

  db:
    image: postgres:16-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    env_file: .env
    volumes:
      - db_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped

networks:
  web:
    external: true
volumes:
  nextcloud_html:
  db_data:
EOF

(cd "$dir" && docker compose up -d)
add_site "$CLOUD_HOST" nextcloud:80
# CalDAV/CardDAV discovery for phones and calendar apps
file="$HOMELAB_DIR/proxy/Caddyfile"
if ! grep -q "redir /.well-known/carddav" "$file"; then
  backup "$file"
  python3 - "$file" "$CLOUD_HOST" <<'PY'
import sys
path, host = sys.argv[1], sys.argv[2]
s = open(path).read()
for addr in (f"http://{host} {{", f"{host} {{"):
    if addr in s:
        s = s.replace(addr, addr + "\n    request_body {\n        max_size 512MB\n    }"
                      "\n    redir /.well-known/carddav /remote.php/dav 301"
                      "\n    redir /.well-known/caldav /remote.php/dav 301", 1)
        break
open(path, "w").write(s)
PY
  docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
fi
log "nextcloud starting at $CLOUD_HOST (first boot runs the installer, give it a few minutes). Admin login: admin, password in $env"
