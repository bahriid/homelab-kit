---
name: base
summary: Fresh Ubuntu Server to a hardened Docker host (SSH keys only, auto security updates, Docker, shared networks).
requires: []
asks:
  - DEPLOY_USER: the non-root user that will run the stack (default: the current sudo user)
  - TZ: time zone, e.g. Asia/Jakarta (default: leave as is)
---

# base

## What you get

- Security updates install themselves every day (`unattended-upgrades` + apt timers).
- SSH accepts keys only. Root login and password login are off. X11 forwarding is off.
- Docker Engine + Compose plugin from Docker's official repo, `DEPLOY_USER` in the `docker` group.
- Docker networks `web` and `db`.
- `vm.swappiness=10`, `$HOMELAB_DIR` owned by `DEPLOY_USER`.

## Before you start

- Ubuntu Server 22.04 or 24.04 (Debian works too).
- **`DEPLOY_USER` can already log in with an SSH key.** The script refuses to turn off password
  login otherwise, so nobody gets locked out.
- BIOS: set "After Power Loss" (or "AC Recovery") to **Power On**. The script can't do this; tell
  the person.

## Install

```bash
sudo DEPLOY_USER=bahri TZ=Asia/Jakarta bash modules/base/install.sh
```

After it finishes, `DEPLOY_USER` must log out and in again for the `docker` group to apply.

## Verify

```bash
bash modules/base/check.sh
```

Also ask the person to open a **new** SSH session before closing the current one.

## Rollback

- SSH: `sudo rm /etc/ssh/sshd_config.d/00-homelab.conf && sudo systemctl reload ssh`
- Auto updates: `sudo systemctl disable --now apt-daily-upgrade.timer`
- Docker stays installed; remove with `apt purge docker-ce` only if nothing else uses it.

## Notes

- **Docker bypasses ufw.** A port published with `ports:` is reachable even if ufw says no.
  Publish only what must be reachable; databases never need `ports:`.
- Docker package upgrades restart every container. `unattended-upgrades` only installs Ubuntu
  security updates by default, so Docker upgrades stay a manual, scheduled job.
