#!/usr/bin/env bash
# maintenance-page: render and deploy the Cloudflare Worker. Runs on the laptop.
. "$(dirname "$0")/../../lib/common.sh"
need ZONE CLOUDFLARE_ACCOUNT_ID CLOUDFLARE_API_TOKEN
SITE_NAME="${SITE_NAME:-$ZONE}"
here="$(cd "$(dirname "$0")" && pwd)"
build="$here/build"
mkdir -p "$build"

python3 - "$here/worker.js" "$build/worker.js" "$SITE_NAME" "${CONTACT:-}" <<'PY'
import html, sys
src, dst, name, contact = sys.argv[1:]
s = open(src).read().replace("__SITE_NAME__", html.escape(name))
s = s.replace("__CONTACT__", ("Urgent? " + html.escape(contact)) if contact else "")
open(dst, "w").write(s)
PY

cat > "$build/wrangler.toml" <<EOF
name = "maintenance-page"
main = "worker.js"
compatibility_date = "2026-10-01"
workers_dev = false
routes = [
  { pattern = "$ZONE/*", zone_name = "$ZONE" },
  { pattern = "*.$ZONE/*", zone_name = "$ZONE" },
]
EOF

(cd "$build" && npx --yes wrangler@4 deploy)
log "deployed. In the dashboard set the Workers routes to Fail open."
