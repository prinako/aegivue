# Adding an RTSP camera

Vigilo records the configured main stream without transcoding. H.264/H.265 cameras that can be remuxed into MP4 are the expected initial target.

```sh
curl -X POST http://127.0.0.1:3000/api/v1/cameras \
  -H 'content-type: application/json' \
  -d '{
    "id": "front-door",
    "name": "Front Door",
    "connection": {
      "protocol": "rtsp",
      "host": "192.168.30.10",
      "port": 554,
      "username": "camera-user",
      "password": "replace-me",
      "mainStream": "/Streaming/Channels/101"
    }
  }'
```

Inspect lifecycle state with `GET /api/v1/cameras/front-door/status` and completed segments with `GET /api/v1/recordings`. Camera credentials are omitted from every response and log field.
