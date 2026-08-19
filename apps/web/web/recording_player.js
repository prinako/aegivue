class AegivueRecordingPlayer extends HTMLElement {
  static get observedAttributes() { return ['src', 'mode']; }

  constructor() {
    super();
    this.video = null;
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() {
    this.render();
    this.load();
  }

  disconnectedCallback() {
    this.stop();
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (oldValue !== newValue && this.isConnected) {
      this.render();
      this.load();
    }
  }

  get mode() {
    return this.getAttribute('mode') === 'thumbnail' ? 'thumbnail' : 'player';
  }

  render() {
    const thumbnail = this.mode === 'thumbnail';
    this.shadowRoot.innerHTML = `
      <style>
        :host { display:block; width:100%; height:100%; background:#07090d; }
        .root { position:relative; width:100%; height:100%; overflow:hidden; background:#07090d; }
        video { width:100%; height:100%; object-fit:${thumbnail ? 'cover' : 'contain'}; display:block; background:#07090d; }
        .state { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
                 color:rgba(255,255,255,.55); font:500 12px system-ui,sans-serif; pointer-events:none; }
        .play { position:absolute; left:50%; top:50%; transform:translate(-50%,-50%); width:42px; height:42px;
                border-radius:50%; display:${thumbnail ? 'grid' : 'none'}; place-items:center;
                background:rgba(5,8,13,.72); color:white; font:700 18px system-ui,sans-serif; pointer-events:none; }
      </style>
      <div class="root">
        <video ${thumbnail ? 'muted playsinline preload="metadata"' : 'controls playsinline preload="metadata"'}></video>
        <div class="state">Loading recording…</div>
        <div class="play">▶</div>
      </div>`;
    this.video = this.shadowRoot.querySelector('video');
    this.state = this.shadowRoot.querySelector('.state');
  }

  load() {
    const src = this.getAttribute('src');
    if (!src || !this.video) {
      this.setState('Recording unavailable');
      return;
    }

    const video = this.video;
    video.src = src;

    const ready = () => this.hideState();
    const failed = () => this.setState('Recording unavailable');

    video.addEventListener('error', failed, { once: true });

    if (this.mode === 'thumbnail') {
      video.addEventListener('loadedmetadata', () => {
        if (!Number.isFinite(video.duration) || video.duration <= 0) {
          ready();
          return;
        }
        const target = Math.min(1, Math.max(0.05, video.duration * 0.08));
        try { video.currentTime = target; } catch (_) { ready(); }
      }, { once: true });
      video.addEventListener('seeked', () => {
        video.pause();
        ready();
      }, { once: true });
      video.load();
      return;
    }

    video.addEventListener('loadeddata', ready, { once: true });
    video.load();
  }

  setState(message) {
    if (!this.state) return;
    this.state.style.display = 'flex';
    this.state.textContent = message;
  }

  hideState() {
    if (this.state) this.state.style.display = 'none';
  }

  stop() {
    if (!this.video) return;
    this.video.pause();
    this.video.removeAttribute('src');
    this.video.load();
  }
}

if (!customElements.get('aegivue-recording-player')) {
  customElements.define('aegivue-recording-player', AegivueRecordingPlayer);
}
