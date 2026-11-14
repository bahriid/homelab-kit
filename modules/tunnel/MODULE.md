---
name: tunnel
summary: Cloudflare Tunnel so the server is reachable from the internet without opening any port (works behind CGNAT).
requires: [base, caddy]
asks:
  - TUNNEL_NAME: name for the tunnel (default: home)
  - The domain must already use Cloudflare DNS. Ask which domain.
---

# tunnel

## What you get

- `cloudflared` CLI on the host (for login, create, route).
- A locally-managed tunnel whose config lives in `$HOMELAB_DIR/tunnel/config.yml`, with one
  ingress rule: everything goes to `http://caddy:80`. Caddy picks the app by hostname, so adding
  an app never touches the tunnel config.
- Container `cloudflared` on network `web`.
- `modules/tunnel/route.sh <host>` to point a hostname at the tunnel.

## Before you start

Check for CGNAT if the person wonders whether they need this: compare the router's WAN IP with
`curl -s ifconfig.me`. Different, or a WAN IP in `10.x` / `100.64-127.x`, means CGNAT: port
forwarding can't work and the tunnel is the way.

**Human step:** the person runs this once and picks their domain in the browser:

```bash
cloudflared tunnel login        # writes ~/.cloudflared/cert.pem
```

(The install script installs `cloudflared` first if it's missing; run it, let it stop at the
login check, then have the person log in, then run it again.)

## Install

```bash
TUNNEL_NAME=home bash modules/tunnel/install.sh
bash modules/tunnel/route.sh music.example.com
```

## Verify

```bash
bash modules/tunnel/check.sh
curl -sI https://<a-routed-host> | head -1
```

## Rollback

`cd $HOMELAB_DIR/tunnel && docker compose down`, then `cloudflared tunnel delete <name>` and remove
the CNAME records in the Cloudflare dashboard.

## Notes

- `route dns` writes to the zone of the **current** `cert.pem`. A hostname from another zone does
  not fail: it silently becomes `host.otherzone.com.currentzone.com`. `route.sh` checks the result
  over DNS-over-HTTPS (some ISPs intercept port 53, so `dig` can lie).
- A domain in a different Cloudflare **account** can't CNAME to this tunnel (error 1033). Run a
  second, remotely-managed tunnel for that account: another `cloudflared` container with
  `command: tunnel --no-autoupdate run` and `TUNNEL_TOKEN` in an `.env`, ingress set in that
  account's Zero Trust dashboard to `http://caddy:80`.
- Limits on the free plan: HTTP(S) only (no inbound UDP: WebRTC/TURN/game servers won't work),
  100 MB max request body, TLS ends at Cloudflare.
- If a browser still says the host doesn't exist after routing, the laptop cached the NXDOMAIN.
  macOS: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`.
