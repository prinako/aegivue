#!/bin/sh
set -eu

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

case "$PUID" in
  ''|*[!0-9]*) echo "PUID must be a numeric user ID" >&2; exit 1 ;;
esac
case "$PGID" in
  ''|*[!0-9]*) echo "PGID must be a numeric group ID" >&2; exit 1 ;;
esac

if [ "$(id -g vigilo)" != "$PGID" ]; then
  groupmod -o -g "$PGID" vigilo
fi

if [ "$(id -u vigilo)" != "$PUID" ]; then
  usermod -o -u "$PUID" vigilo
fi

# Only fix the mount root. Recursively chowning a large NVR library on every
# container start would be expensive and unnecessary.
if [ -d /data/recordings ]; then
  chown "$PUID:$PGID" /data/recordings 2>/dev/null || \
    echo "warning: unable to chown /data/recordings; verify host permissions" >&2
fi

echo "Starting vigilo-media as PUID=$PUID PGID=$PGID"
exec gosu "$PUID:$PGID" "$@"
