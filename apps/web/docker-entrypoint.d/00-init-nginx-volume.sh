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

# Keep the privileged Nginx master process for binding port 80, while making
# its worker processes and writable files use the host user's IDs.
sed -i "s/^nginx:x:[0-9]*:[0-9]*:/nginx:x:${PUID}:${PGID}:/" /etc/passwd
sed -i "s/^nginx:x:[0-9]*:/nginx:x:${PGID}:/" /etc/group

mkdir -p /etc/nginx

if [ -z "$(find /etc/nginx -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "Initializing empty /etc/nginx volume with default configuration"
  cp -a /usr/share/nginx-default/. /etc/nginx/
fi

chown -R "$PUID:$PGID" /etc/nginx /var/cache/nginx 2>/dev/null || \
  echo "warning: unable to chown Nginx paths; verify host volume permissions" >&2

echo "Starting Nginx workers as PUID=$PUID PGID=$PGID"
