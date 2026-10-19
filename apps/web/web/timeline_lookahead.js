// Opt-in bounded scheduler for a previously validated MSE timeline.
// This does not infer codec compatibility or compress wall-clock gaps.
class AegivueTimelineLookahead {
  constructor(coordinator, { aheadSeconds = 30, behindSeconds = 20,
      maxQueued = 4, onError = () => {} } = {}) {
    if (!coordinator || typeof coordinator.enqueue !== 'function')
      throw new TypeError('Coordinator required');
    if (!(aheadSeconds > 0 && behindSeconds >= 0 &&
          Number.isInteger(maxQueued) && maxQueued > 0))
      throw new RangeError('Invalid buffer limits');
    this.coordinator = coordinator;
    this.aheadSeconds = aheadSeconds;
    this.behindSeconds = behindSeconds;
    this.maxQueued = maxQueued;
    this.onError = onError;
    this.items = [];
    this.nextIndex = 0;
    this.inFlight = false;
    this.generation = 0;
    this.disposed = false;
  }

  setPlaylist(items) {
    if (this.disposed) throw new Error('Lookahead disposed');
    if (!Array.isArray(items)) throw new TypeError('Playlist must be an array');
    let end = -Infinity;
    for (const item of items) {
      if (!Number.isFinite(item.start) || !Number.isFinite(item.end) ||
          item.end <= item.start || item.start < end || !item.recording)
        throw new RangeError('Playlist must contain ordered, non-overlapping windows');
      end = item.end;
    }
    this.generation++;
    this.items = items.slice();
    this.nextIndex = 0;
  }

  tick(playhead) {
    if (this.disposed || !Number.isFinite(playhead) || playhead < 0) return;
    this.coordinator.stream?.trim(playhead);
    if (this.inFlight) return;
    // Skip windows entirely behind the current playhead, without collapsing
    // genuine gaps in the recording timeline.
    while (this.nextIndex < this.items.length &&
           this.items[this.nextIndex].end <= playhead) this.nextIndex++;
    const item = this.items[this.nextIndex];
    if (!item || item.start > playhead + this.aheadSeconds) return;
    this.inFlight = true;
    const version = this.generation;
    Promise.resolve().then(() => this.coordinator.enqueue(item.recording))
      .then(() => {
        if (!this.disposed && this.generation === version) {
          this.nextIndex++;
        }
      })
      .catch((error) => {
        if (!this.disposed && this.generation === version) this.onError(error);
      })
      .finally(() => { this.inFlight = false; });
  }

  dispose() {
    this.disposed = true;
    this.generation++;
    this.items = [];
  }
}
window.AegivueTimelineLookahead = AegivueTimelineLookahead;
