# AGENTS.md: how to install homelab-kit modules

You are an AI coding agent (Claude Code, Codex, Gemini CLI, or similar) helping a person set up
their own home server. This repo is a set of **modules**. The person picks the ones they want;
you install them on their machine, adapted to what they already run.

## Your workflow

1. **Find out where you are.** Is this the server itself, or a laptop that reaches the server over
   SSH? Run commands on the server. If you are on a laptop, ask for the SSH host and prefix
   commands with `ssh <host>`.
2. **Pick the module(s).** Read `README.md` for the list. Then read `modules/<name>/MODULE.md` in
   full before doing anything. Each module lists what it `requires`.
3. **Check what is already there.** Run `modules/<required>/check.sh` for every required module.
   If one fails, offer to install it first, or adapt if the person runs an equivalent
   (for example Traefik or nginx instead of Caddy).
4. **Ask the questions in the module's `asks:` list** that you can't answer yourself.
   Ask them together, in one message, with sensible defaults filled in.
5. **Show the plan** (files you will create, packages you will install, services you will
   restart) and wait for a yes. Then run `install.sh` with the answers as environment variables.
6. **Verify** with `check.sh`, plus the checks in the module's "Verify" section.
   Report what you checked and what you could not.

## Rules

- **Secrets never appear in the chat.** Generate passwords on the server (`openssl rand`), write
  them into an `.env` file with mode `600`, and tell the person the file path. Never echo, cat or
  print a secret. Avoid commands that print credentials (for example `curl -u` with
  `%{redirect_url}`, which repeats the password).
- **Steps that need a human, the human does.** Browser logins (`cloudflared tunnel login`,
  `tailscale up`) and anything that needs a password the person knows: print the exact command
  and ask them to run it. In Claude Code they can type `! <command>`.
- **Don't break what runs.** Before you edit an existing file, back it up as `<file>.bak-<date>`.
  Never run `docker system prune -a --volumes`, `docker compose down -v`, or anything that
  deletes volumes or data.
- **Scripts are safe to run twice.** If something already exists, they leave it alone. If you
  change a script's behaviour for one person's setup, say so.
- **Adapt, don't force.** The scripts assume the defaults below. If the person's setup differs,
  follow the intent in `MODULE.md` and do the steps by hand rather than bending their system to
  fit the script.

## Defaults the scripts assume

| Thing | Default | Override with |
|---|---|---|
| Stack folder | `/srv/homelab` | `HOMELAB_DIR` |
| Docker networks | `web` (proxy to apps), `db` (apps to databases) | n/a |
| Reverse proxy | Caddy in `$HOMELAB_DIR/proxy`, container `caddy` | `PROXY_MODE=tunnel` (plain HTTP behind Cloudflare Tunnel) or `direct` (Caddy gets its own certificates) |
| One app | one folder `$HOMELAB_DIR/<module>/` with `docker-compose.yml` + `.env` | n/a |
| Long jobs | systemd units, never `nohup` | n/a |

Shared helpers live in `lib/common.sh`. Every `install.sh` sources it.

## Adding a module (for contributors)

Copy `modules/navidrome/` as a starting point. A module needs:

- `MODULE.md` with front matter (`name`, `summary`, `requires`, `asks`) and the sections
  What you get, Install, Verify, Rollback, Notes.
- `install.sh`: idempotent, reads answers from environment variables, exits non-zero on failure.
- `check.sh`: exits 0 only when the module is installed and healthy. No side effects.
