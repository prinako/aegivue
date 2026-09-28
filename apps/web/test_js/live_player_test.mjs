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

test('WHEP timeout covers a stalled response body', async () => {
  const player = new LivePlayer();
  globalThis.fetch = async (_url, options) => ({
    ...response(),
    text: () => new Promise((_resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(options.signal.reason));
    }),
  });

  await assert.rejects(
    player.fetchResponseTextWithTimeout('/whep', { method: 'POST' }, 5),
  );
});

test('stopping the player aborts an in-flight WHEP request', async () => {
  const player = new LivePlayer();
  player.video = null;
  player.generation = 1;
  globalThis.RTCPeerConnection = FakePeer;

  let requestSignal;
  globalThis.fetch = (_url, options) => {
    requestSignal = options.signal;
    return new Promise((_resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(options.signal.reason));
    });
  };

  const starting = player.startWebRtc('front-door', 1);
  while (requestSignal == null) await Promise.resolve();
  player.stop();
  const settled = await Promise.race([
    starting.then(() => true, () => true),
    new Promise((resolve) => setTimeout(() => resolve(false), 20)),
  ]);

  assert.equal(requestSignal.aborted, true);
  assert.equal(settled, true);
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

  close() {}
}

function response() {
  return {
    ok: true,
    status: 201,
    headers: { get: () => '/front-door/whep/session-1' },
    text: async () => 'answer',
  };
}
