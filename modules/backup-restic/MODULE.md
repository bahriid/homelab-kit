---
name: backup-restic
summary: Nightly encrypted, deduplicated backups of your stack (configs, .env files, database dumps, app volumes) with restic, checked every night.
requires: [base]
asks:
  - RESTIC_REPOSITORY: where backups go. A path on a second disk (e.g. /mnt/backup/restic), or an off-site target such as s3:..., b2:..., sftp:...
  - BACKUP_PATHS: extra host folders to include, space separated (default: $HOMELAB_DIR)
  - BACKUP_VOLUMES: regex of Docker volume names to include (default: _data$|caddy_data)
  - For an off-site repository, its credentials (put them in /etc/homelab-backup.env, never in chat)
---

# backup-restic

## What you get

- `/usr/local/bin/homelab-backup`, run nightly at 03:30 by `homelab-backup.timer`:
  1. Dumps every running Postgres container (`pg_dumpall`) and MySQL/MariaDB container
     (`mysqldump --all-databases --single-transaction`), using the credentials the container
     already has in its environment.
  2. Tars the Docker volumes matching `BACKUP_VOLUMES`.
  3. `restic backup` of the dumps, the volume tarballs and `BACKUP_PATHS` (including `.env` files).
  4. Keeps 7 daily, 4 weekly, 6 monthly snapshots.
  5. `restic check --read-data-subset=5%`: a backup nobody checks is not a backup.
- Repository password generated into `/root/.restic-pass` (mode 600).

## Install

```bash
sudo RESTIC_REPOSITORY=/mnt/backup/restic bash modules/backup-restic/install.sh
```

**Tell the person:** copy `/root/.restic-pass` into their password manager now. If the server
dies and the password only lived on it, the backups can't be opened. Have them run
`sudo cat /root/.restic-pass` themselves; don't print it.

## Verify

```bash
sudo systemctl start homelab-backup.service     # first run now, ~minutes
bash modules/backup-restic/check.sh
```

## Restore drill (do it once)

```bash
sudo -i
export RESTIC_REPOSITORY=<repo> RESTIC_PASSWORD_FILE=/root/.restic-pass
restic snapshots
restic restore latest --target /tmp/restore-test --include /var/backups/homelab/sql
zcat /tmp/restore-test/var/backups/homelab/sql/*.sql.gz | head
rm -rf /tmp/restore-test
```

For a real database restore, pipe the dump into a fresh container of the same engine first and
check it, before touching the live one.

## Rollback

`sudo systemctl disable --now homelab-backup.timer`. The repository stays.

## Notes

- A repository on a second **internal** disk protects against a dead SSD and mistakes, not
  against fire, theft or a power surge. For data you can't lose, follow 3-2-1: three copies, two
  kinds of media, one off-site. restic talks to S3, Backblaze B2, Cloudflare R2 and SFTP directly.
- `RequiresMountsFor=` on the service: if the backup disk isn't mounted, the job doesn't run, so
  restic never fills the root disk by writing into an empty mount folder.
- `Persistent=true` on the timer: if the server was off at 03:30, the backup runs at boot.
- Big media (photos, music, Nextcloud data) is left out by default because of its size. Add its
  path to `BACKUP_PATHS` when the target has the room.
