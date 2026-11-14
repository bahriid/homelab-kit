---
name: nextcloud
summary: Your own Google Drive: files, photos, calendar and contacts on your disk.
requires: [base, caddy]
asks:
  - CLOUD_HOST: hostname, e.g. cloud.example.com
  - CLOUD_DATA: folder for user files on the host (default /srv/nextcloud-data). Put it on the disk with the most space.
  - EXTRA_MOUNTS: optional host folders to show inside Nextcloud as External storage, space separated, e.g. "/mnt/hdd"
---

# nextcloud

## What you get

- Nextcloud (Apache image) + its own Postgres + Redis, all in `$HOMELAB_DIR/nextcloud/`.
- A separate `cron` container running background jobs every 5 minutes.
- Generated database and admin passwords in `$HOMELAB_DIR/nextcloud/.env` (mode 600). The admin
  user is `admin`; tell the person where the password is, never the password.
- User files on a **bind mount** (`CLOUD_DATA`), so moving to a bigger disk is one `rsync` and a
  path change.

## Install

```bash
CLOUD_HOST=cloud.example.com CLOUD_DATA=/srv/nextcloud-data bash modules/nextcloud/install.sh
```

With the tunnel: `bash modules/tunnel/route.sh cloud.example.com`.

First start takes a minute or two (installer runs). Then in the web UI: Administration settings →
Basic settings → Background jobs → **Cron**.

## Moving data in from Google Drive

Use rclone **as a systemd unit, never with `nohup`**: a power cut or dropped SSH kills a `nohup`
job and it never resumes.

```bash
rclone config                       # remote "gdrive", type drive, read-only scope is enough
rclone size gdrive:
sudo systemd-run --unit=gdrive-sync --property=Restart=on-failure \
  rclone copy gdrive: "<CLOUD_DATA>/admin/files/Google Drive" \
    --drive-export-formats docx,xlsx,pptx --transfers 8 \
    --log-file /var/log/gdrive-sync.log --log-level INFO
```

Files written straight into the data folder are unknown to Nextcloud until scanned:

```bash
sudo chown -R 33:33 "<CLOUD_DATA>/admin/files/Google Drive"
docker exec -u www-data nextcloud php occ files:scan --path="admin/files/Google Drive"
```

## External disks

Mount the disk on the host first, with `nofail` so the server still boots without it:

```
UUID=<uuid>  /mnt/hdd  ext4  defaults,nofail,x-systemd.device-timeout=10  0 2
```

Then pass it as `EXTRA_MOUNTS=/mnt/hdd`, enable the **External storage** app, and add a "Local"
storage pointing at `/mnt/hdd`.

## Verify

```bash
bash modules/nextcloud/check.sh
```

## Rollback

`cd $HOMELAB_DIR/nextcloud && docker compose down`. Data in `CLOUD_DATA` and the database volume
stay. Delete them only on an explicit request.

## Notes

- `OVERWRITEPROTOCOL=https` + `TRUSTED_PROXIES` are required behind Caddy/tunnel, otherwise links
  and redirects come out as `http://` and client logins loop.
- Cloudflare's free plan caps a request at 100 MB. The desktop and mobile clients upload in
  chunks, so only huge single uploads through the browser are affected.
- **USB disks drop.** When a USB disk re-enumerates (`sdb` comes back as `sdc`), its mount stays on
  the dead device and Nextcloud shows an empty folder, silently. Use SATA for anything that
  matters, a powered USB hub otherwise, and the `health-alerts` module to catch a lost mount.
  Recover with `sudo mount <path> && docker restart nextcloud nextcloud-cron`.
- Never write files into a mount folder while the disk is unmounted: they land on the root disk
  and vanish behind the mount when it comes back.
- macOS Finder stuck on "Loading..." in a Nextcloud folder is the File Provider extension, not
  the server: `killall FileProviderExt`, reopen Nextcloud.app.
