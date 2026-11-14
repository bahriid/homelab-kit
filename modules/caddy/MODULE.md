---
name: caddy
summary: One Caddy reverse proxy for every app, routing by hostname.
requires: [base]
asks:
  - PROXY_MODE: "tunnel" if traffic arrives through Cloudflare Tunnel (no public IP, CGNAT), "direct" if the server has a public IP with ports 80/443 forwarded (default: tunnel)
  - ACME_EMAIL: only for direct mode, the email for Let's Encrypt
---

# caddy

## What you get

`$HOMELAB_DIR/proxy/` with `docker-compose.yml` and `Caddyfile`, container `caddy` on network
`web`. Other modules add their site with `add_site <host> <container:port>` from
`lib/common.sh`, which appends a block and reloads Caddy without a restart.

- **tunnel mode**: Caddy serves plain HTTP on :80, only for the tunnel and the LAN. TLS ends at
  Cloudflare. Site addresses start with `http://`, otherwise Caddy binds :443 and tries to get
  certificates the tunnel never forwards.
- **direct mode**: Caddy publishes 80 and 443 and gets Let's Encrypt certificates itself.

## Install

```bash
PROXY_MODE=tunnel bash modules/caddy/install.sh
```

## Verify

```bash
bash modules/caddy/check.sh
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: test.invalid' http://localhost/   # any code = Caddy answers
```

## Rollback

`cd $HOMELAB_DIR/proxy && docker compose down` (volumes stay).

## Notes

- `trusted_proxies static private_ranges` is set in tunnel mode. Without it Caddy overwrites the
  `X-Forwarded-Proto: https` header from cloudflared with `http`, and apps such as Laravel build
  `http://` asset URLs that the browser blocks (blank or black page).
- The proxy folder is mounted as a directory, not the single `Caddyfile`. Docker pins a single-file
  bind mount to the file's inode; editors and `git pull` replace the file, so a reload would keep
  reading the old one.
- A broken Caddyfile takes every site down. `add_site` backs the file up first. Validate by hand
  edits with `docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`.
