---
name: navidrome
summary: Your own music streaming server (Subsonic API) with per-user libraries and synced lyrics.
requires: [base, caddy]
asks:
  - MUSIC_HOST: hostname, e.g. music.example.com
  - MUSIC_DIR: folder with the music on the host (default /srv/music)
  - EXTRA_LIBRARY: optional second folder for another person's own library, e.g. /srv/music-partner
  - ADMIN_USER: admin username (default admin)
---

# navidrome

## What you get

- Navidrome at `MUSIC_HOST`, ~30 MB RAM idle, library rescanned every hour.
- Music folders mounted **read-only**: Navidrome only reads them.
- The admin account created by the script, with the password written to
  `$HOMELAB_DIR/navidrome/.admin-password` (mode 600). Tell the person the path, never the password.
- Optional second library for another person (Navidrome 0.58+ multi-library).

## Install

```bash
MUSIC_HOST=music.example.com MUSIC_DIR=/srv/music bash modules/navidrome/install.sh
```

With the `tunnel` module, also: `bash modules/tunnel/route.sh music.example.com`.

The script creates the admin **right after** the container starts, because Navidrome makes the
first visitor admin. Do the routing (making the host public) only after the script has finished.

## Second library for another person

1. Settings → Libraries → add a library with path `/music-extra`.
2. Settings → Users → create their user, **not admin**. Admins see every library, which is why
   the library checkboxes don't appear while the user is admin.
3. Tick only their library on their user.

A file belongs to one library. Same song in both accounts = copy the file.

## Clients

| Device | App |
|---|---|
| Android | Symfonium (paid once, Android Auto), free: Substreamer |
| Android TV | Symfonium TV, from the TV's own Play Store |
| iOS | Amperfy, play:Sub |
| Mac / Windows / Linux | Feishin (on macOS: `xattr -cr /Applications/Feishin.app` after copying) |
| Browser | Navidrome's own web UI |

## Synced lyrics

Navidrome reads `<song>.lrc` next to the audio file. Lyrics scroll in sync only when **every line**
has a timestamp (`[00:12.40]text`); plain text shows as static or not at all.

`lyrics.py` fills missing `.lrc` files from [LRCLIB](https://lrclib.net) (synced lyrics only):

```bash
python3 modules/navidrome/lyrics.py /srv/music          # dry run: prints what it would write
python3 modules/navidrome/lyrics.py /srv/music --apply
```

Needs `ffprobe` (`apt install ffmpeg`) and clean `artist` / `title` tags. Typical hit rate:
70-87% for official releases, much lower for covers and small local artists.

## Verify

```bash
bash modules/navidrome/check.sh
```

Check one song's lyrics the way the apps do:
`/rest/getLyricsBySongId.view?id=<songId>&u=<user>&p=<pass>&v=1.16.1&c=check&f=json`, then
look for `"synced": true`. The `lyrics` column in Navidrome's database reads `[]` even when
lyrics work; don't trust it.

## Rollback

`cd $HOMELAB_DIR/navidrome && docker compose down`. Remove the site block from the Caddyfile.
Music files are untouched.

## Notes

- Removed files stay in the database flagged `missing` and are hidden from clients.
- Don't `rm` music you clean up; move it to a quarantine folder so a mistake is one `mv` away.
