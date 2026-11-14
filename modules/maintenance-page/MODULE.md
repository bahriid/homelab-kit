---
name: maintenance-page
summary: When the server or home internet is down, browsers get a friendly "back soon" page instead of Cloudflare's error screen.
requires: []   # only needs the domain on Cloudflare (proxied records)
asks:
  - ZONE: the Cloudflare domain, e.g. example.com (covers example.com and *.example.com)
  - SITE_NAME: name shown on the page (default: the domain)
  - CONTACT: optional contact line for urgent matters, e.g. "hello@example.com"
  - CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN (token with "Edit Cloudflare Workers" permission). The person exports them in their own shell; never paste them in chat.
---

# maintenance-page

## What you get

A Cloudflare Worker on `ZONE/*` and `*.ZONE/*` that passes every request to your server. Only
when the origin is unreachable (502, 504, 520-526, 530) does it answer, and only to browsers:

- Browsers get a static 503 page that reloads itself every 2 minutes.
- API clients, sync apps and music apps get the original error, so they retry as usual.
- An app's own 503 (for example Laravel's `artisan down`) passes through untouched.

Runs on your laptop (needs Node.js for `npx wrangler`), not on the server.

## Install

```bash
export CLOUDFLARE_ACCOUNT_ID=... CLOUDFLARE_API_TOKEN=...     # the person runs this
ZONE=example.com SITE_NAME="example.com" CONTACT="hello@example.com" bash modules/maintenance-page/install.sh
```

The script renders `worker.js` + `wrangler.toml` into `modules/maintenance-page/build/` and runs
`npx wrangler@4 deploy`.

After deploying, in the Cloudflare dashboard: Workers Routes → set the routes to **Fail open**, so
if the free plan's 100k requests/day run out, traffic still reaches your server.

## Verify

Stop the tunnel for a minute and load a page in the browser:

```bash
docker stop cloudflared; sleep 5
curl -s -H 'Accept: text/html' https://<a-host> | grep -o '<title>[^<]*'
curl -s -o /dev/null -w '%{http_code}\n' https://<a-host>/api/anything   # original error, not the page
docker start cloudflared
```

## Rollback

`cd modules/maintenance-page/build && npx wrangler@4 delete`

## Notes

`wrangler login` (OAuth) can fail with a CSRF error; the API token path avoids it.
