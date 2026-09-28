import assert from 'node:assert/strict';
import test from 'node:test';

const elements = new Map();

globalThis.HTMLElement = class {
  attachShadow() {
    this.shadowRoot = {};
  }
};
globalThis.customElements = {
  define(name, element) {
    elements.set(name, element);
  },
  get(name) {
    return elements.get(name);
  },
};
globalThis.window = {
  location: { origin: 'http://localhost' },
  RTCPeerConnection: true,
};

await import('../web/live_player.js');

const LivePlayer = elements.get('aegivue-live-player');

test('WHEP POST is abortable', async () => {
  const player = new LivePlayer();
  player.video = {};
  player.generation = 1;
  globalThis.RTCPeerConnection = FakePeer;

  let postOptions;
  globalThis.fetch = async (_url, options) => {
    postOptions = options;
    return response();
  };

  await player.startWebRtc('front-door', 1);

  assert.ok(postOptions.signal instanceof AbortSignal);
});

test('a stale WHEP response deletes the server session', async () => {
  const player = new LivePlayer();
  player.video = {};
  player.generation = 1;
  globalThis.RTCPeerConnection = FakePeer;

  let completePost;
  const deleted = [];
  globalThis.fetch = (url, options) => {
    if (options.method === 'DELETE') {
      deleted.push(url);
      return Promise.resolve(response());
    }
    return new Promise((resolve) => {
      completePost = resolve;
    });
  };

  const starting = player.startWebRtc('front-door', 1);
  while (completePost == null) await Promise.resolve();
  player.generation = 2;
  completePost(response());
  await starting;
  await Promise.resolve();

  assert.deepEqual(deleted, ['/webrtc/front-door/whep/session-1']);
  assert.equal(player.whepSession, null);
});

class FakePeer {
  constructor() {
    this.iceGatheringState = 'complete';
    this.localDescription = { sdp: 'offer' };
  }

  addTransceiver() {}

  async createOffer() {
    return this.localDescription;
  }

  async setLocalDescription(description) {
    this.localDescription = description;
  }

  async setRemoteDescription() {}
}

function response() {
  return {
    ok: true,
    status: 201,
    headers: { get: () => '/front-door/whep/session-1' },
    text: async () => 'answer',
  };
}
