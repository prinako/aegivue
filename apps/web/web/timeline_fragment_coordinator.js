// Experimental controller for one persistent recording MediaSource per camera.
// The measured endpoint returns the exact fMP4 bytes and a base64url-encoded
// per-track timing header. Do not join files unless the caller verified codec
// and initialization compatibility. This is deliberately NOT wired to Flutter.
class AegivueTimelineFragmentCoordinator {
  constructor(video, { mimeType, fetchFragment, originMs, codecFingerprint,
      behindSeconds = 30, aheadSeconds = 90 } = {}) {
    if (!Number.isFinite(originMs) || !mimeType || !codecFingerprint) {
      throw new TypeError('originMs, mimeType and codecFingerprint required');
    }
    if (typeof fetchFragment !== 'function') throw new TypeError('fetchFragment required');
    this.stream = new window.AegivueTimelineStream(video, { mimeType, behindSeconds, aheadSeconds });
    this.originMs = originMs;
    this.codecFingerprint = codecFingerprint;
    this.fetchFragment = fetchFragment;
    this.tail = Promise.resolve();
    this.disposed = false;
    this.lastEnd = 0;
    this.abort = new AbortController();
  }

  // Each descriptor describes an explicitly selected recording and request
  // window. startTime/endTime are wall-clock ISO strings; startSeconds is
  // offset within that recording. The supplied fingerprint must be verified
  // against actual decoder configuration, not guessed from codec name.
  enqueue(recording) {
    if (this.disposed) return Promise.reject(new Error('Coordinator disposed'));
    const operation = this.tail.then(() => this._append(recording));
    this.tail = operation.catch(() => {});
    return operation;
  }

  async _append(recording) {
    if (this.disposed) throw new Error('Coordinator disposed');
    if (recording.codecFingerprint !== this.codecFingerprint) {
      throw new Error('Incompatible recording codec configuration');
    }
    const startMs = Date.parse(recording.startTime);
    const endMs = Date.parse(recording.endTime);
    const offset = recording.startSeconds ?? 0;
    if (!Number.isFinite(startMs) || !Number.isFinite(endMs) ||
        endMs <= startMs || !Number.isFinite(offset) || offset < 0) {
      throw new RangeError('Invalid recording window');
    }
    const response = await this.fetchFragment(recording, this.abort.signal);
    if (this.disposed) throw new Error('Coordinator disposed');
    if (!response?.ok) throw new Error('Fragment request failed');
    const encoded = response.headers.get('X-Recording-Timing-Base64');
    if (!encoded || encoded.length > 8192) throw new Error('Missing or oversized timing metadata');
    const json = atob(encoded.replace(/-/g, '+').replace(/_/g, '/'));
    const metadata = JSON.parse(json);
    if (!Array.isArray(metadata.tracks) || metadata.tracks.length === 0 ||
        metadata.requestedStartSeconds !== offset) {
      throw new Error('Invalid timing metadata');
    }
    // The reference video track is explicitly selected by the caller.
    const track = metadata.tracks.find((x) => x.trackId === recording.videoTrackId);
    if (!track || !Number.isFinite(track.firstPresentationSeconds) ||
        !Number.isFinite(track.endPresentationSeconds) ||
        track.endPresentationSeconds <= track.firstPresentationSeconds) {
      throw new Error('Unusable video presentation timestamps');
    }
    const start = (startMs - this.originMs) / 1000 + offset;
    const end = Math.min((endMs - this.originMs) / 1000,
      start + track.endPresentationSeconds - track.firstPresentationSeconds);
    const windowStart = Math.max(start, this.lastEnd);
    if (!Number.isFinite(windowStart) || end <= windowStart) {
      throw new Error('Fragment already covered or outside timeline');
    }
    const gapSeconds = Math.max(0, start - this.lastEnd);
    const media = await response.arrayBuffer();
    if (this.disposed) throw new Error('Coordinator disposed');
    await this.stream.appendFragment(media, {
      timestampOffset: start - track.firstPresentationSeconds,
      appendWindowStart: windowStart,
      appendWindowEnd: end,
    });
    this.lastEnd = end;
    this.stream.trim();
    return { start: windowStart, end, gapSeconds };
  }

  seekTo(seconds) { this.stream.seekTo(seconds); }
  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.abort.abort();
    this.stream.dispose();
  }
}
window.AegivueTimelineFragmentCoordinator = AegivueTimelineFragmentCoordinator;
