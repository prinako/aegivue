#!/bin/sh
set -eu
base="http://127.0.0.1:3000/api/v1"
curl -fsS -X POST "$base/cameras" -H 'content-type: application/json' -d '{"id":"synthetic_camera","name":"Synthetic Camera","enabled":true,"connection":{"protocol":"rtsp","host":"rtsp-source","port":8554,"mainStream":"/aegivue-test"}}'
i=0
while [ "$i" -lt 30 ]; do
  state=$(curl -fsS "$base/cameras/synthetic_camera/status" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')
  [ "$state" = online ] && break
  i=$((i + 1)); sleep 1
done
[ "${state:-}" = online ]
sleep 12
recordings=$(curl -fsS "$base/recordings?page=1&pageSize=10")
id=$(printf '%s' "$recordings" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
[ -n "$id" ]
code=$(curl -sS -o /tmp/aegivue-range.mp4 -w '%{http_code}' -H 'Range: bytes=0-1023' "$base/recordings/$id/media")
[ "$code" = 206 ]
[ "$(wc -c </tmp/aegivue-range.mp4)" -eq 1024 ]
printf 'Synthetic RTSP integration passed; recording=%s\n' "$id"
