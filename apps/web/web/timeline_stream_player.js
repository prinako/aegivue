// Dedicated recorded-timeline media buffer. This module intentionally does not
// handle standalone faststart MP4 files: append() accepts codec-compatible
// fragmented MP4 initialization/media fragments from the streaming API.
class AegivueTimelineStream {
  constructor(video, { mimeType, behindSeconds = 30, aheadSeconds = 90 } = {}) {
    if (!video || !mimeType) throw new TypeError('video and mimeType required');
    if (!window.MediaSource || !MediaSource.isTypeSupported(mimeType)) {
      throw new Error('Timeline streaming codec is not supported by this browser');
    }
    this.video = video;
    this.mimeType = mimeType;
    this.behindSeconds = behindSeconds;
    this.aheadSeconds = aheadSeconds;
    this.mediaSource = new MediaSource();
    this.sourceBuffer = null;
    this.queue = [];
    this.closed = false;
    this.activeAppend = null;
    this.objectUrl = URL.createObjectURL(this.mediaSource);
    this.video.src = this.objectUrl;
    this.onUpdateEnd = () => {
      this.activeAppend?.resolve();
      this.activeAppend = null;
      this.flush();
    };
    this.onUpdateError = () => {
      this.activeAppend?.reject(new Error('SourceBuffer append failed'));
      this.activeAppend = null;
      // Drop the pending continuation: decoding is not reliable after failure.
      for (const item of this.queue.splice(0)) item.reject?.(new Error('SourceBuffer failed'));
    };
    this.onSourceOpen = () => {
      if (this.closed) return;
      this.sourceBuffer = this.mediaSource.addSourceBuffer(this.mimeType);
      this.sourceBuffer.mode = 'segments';
      this.sourceBuffer.addEventListener('updateend', this.onUpdateEnd);
      this.sourceBuffer.addEventListener('error', this.onUpdateError);
      this.flush();
    };
    this.mediaSource.addEventListener('sourceopen', this.onSourceOpen, { once: true });
  }

  // appendFragment is serialized; callers must supply a valid fMP4 init
  // segment before any media fragments and ensure monotonically increasing
  // decode timestamps within a continuity period.
  appendFragment(data, { timestampOffset, appendWindowStart, appendWindowEnd } = {}) {
    if (this.closed) return Promise.reject(new Error('Timeline stream closed'));
    if (!(data instanceof ArrayBuffer)) {
      return Promise.reject(new TypeError('Expected an ArrayBuffer'));
    }
    return new Promise((resolve, reject) => {
      this.queue.push({ type: 'append', data, timestampOffset, appendWindowStart, appendWindowEnd, resolve, reject });
      this.flush();
    });
  }

  seekTo(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0) return;
    this.video.currentTime = seconds;
  }

  trim(currentTime = this.video.currentTime) {
    if (this.closed || !Number.isFinite(currentTime)) return;
    const cutoff = Math.max(0, currentTime - this.behindSeconds);
    this.queue.push({ type: 'trim', cutoff });
    this.flush();
  }

  flush() {
    if (this.closed || !this.sourceBuffer || this.sourceBuffer.updating) return;
    const item = this.queue.shift();
    if (!item) return;
    try {
      if (item.type === 'append') {
        if (item.timestampOffset !== undefined) {
          this.sourceBuffer.timestampOffset = item.timestampOffset;
        }
        if (item.appendWindowStart !== undefined || item.appendWindowEnd !== undefined) {
          this.sourceBuffer.appendWindowStart = 0;
          this.sourceBuffer.appendWindowEnd = Infinity;
          if (item.appendWindowEnd !== undefined) this.sourceBuffer.appendWindowEnd = item.appendWindowEnd;
          if (item.appendWindowStart !== undefined) this.sourceBuffer.appendWindowStart = item.appendWindowStart;
        }
        this.activeAppend = item;
        this.sourceBuffer.appendBuffer(item.data);
      } else {
        const ranges = this.sourceBuffer.buffered;
        if (ranges.length && ranges.start(0) < item.cutoff) {
          this.sourceBuffer.remove(ranges.start(0), Math.min(ranges.end(0), item.cutoff));
        } else {
          this.flush();
        }
      }
    } catch (error) {
      if (item === this.activeAppend) this.activeAppend = null;
      if (item.reject) item.reject(error);
      // The following item might still be valid, but an invalid media
      // fragment must be surfaced to the coordinator as a fatal error.
    }
  }

  dispose() {
    if (this.closed) return;
    this.closed = true;
    this.activeAppend?.reject(new Error('Timeline stream closed'));
    this.activeAppend = null;
    for (const item of this.queue.splice(0)) {
      item.reject?.(new Error('Timeline stream closed'));
    }
    if (this.sourceBuffer) {
      this.sourceBuffer.removeEventListener('updateend', this.onUpdateEnd);
      this.sourceBuffer.removeEventListener('error', this.onUpdateError);
      try { if (this.sourceBuffer.updating) this.sourceBuffer.abort(); } catch (_) {}
    }
    if (this.mediaSource.readyState === 'open') {
      try { this.mediaSource.endOfStream(); } catch (_) {}
    }
    this.video.pause();
    this.video.removeAttribute('src');
    this.video.load();
    URL.revokeObjectURL(this.objectUrl);
  }
}

window.AegivueTimelineStream = AegivueTimelineStream;
