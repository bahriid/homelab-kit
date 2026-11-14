#!/usr/bin/env bash
# base: exit 0 when the host is a hardened Docker host.
. "$(dirname "$0")/../../lib/common.sh"
ok=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; ok=1; fi; }

chk "docker running"              "docker info"
chk "compose plugin"              "docker compose version"
chk "network web"                 "docker network inspect web"
chk "network db"                  "docker network inspect db"
chk "auto security updates"       "systemctl is-enabled apt-daily-upgrade.timer"
chk "ssh password login off"      "as_root sshd -T | grep -x 'passwordauthentication no' >/dev/null"
chk "ssh root login off"          "as_root sshd -T | grep -x 'permitrootlogin no' >/dev/null"
chk "$HOMELAB_DIR exists"         "test -d '$HOMELAB_DIR'"
exit $ok
