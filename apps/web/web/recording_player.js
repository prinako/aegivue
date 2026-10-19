class AegivueRecordingPlayer extends HTMLElement {
  static get observedAttributes() { return ['src', 'mode']; }

  constructor() {
    super();
    this.video = null;
    this.mediaAbort = null;
    this.pendingSeek = null;
    this.lastTimeUpdate = 0;
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
    this.releaseVideo();
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
    this.mediaAbort = new AbortController();
    const signal = this.mediaAbort.signal;

    const ready = () => this.hideState();
    const failed = () => this.setState('Recording unavailable');

    video.addEventListener('error', failed, { once: true, signal });

    if (this.mode === 'thumbnail') {
      video.addEventListener('loadedmetadata', () => {
        if (!Number.isFinite(video.duration) || video.duration <= 0) {
          ready();
          return;
        }
        const target = Math.min(1, Math.max(0.05, video.duration * 0.08));
        try { video.currentTime = target; } catch (_) { ready(); }
      }, { once: true, signal });
      video.addEventListener('seeked', () => {
        video.pause();
        ready();
      }, { once: true, signal });
      video.load();
      return;
    }

    const emit = (phase, error = null) => this.emitPlayback(phase, error);
    video.addEventListener('loadstart', () => emit('loading'), { signal });
    video.addEventListener('waiting', () => emit('loading'), { signal });
    video.addEventListener('loadedmetadata', () => {
      this.applyPendingSeek();
      emit('ready');
    }, { signal });
    video.addEventListener('loadeddata', ready, { once: true, signal });
    video.addEventListener('play', () => emit('playing'), { signal });
    video.addEventListener('pause', () => {
      if (!video.ended) emit('paused');
    }, { signal });
    video.addEventListener('seeked', () => emit('seeked'), { signal });
    video.addEventListener('ended', () => emit('ended'), { signal });
    video.addEventListener('timeupdate', () => {
      const now = Date.now();
      if (now - this.lastTimeUpdate < 200 && !video.ended) return;
      this.lastTimeUpdate = now;
      emit(video.paused ? 'paused' : 'playing');
    }, { signal });
    video.addEventListener('error', () => emit('error', 'Recording unavailable'), {
      once: true,
      signal,
    });
    video.load();
  }

  playMedia() {
    if (!this.video) return;
    const playing = this.video.play();
    if (playing?.catch) {
      playing.catch(() => this.emitPlayback('error', 'Unable to start playback'));
    }
  }

  pauseMedia() {
    this.video?.pause();
  }

  seekTo(seconds) {
    if (!Number.isFinite(seconds)) return;
    const target = Math.max(0, seconds);
    if (!this.video || this.video.readyState < 1) {
      this.pendingSeek = target;
      return;
    }
    const duration = this.video.duration;
    this.video.currentTime = Number.isFinite(duration)
      ? Math.min(target, Math.max(0, duration))
      : target;
    this.pendingSeek = null;
  }

  applyPendingSeek() {
    if (this.pendingSeek == null) return;
    const target = this.pendingSeek;
    this.pendingSeek = null;
    this.seekTo(target);
  }

  emitPlayback(phase, error = null) {
    if (!this.video) return;
    this.setAttribute('playback-phase', phase);
    this.setAttribute('current-time', String(this.video.currentTime || 0));
    this.setAttribute(
      'media-duration',
      Number.isFinite(this.video.duration) ? String(this.video.duration) : '',
    );
    if (error) this.setAttribute('playback-error', error);
    else this.removeAttribute('playback-error');
    this.dispatchEvent(new CustomEvent('aegivue-playback', { bubbles: false }));
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
    this.releaseVideo();
    this.video = null;
    this.pendingSeek = null;
  }

  releaseVideo() {
    this.mediaAbort?.abort();
    this.mediaAbort = null;
    if (!this.video) return;
    this.video.pause();
    this.video.removeAttribute('src');
    this.video.load();
  }
}

if (!customElements.get('aegivue-recording-player')) {
  customElements.define('aegivue-recording-player', AegivueRecordingPlayer);
}
