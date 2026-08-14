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

if [ "$(id -u vigilo)" != "$PUID" ] || [ "$(id -g vigilo)" != "$PGID" ]; then
  deluser vigilo
  addgroup -g "$PGID" vigilo
  adduser -D -H -u "$PUID" -G vigilo vigilo
fi

if [ -d /data/recordings ]; then
  chown "$PUID:$PGID" /data/recordings 2>/dev/null || \
    echo "warning: unable to chown /data/recordings; verify host permissions" >&2
fi

echo "Starting vigilo-api as PUID=$PUID PGID=$PGID"
exec su-exec "$PUID:$PGID" "$@"
