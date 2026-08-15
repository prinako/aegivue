class AegivueLivePlayer extends HTMLElement {
  static get observedAttributes() { return ['camera-id']; }

  constructor() {
    super();
    this.hls = null;
    this.peer = null;
    this.whepSession = null;
    this.video = null;
    this.generation = 0;
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() {
    this.render();
    this.start();
  }

  disconnectedCallback() {
    this.stop();
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (name === 'camera-id' && oldValue !== newValue && this.isConnected) {
      this.stop();
      this.start();
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host { display:block; width:100%; height:100%; background:#07090d; }
        video { width:100%; height:100%; object-fit:cover; display:block; background:#07090d; }
        .state { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
                 color:rgba(255,255,255,.55); font:500 12px system-ui,sans-serif; }
        .root { position:relative; width:100%; height:100%; overflow:hidden; }
      </style>
      <div class="root">
        <video autoplay muted playsinline></video>
        <div class="state">Connecting live view…</div>
      </div>`;
    this.video = this.shadowRoot.querySelector('video');
    this.state = this.shadowRoot.querySelector('.state');
  }

  async start() {
    const cameraId = this.getAttribute('camera-id');
    if (!cameraId || !this.video) return;

    const generation = ++this.generation;
    this.setState('Connecting WebRTC…');

    try {
      await this.startWebRtc(cameraId, generation);
    } catch (error) {
      if (generation !== this.generation) return;
      console.warn(`WebRTC live view failed for ${cameraId}; falling back to HLS`, error);
      this.cleanupPeer();
      this.setState('WebRTC unavailable — using HLS…');
      this.startHls(cameraId, generation);
    }
  }

  async startWebRtc(cameraId, generation) {
    if (!window.RTCPeerConnection) throw new Error('WebRTC is not supported by this browser');

    const peer = new RTCPeerConnection();
    this.peer = peer;

    peer.addTransceiver('video', { direction: 'recvonly' });
    peer.ontrack = (event) => {
      if (generation !== this.generation || !this.video) return;
      this.video.srcObject = event.streams[0] || new MediaStream([event.track]);
      this.video.play().catch(() => {});
    };
    peer.onconnectionstatechange = () => {
      if (generation !== this.generation) return;
      if (peer.connectionState === 'connected') this.hideState();
      if (peer.connectionState === 'failed') this.failWebRtcToHls(cameraId, generation);
    };

    const offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    await this.waitForIceGathering(peer);
    if (generation !== this.generation) return;

    const endpoint = `/webrtc/${encodeURIComponent(cameraId)}/whep`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/sdp' },
      body: peer.localDescription.sdp,
      cache: 'no-store',
    });

    if (!response.ok) {
      throw new Error(`WHEP returned HTTP ${response.status}`);
    }

    const location = response.headers.get('Location');
    if (location) {
      const parsed = new URL(location, window.location.origin);
      this.whepSession = `/webrtc${parsed.pathname}`;
    }

    const answer = await response.text();
    if (generation !== this.generation) return;
    await peer.setRemoteDescription({ type: 'answer', sdp: answer });
  }

  waitForIceGathering(peer) {
    if (peer.iceGatheringState === 'complete') return Promise.resolve();
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        peer.removeEventListener('icegatheringstatechange', onChange);
        reject(new Error('WebRTC ICE gathering timed out'));
      }, 5000);
      const onChange = () => {
        if (peer.iceGatheringState === 'complete') {
          clearTimeout(timeout);
          peer.removeEventListener('icegatheringstatechange', onChange);
          resolve();
        }
      };
      peer.addEventListener('icegatheringstatechange', onChange);
    });
  }

  failWebRtcToHls(cameraId, generation) {
    if (generation !== this.generation || this.hls) return;
    console.warn(`WebRTC peer connection failed for ${cameraId}; falling back to HLS`);
    this.cleanupPeer();
    this.setState('WebRTC unavailable — using HLS…');
    this.startHls(cameraId, generation);
  }

  startHls(cameraId, generation) {
    if (generation !== this.generation || !this.video) return;
    const source = `/live/${encodeURIComponent(cameraId)}/index.m3u8`;
    const ready = () => {
      if (generation === this.generation) this.hideState();
    };
    const failed = () => {
      if (generation === this.generation) this.setState('Live stream unavailable');
    };

    this.video.addEventListener('playing', ready, { once: true });
    this.video.addEventListener('error', failed, { once: true });

    if (this.video.canPlayType('application/vnd.apple.mpegurl')) {
      this.video.src = source;
      this.video.play().catch(() => {});
      return;
    }

    if (window.Hls && Hls.isSupported()) {
      this.hls = new Hls({
        lowLatencyMode: true,
        liveSyncDurationCount: 1,
        liveMaxLatencyDurationCount: 3,
        maxLiveSyncPlaybackRate: 1.5,
      });
      this.hls.loadSource(source);
      this.hls.attachMedia(this.video);
      this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
        this.video.play().catch(() => {});
      });
      this.hls.on(Hls.Events.ERROR, (_event, data) => {
        if (data.fatal) failed();
      });
      return;
    }

    failed();
  }

  setState(message) {
    if (!this.state) return;
    this.state.style.display = 'flex';
    this.state.textContent = message;
  }

  hideState() {
    if (this.state) this.state.style.display = 'none';
  }

  cleanupPeer() {
    if (this.peer) {
      this.peer.ontrack = null;
      this.peer.onconnectionstatechange = null;
      this.peer.close();
      this.peer = null;
    }
    if (this.whepSession) {
      fetch(this.whepSession, { method: 'DELETE', keepalive: true }).catch(() => {});
      this.whepSession = null;
    }
  }

  stop() {
    this.generation++;
    this.cleanupPeer();
    if (this.hls) {
      this.hls.destroy();
      this.hls = null;
    }
    if (this.video) {
      this.video.pause();
      this.video.srcObject = null;
      this.video.removeAttribute('src');
      this.video.load();
    }
  }
}

if (!customElements.get('aegivue-live-player')) {
  customElements.define('aegivue-live-player', AegivueLivePlayer);
}
