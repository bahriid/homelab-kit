#!/usr/bin/env bash
# maintenance-page: the worker is deployed if the build exists and wrangler lists a deployment.
. "$(dirname "$0")/../../lib/common.sh"
build="$(cd "$(dirname "$0")" && pwd)/build"
[ -f "$build/wrangler.toml" ] || die "not built yet (run install.sh)"
(cd "$build" && npx --yes wrangler@4 deployments list >/dev/null 2>&1) || die "no deployment found (needs CLOUDFLARE_API_TOKEN in the shell)"
echo "ok   maintenance-page worker deployed. Real test: see MODULE.md Verify."
