---
name: health-alerts
summary: A Telegram message when something breaks quietly: a lost disk mount, an unhealthy container, a full disk, a backup that stopped running.
requires: [base]
asks:
  - TG_TOKEN: Telegram bot token from @BotFather. The person writes it into /etc/homelab-health.env themselves, or exports it in their shell before running install.sh; never in chat.
  - TG_CHAT: chat id that receives alerts (send the bot a message, then open https://api.telegram.org/bot<TOKEN>/getUpdates)
  - HEALTH_MOUNTS: mount points that must be mounted, space separated, e.g. "/mnt/hdd /mnt/backup"
  - DISK_MAX: alert above this % used (default 90)
  - BACKUP_LOG: optional, your own backup script's log if it writes lines like "<ISO date> ok ..." (default /var/log/homelab-backup.log)
---

# health-alerts

## Why

Down is easy to notice: the site is gone and people tell you. What hurts is what breaks quietly:
a USB disk that drops off and leaves an empty folder for hours, a backup that stopped a week ago,
a container stuck "unhealthy". This module checks every 10 minutes and messages you.

## What you get

`/usr/local/bin/homelab-health` + `homelab-health.timer` (every 10 min). It checks:

| Check | Alert when |
|---|---|
| Mounts in `HEALTH_MOUNTS` | not a mount point |
| Containers with a healthcheck | `unhealthy` |
| Containers with `restart: unless-stopped/always` | exited |
| Root disk and each mount | above `DISK_MAX` % |
| `BACKUP_LOG` (if it exists) | last line not `ok`, or older than 36 h |

The same alert repeats at most every 6 hours, and you get one "recovered" message when it clears.

## Install

```bash
sudo TG_CHAT=123456789 HEALTH_MOUNTS="/mnt/hdd" bash modules/health-alerts/install.sh
```

`TG_TOKEN` comes from the environment or from `/etc/homelab-health.env` if the person already
put it there.

## Verify

```bash
sudo homelab-health --dry       # lists current problems, sends nothing
sudo homelab-health --test      # sends "test message" to Telegram
bash modules/health-alerts/check.sh
```

## Rollback

`sudo systemctl disable --now homelab-health.timer`

## Adding a check

Add a line to `homelab-health` that calls `problem "<short text>"` when something is wrong. The
text is the dedupe key, so keep it stable (no timestamps or counts in it).
