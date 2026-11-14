#!/usr/bin/env python3
"""Fill missing <song>.lrc files with synced lyrics from LRCLIB (https://lrclib.net).

Usage: lyrics.py <music dir> [--apply]
Without --apply it only prints what it would write. Needs ffprobe on PATH.
Only synced lyrics are written: plain text would not scroll in Navidrome anyway.
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

AUDIO = (".mp3", ".flac", ".m4a", ".ogg", ".opus")
UA = {"User-Agent": "homelab-kit lyrics.py (github.com/bahriid/homelab-kit)"}


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:format_tags",
                          "-of", "json", path], capture_output=True, text=True).stdout
    fmt = json.loads(out or "{}").get("format", {})
    tags = {k.lower(): v for k, v in fmt.get("tags", {}).items()}
    return tags.get("artist", ""), tags.get("title", ""), float(fmt.get("duration") or 0)


def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
            return json.load(r)
    except Exception:
        return None


def lookup(artist, title, dur):
    q = urllib.parse.urlencode({"artist_name": artist, "track_name": title, "duration": round(dur)})
    hit = get("https://lrclib.net/api/get?" + q)
    if not (hit and hit.get("syncedLyrics")):
        # fuzzy fallback: same title/artist search, duration within 5 s
        res = get("https://lrclib.net/api/search?" + urllib.parse.urlencode(
            {"track_name": title, "artist_name": artist})) or []
        hit = next((h for h in res if h.get("syncedLyrics")
                    and abs((h.get("duration") or 0) - dur) <= 5), None)
    return hit and hit.get("syncedLyrics")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root, apply = sys.argv[1], "--apply" in sys.argv
    found = missing = 0
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            if not name.lower().endswith(AUDIO):
                continue
            path = os.path.join(dirpath, name)
            lrc = os.path.splitext(path)[0] + ".lrc"
            if os.path.exists(lrc):
                continue
            artist, title, dur = probe(path)
            if not (artist and title and dur):
                print(f"skip (no tags)  {path}")
                continue
            text = lookup(artist, title, dur)
            time.sleep(0.2)  # be polite to a free API
            if not text:
                missing += 1
                print(f"not found       {artist} - {title}")
                continue
            found += 1
            print(f"{'wrote' if apply else 'would write'}     {lrc}")
            if apply:
                with open(lrc, "w", encoding="utf-8") as f:
                    f.write(text if text.endswith("\n") else text + "\n")
    print(f"\n{found} found, {missing} not on LRCLIB" + ("" if apply else " (dry run, add --apply)"))


if __name__ == "__main__":
    main()
