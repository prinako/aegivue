import assert from 'node:assert/strict';
import test from 'node:test';

const appended = [];
class FakeStream {
  constructor(video) { this.video = video; }
  appendFragment(bytes, options) { appended.push({ bytes, options }); return Promise.resolve(); }
  trim() {}
  seekTo(value) { this.video.currentTime = value; }
  dispose() { this.closed = true; }
}
globalThis.window = { AegivueTimelineStream: FakeStream };
await import('../web/timeline_fragment_coordinator.js');
const Coordinator = window.AegivueTimelineFragmentCoordinator;
const originMs = Date.parse('2026-10-19T10:00:00Z');
const recording = {
  codecFingerprint: 'same-decoder-config',
  videoTrackId: 1,
  startTime: '2026-10-19T10:00:10Z',
  endTime: '2026-10-19T10:00:20Z',
  startSeconds: 0,
};
const response = (startSeconds = 0) => ({
  ok: true,
  headers: { get: () => Buffer.from(JSON.stringify({
    requestedStartSeconds: startSeconds,
    tracks: [{ trackId: 1, firstPresentationSeconds: 0.5, endPresentationSeconds: 10.5 }],
  })).toString('base64url') },
  arrayBuffer: async () => new ArrayBuffer(8),
});

test('maps fragment measured PTS into one timeline', async () => {
  appended.length = 0;
  const coordinator = new Coordinator({}, {
    mimeType: 'video/mp4; codecs="avc1.640028"',
    originMs, codecFingerprint: recording.codecFingerprint,
    fetchFragment: async () => response(),
  });
  const result = await coordinator.enqueue(recording);
  assert.equal(result.start, 10);
  assert.equal(result.end, 20);
  assert.equal(result.gapSeconds, 10);
  assert.equal(appended[0].options.timestampOffset, 9.5);
  assert.equal(appended[0].options.appendWindowStart, 10);
  coordinator.dispose();
});

test('refuses incompatible codec before fetching', async () => {
  let fetched = false;
  const coordinator = new Coordinator({}, {
    mimeType: 'video/mp4', originMs, codecFingerprint: 'other',
    fetchFragment: async () => { fetched = true; return response(); },
  });
  await assert.rejects(coordinator.enqueue(recording), /Incompatible/);
  assert.equal(fetched, false);
  coordinator.dispose();
});

test('rejects missing timing metadata', async () => {
  const coordinator = new Coordinator({}, {
    mimeType: 'video/mp4', originMs, codecFingerprint: recording.codecFingerprint,
    fetchFragment: async () => ({ ok: true, headers: { get: () => null } }),
  });
  await assert.rejects(coordinator.enqueue(recording), /timing metadata/);
  coordinator.dispose();
});

test('disposal prevents further requests', async () => {
  const coordinator = new Coordinator({}, {
    mimeType: 'video/mp4', originMs, codecFingerprint: recording.codecFingerprint,
    fetchFragment: async () => response(),
  });
  coordinator.dispose();
  await assert.rejects(coordinator.enqueue(recording), /disposed/);
});
