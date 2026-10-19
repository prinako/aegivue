import assert from 'node:assert/strict';
import test from 'node:test';

const elements = new Map();

globalThis.HTMLElement = class extends EventTarget {
  constructor() {
    super();
    this.attributes = new Map();
  }

  attachShadow() {
    this.shadowRoot = {};
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }
  getAttribute(name) {
    return this.attributes.get(name) ?? null;
  }
  removeAttribute(name) {
    this.attributes.delete(name);
  }
};
globalThis.CustomEvent = class extends Event {
  constructor(type, options) {
    super(type, options);
  }
};
globalThis.document = { fullscreenElement: null };
globalThis.customElements = {
  define(name, element) {
    elements.set(name, element);
  },
  get(name) {
    return elements.get(name);
  },
};

await import('../web/recording_player.js');

const RecordingPlayer = elements.get('aegivue-recording-player');

test('exposes playback commands for the Flutter controller', () => {
  const player = new RecordingPlayer();

  assert.equal(typeof player.playMedia, 'function');
  assert.equal(typeof player.pauseMedia, 'function');
  assert.equal(typeof player.seekTo, 'function');
  assert.equal(typeof player.setMuted, 'function');
  assert.equal(typeof player.toggleFullscreen, 'function');
});

test('queues a seek until media metadata is ready', () => {
  const player = new RecordingPlayer();
  player.video = { readyState: 0, currentTime: 0, duration: Number.NaN };

  player.seekTo(180);

  assert.equal(player.video.currentTime, 0);
  assert.equal(player.pendingSeek, 180);
});

test('applies a queued seek and clamps it to playable duration', () => {
  const player = new RecordingPlayer();
  player.video = { readyState: 1, currentTime: 0, duration: 120 };
  player.pendingSeek = 180;

  player.applyPendingSeek();

  assert.equal(player.video.currentTime, 120);
  assert.equal(player.pendingSeek, null);
});

test('publishes typed playback attributes with each media event', () => {
  const player = new RecordingPlayer();
  player.video = { currentTime: 12.5, duration: 300 };
  let events = 0;
  player.addEventListener('aegivue-playback', () => events++);

  player.emitPlayback('playing');

  assert.equal(player.getAttribute('playback-phase'), 'playing');
  assert.equal(player.getAttribute('current-time'), '12.5');
  assert.equal(player.getAttribute('media-duration'), '300');
  assert.equal(events, 1);
});

test('controls per-camera mute and fullscreen state', async () => {
  const player = new RecordingPlayer();
  let fullscreenRequests = 0;
  player.video = {
    muted: false,
    requestFullscreen: async () => fullscreenRequests++,
  };

  player.setMuted(true);
  await player.toggleFullscreen();

  assert.equal(player.video.muted, true);
  assert.equal(fullscreenRequests, 1);
});

test('reports browser autoplay rejection without throwing', async () => {
  const player = new RecordingPlayer();
  player.video = {
    currentTime: 0,
    duration: 300,
    play: () => Promise.reject(new Error('interaction required')),
  };

  player.playMedia();
  await Promise.resolve();
  await Promise.resolve();

  assert.equal(player.getAttribute('playback-phase'), 'error');
  assert.equal(
    player.getAttribute('playback-error'),
    'Unable to start playback',
  );
});

test('releases media resources when the player disconnects', () => {
  const player = new RecordingPlayer();
  let pauses = 0;
  let sourceRemovals = 0;
  let loads = 0;
  let aborts = 0;
  player.video = {
    pause: () => pauses++,
    removeAttribute: (name) => {
      if (name === 'src') sourceRemovals++;
    },
    load: () => loads++,
  };
  player.mediaAbort = { abort: () => aborts++ };
  player.pendingSeek = 12;

  player.disconnectedCallback();

  assert.equal(aborts, 1);
  assert.equal(pauses, 1);
  assert.equal(sourceRemovals, 1);
  assert.equal(loads, 1);
  assert.equal(player.video, null);
  assert.equal(player.pendingSeek, null);
});
