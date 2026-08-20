# Adding an RTSP camera

Aegivue records the configured main stream through FFmpeg without mandatory
transcoding. H.264 and H.265 streams that can be remuxed into MP4 are the current
recording target. Browser live viewing is most compatible with H.264.

Before adding a camera, confirm that its host is reachable from the machine running
the media engine and identify the manufacturer's RTSP paths. Aegivue accepts the
host and stream path separately; do not put credentials in `mainStream` or
`subStream`.

## Add a camera

Use the dashboard's camera settings page, or call the API directly:

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
      "mainStream": "/Streaming/Channels/101",
      "subStream": "/Streaming/Channels/102"
    }
  }'
```

`mainStream` is used for recording. Live preview prefers `subStream` to reduce
bandwidth and falls back to `mainStream` when no substream is configured. Stream
paths are vendor-specific and normally begin with `/`.

Inspect lifecycle state and completed segments:

```sh
curl --fail http://127.0.0.1:3000/api/v1/cameras/front-door/status
curl --fail 'http://127.0.0.1:3000/api/v1/recordings?page=1&pageSize=25'
```

Camera credentials are accepted on writes but omitted from API read models and
structured logs.

## Verify live viewing

Open the dashboard at <http://127.0.0.1:8080> and select the camera in **Live
view**. Aegivue attempts WebRTC first and falls back to Low-Latency HLS.

You can test the HLS path directly after the camera is online:

```sh
curl --fail http://127.0.0.1:8080/live/front-door/index.m3u8
```

For browsers on another device, set `AEGIVUE_WEBRTC_HOST` in `.env` to the Aegivue
host's reachable LAN address or DNS name. Ensure UDP port 8189 can reach the host,
then recreate the stack:

```sh
docker compose up -d --force-recreate
```

## Troubleshooting

### Camera stays offline

1. Verify the camera host, RTSP port, credentials, and exact stream path.
2. Confirm the camera is reachable from the Docker host and is not isolated on a
   different VLAN without a route.
3. Check the worker state and media-engine logs:

   ```sh
   curl --fail http://127.0.0.1:3000/api/v1/cameras/front-door/status
   docker compose logs --tail=100 aegivue-media
   ```

4. Confirm another client is not exhausting the camera's RTSP session limit.

### Recording works but live view fails

- Prefer an H.264 substream; H.265 browser support is limited.
- Test the HLS URL above. If HLS works but WebRTC does not, check
  `AEGIVUE_WEBRTC_HOST`, UDP 8189, host firewall rules, and NAT.
- Inspect both gateway and web-proxy logs:

  ```sh
  docker compose logs --tail=100 aegivue-webrtc aegivue-web
  ```

### Protect camera credentials

Keep `.env` and camera credentials out of version control. Aegivue does not yet
provide built-in authentication, so keep the dashboard and API on a trusted
network or behind an authenticated reverse proxy.
