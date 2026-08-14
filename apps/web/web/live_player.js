class VigiloLivePlayer extends HTMLElement {
  static get observedAttributes() { return ['camera-id']; }

  constructor() {
    super();
    this.hls = null;
    this.video = null;
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
        <div class="state">Starting live view…</div>
      </div>`;
    this.video = this.shadowRoot.querySelector('video');
    this.state = this.shadowRoot.querySelector('.state');
  }

  start() {
    const cameraId = this.getAttribute('camera-id');
    if (!cameraId || !this.video) return;
    const source = `/live/${encodeURIComponent(cameraId)}/index.m3u8`;

    const ready = () => { if (this.state) this.state.style.display = 'none'; };
    const failed = () => {
      if (this.state) {
        this.state.style.display = 'flex';
        this.state.textContent = 'Live stream unavailable';
      }
    };

    this.video.addEventListener('playing', ready, { once: true });
    this.video.addEventListener('error', failed);

    if (this.video.canPlayType('application/vnd.apple.mpegurl')) {
      this.video.src = source;
      this.video.play().catch(() => {});
      return;
    }

    if (window.Hls && Hls.isSupported()) {
      this.hls = new Hls({
        lowLatencyMode: true,
        liveSyncDurationCount: 2,
        liveMaxLatencyDurationCount: 5,
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

  stop() {
    if (this.hls) {
      this.hls.destroy();
      this.hls = null;
    }
    if (this.video) {
      this.video.pause();
      this.video.removeAttribute('src');
      this.video.load();
    }
  }
}

if (!customElements.get('vigilo-live-player')) {
  customElements.define('vigilo-live-player', VigiloLivePlayer);
}
