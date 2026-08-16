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

if [ "$(id -u aegivue)" != "$PUID" ] || [ "$(id -g aegivue)" != "$PGID" ]; then
  deluser aegivue
  addgroup -g "$PGID" aegivue
  adduser -D -H -u "$PUID" -G aegivue aegivue
fi

if [ -d /data/recordings ]; then
  chown "$PUID:$PGID" /data/recordings 2>/dev/null || \
    echo "warning: unable to chown /data/recordings; verify host permissions" >&2
fi

echo "Starting aegivue-api as PUID=$PUID PGID=$PGID"
exec su-exec "$PUID:$PGID" "$@"
