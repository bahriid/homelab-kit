---
name: gitops-sync
summary: Push to your git repo, the server applies it within a minute. The server pulls; nothing needs to reach into it.
requires: [base]
asks:
  - GITOPS_REPO: SSH clone URL of the person's own stack repo, e.g. git@github.com:me/homelab.git
  - GITOPS_DIR: where the stack lives on the server (default $HOMELAB_DIR, /srv/homelab). If the folder already holds the stack, the script attaches the repo's history to it without overwriting files.
  - GITOPS_BRANCH: branch to follow (default main)
---

# gitops-sync

## What you get

- A read-only **deploy key** for that one repo (no personal token on the server).
- `/usr/local/bin/homelab-sync`, run every minute by `homelab-sync.timer`:
  1. `git fetch` (with a 60 s timeout; a dropped connection once hung for 2 hours and blocked
     every deploy behind it).
  2. Fast-forward only. If someone edited files on the server, it stops and logs why.
  3. For every changed file, find the nearest folder with a `docker-compose.yml` and run
     `docker compose pull && up -d` there. If the folder has an `image-tag` file, its content is
     exported as `IMAGE_TAG`.
  4. If a `Caddyfile` changed, `caddy reload` (no restart).
- Log: `/var/log/homelab-sync.log`.

## Repo layout it expects

Any layout works as long as each app is one folder with a `docker-compose.yml`, for example:

```
homelab/
├── proxy/      docker-compose.yml + Caddyfile
├── navidrome/  docker-compose.yml
└── nextcloud/  docker-compose.yml   (.env stays on the server, in .gitignore)
```

Folders without an `.env` on the server are skipped if their compose file uses `env_file: .env`,
so a half-configured app never starts.

## Install

```bash
GITOPS_REPO=git@github.com:me/homelab.git bash modules/gitops-sync/install.sh
```

**Human step:** the script prints a public key. The person adds it in GitHub → repo → Settings →
Deploy keys, **without** write access. Then rerun the script to clone and start the timer.

## Verify

```bash
bash modules/gitops-sync/check.sh
```

Make a harmless commit (a comment in a compose file), push, and watch
`tail -f /var/log/homelab-sync.log`.

## Rollback

`sudo systemctl disable --now homelab-sync.timer`. Rolling back a deploy = `git revert` + push.

## Notes

- **Never edit files in `GITOPS_DIR` on the server** except `.env`. The next fast-forward fails and
  every deploy after it stops.
- A container you stopped by hand comes back the next time its folder changes. To keep a service
  off, give it `profiles: ["paused"]` in git.
- `docker restart` does not reread `.env`. After editing an `.env`, run `docker compose up -d` in
  that folder (it recreates the container).
