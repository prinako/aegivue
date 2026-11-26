import assert from 'node:assert/strict';
import test from 'node:test';
globalThis.window = {};
await import('../web/timeline_lookahead.js');
const Lookahead = window.AegivueTimelineLookahead;
const settle = async () => { for (let i = 0; i < 6; i++) await Promise.resolve(); };
test('prefetches windows only within bounded lookahead', async () => {
  const calls = [];
  const coordinator = { enqueue: async (r) => calls.push(r.id), stream: { trim: () => {} } };
  const scheduler = new Lookahead(coordinator, { aheadSeconds: 5 });
  scheduler.setPlaylist([{ start: 10, end: 20, recording: { id: 'a' } },
    { start: 20, end: 30, recording: { id: 'b' } }]);
  scheduler.tick(0);
  await settle();
  assert.deepEqual(calls, []);
  scheduler.tick(6);
  await settle();
  assert.deepEqual(calls, ['a']);
  scheduler.tick(16);
  await settle();
  assert.deepEqual(calls, ['a', 'b']);
  scheduler.dispose();
});
test('rejects invalid playlist and avoids fetching when disposed', async () => {
  const calls = [];
  const scheduler = new Lookahead({ enqueue: async (r) => calls.push(r) });
  assert.throws(() => scheduler.setPlaylist([{ start: 3, end: 2, recording: {} }]), RangeError);
  scheduler.setPlaylist([{ start: 0, end: 10, recording: { id: 1 } }]);
  scheduler.dispose();
  scheduler.tick(1);
  await settle();
  assert.equal(calls.length, 0);
});
