#!/usr/bin/env bash
# tailscale: private path for SSH. Tailscale SSH stays off; OpenSSH with keys does the work.
. "$(dirname "$0")/../../lib/common.sh"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | as_root sh
if tailscale status >/dev/null 2>&1; then
  log "already logged in: $(tailscale ip -4 | head -1)"
else
  log "human step: open the URL below to add this machine to your tailnet"
  as_root tailscale up --ssh=false
fi
as_root tailscale set --ssh=false
log "tailscale ip: $(tailscale ip -4 | head -1)"
