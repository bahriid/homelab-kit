#!/usr/bin/env bash
# gitops-sync: deploy key + clone + homelab-sync timer.
. "$(dirname "$0")/../../lib/common.sh"
need GITOPS_REPO
GITOPS_DIR="${GITOPS_DIR:-$HOMELAB_DIR}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
key="$HOME/.ssh/homelab_deploy"

if [ ! -f "$key" ]; then
  ssh-keygen -q -t ed25519 -C "homelab-sync@$(hostname)" -f "$key" -N ""
fi
if ! grep -q "^Host github.com-homelab" "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" <<EOF

Host github.com-homelab
  HostName github.com
  User git
  IdentityFile $key
  IdentitiesOnly yes
EOF
  chmod 600 "$HOME/.ssh/config"
fi
url="${GITOPS_REPO/git@github.com:/git@github.com-homelab:}"

if [ ! -d "$GITOPS_DIR/.git" ]; then
  if ! GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git ls-remote "$url" >/dev/null 2>&1; then
    log "human step: add this key as a READ-ONLY deploy key on the repo, then rerun:"
    cat "$key.pub"
    exit 2
  fi
  as_root mkdir -p "$GITOPS_DIR"
  as_root chown "$(id -u):$(id -g)" "$GITOPS_DIR"
  if [ -z "$(ls -A "$GITOPS_DIR")" ]; then
    git clone -q -b "$GITOPS_BRANCH" "$url" "$GITOPS_DIR"
  else
    # folder already holds the stack (plus .env files): attach the history without overwriting anything
    tmp="$(mktemp -d)"
    git clone -q --no-checkout -b "$GITOPS_BRANCH" "$url" "$tmp/repo"
    mv "$tmp/repo/.git" "$GITOPS_DIR/.git"; rm -rf "$tmp"
    git -C "$GITOPS_DIR" reset -q
    if [ -n "$(git -C "$GITOPS_DIR" status --porcelain --untracked-files=no)" ]; then
      warn "files in $GITOPS_DIR differ from the repo (git status). Commit them from the laptop first, or homelab-sync will refuse to fast-forward."
    fi
  fi
fi

as_root install -m 755 "$(dirname "$0")/homelab-sync" /usr/local/bin/homelab-sync
printf 'GITOPS_DIR=%q\nGITOPS_BRANCH=%q\n' "$GITOPS_DIR" "$GITOPS_BRANCH" | as_root tee /etc/homelab-sync.env >/dev/null
as_root touch /var/log/homelab-sync.log
as_root chown "$(id -u):$(id -g)" /var/log/homelab-sync.log

# run as this user (owns the clone and the deploy key, member of docker)
as_root tee /etc/systemd/system/homelab-sync.service >/dev/null <<EOF
[Unit]
Description=Pull the stack repo and apply changes
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=$(id -un)
ExecStart=/usr/local/bin/homelab-sync
EOF
as_root tee /etc/systemd/system/homelab-sync.timer >/dev/null <<'EOF'
[Unit]
Description=Run homelab-sync every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF
as_root systemctl daemon-reload
as_root systemctl enable --now homelab-sync.timer >/dev/null
log "homelab-sync running every minute on $GITOPS_DIR ($GITOPS_BRANCH). Log: /var/log/homelab-sync.log"
