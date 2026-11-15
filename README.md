# homelab-kit

Pick-and-choose modules for a home server, written so your AI coding agent can install them for you.
Tell Claude Code, Codex or Gemini CLI: **"install navidrome from github.com/bahriid/homelab-kit"**,
and it reads the module, asks you a few questions, and sets it up on your machine.

> 🇮🇩 Seri tutorial lengkapnya (bahasa Indonesia, 10 artikel): [Home server sendiri, dari nol](https://bahri.id/blog/home-server-perlu-ngga-dan-biayanya)

## How to use it

In your agent, on the server (or on a laptop that can `ssh` into it):

```
install the tunnel and navidrome modules from https://github.com/bahriid/homelab-kit
```

The agent clones the repo, follows [`AGENTS.md`](AGENTS.md), checks what you already run, asks for
the missing details (domain, folders), shows you the plan, and waits for your yes. Logins that need
a browser (Cloudflare, Tailscale) stay with you. Passwords are generated on the server and never
printed in the chat.

No agent? Every module also works by hand: read its `MODULE.md`, then run its `install.sh`.

## Modules

| Module | What it does | Needs |
|---|---|---|
| [base](modules/base/MODULE.md) | Fresh Ubuntu to a hardened Docker host: SSH keys only, daily security updates, Docker, shared networks | - |
| [caddy](modules/caddy/MODULE.md) | One reverse proxy for every app, routed by hostname | base |
| [tunnel](modules/tunnel/MODULE.md) | Cloudflare Tunnel: online with no open ports, works behind CGNAT | base, caddy |
| [tailscale](modules/tailscale/MODULE.md) | SSH from anywhere without exposing port 22 | base |
| [gitops-sync](modules/gitops-sync/MODULE.md) | `git push` your stack repo, the server applies it within a minute | base |
| [navidrome](modules/navidrome/MODULE.md) | Your own Spotify: music server, per-user libraries, synced lyrics from LRCLIB | base, caddy |
| [nextcloud](modules/nextcloud/MODULE.md) | Your own Google Drive, with its own Postgres + Redis | base, caddy |
| [backup-restic](modules/backup-restic/MODULE.md) | Nightly encrypted backups (configs, `.env`, DB dumps, volumes), checked every night | base |
| [maintenance-page](modules/maintenance-page/MODULE.md) | Friendly "back soon" page when your home internet is down (Cloudflare Worker) | a domain on Cloudflare |
| [health-alerts](modules/health-alerts/MODULE.md) | Telegram alert when something breaks quietly: lost disk mount, unhealthy container, stale backup | base |

A typical start: `base` → `caddy` → `tunnel` → the apps you want → `backup-restic` → `health-alerts`.

## Principles

- **Each module stands alone.** Running Traefik instead of Caddy? The agent follows the intent in
  `MODULE.md` and adapts instead of forcing the script.
- **Safe to run twice.** Scripts skip what already exists and back up files before editing them.
- **Nothing breaks quietly.** Long jobs run as systemd units, every module ships a `check.sh`, and
  the notes in each `MODULE.md` come from things that actually went wrong on a real home server.

## Add a module

Copy `modules/navidrome/`, then see the contributor section in [`AGENTS.md`](AGENTS.md).
Pull requests welcome.

## License

MIT
