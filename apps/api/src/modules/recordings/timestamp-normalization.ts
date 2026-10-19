/**
 * Build wall-clock aligned MSE append instructions. A media fragment's first
 * presentation timestamp MUST be measured from the remuxed output, not guessed
 * from the FFmpeg -ss request (which can seek to an earlier keyframe).
 *
 * This module does not rewrite tfdt or make incompatible codecs compatible.
 */
export interface RecordingWindow {
  id: string;
  startTime: string;
  endTime: string;
}
export interface FragmentTiming {
  /** First presentation timestamp reported by probing the remuxed fragment. */
  firstPresentationSeconds: number;
  /** Duration of the media actually contained in the fragment. */
  durationSeconds: number;
}
export interface AppendPlan {
  recordingId: string;
  timestampOffset: number;
  appendWindowStart: number;
  appendWindowEnd: number;
  gapBeforeSeconds: number;
  overlapBeforeSeconds: number;
}

/**
 * The MediaSource timeline origin is the requested playback window's UTC start.
 * Real gaps are preserved: they must be represented in the UI and may require
 * an explicit seek across the empty range to continue playback.
 */
export function planRecordingAppend(
  originUtcMs: number,
  recording: RecordingWindow,
  fragment: FragmentTiming,
  previousEndSeconds = 0,
): AppendPlan {
  const startMs = Date.parse(recording.startTime);
  const endMs = Date.parse(recording.endTime);
  if (
    !Number.isFinite(originUtcMs) ||
    !Number.isFinite(startMs) ||
    !Number.isFinite(endMs) ||
    endMs <= startMs ||
    !Number.isFinite(fragment.firstPresentationSeconds) ||
    !Number.isFinite(fragment.durationSeconds) ||
    fragment.durationSeconds <= 0 ||
    !Number.isFinite(previousEndSeconds) ||
    previousEndSeconds < 0
  ) {
    throw new RangeError("Invalid recording or fragment timing");
  }
  const start = (startMs - originUtcMs) / 1000;
  const end = (endMs - originUtcMs) / 1000;
  if (start < 0 || end <= 0) {
    throw new RangeError("Recording must start at or after timeline origin");
  }
  const actualEnd = Math.min(end, start + fragment.durationSeconds);
  const appendWindowStart = Math.max(start, previousEndSeconds);
  if (actualEnd <= appendWindowStart) {
    throw new RangeError("Fragment is fully outside the remaining append window");
  }
  return {
    recordingId: recording.id,
    timestampOffset: start - fragment.firstPresentationSeconds,
    appendWindowStart,
    appendWindowEnd: actualEnd,
    gapBeforeSeconds: Math.max(0, start - previousEndSeconds),
    overlapBeforeSeconds: Math.max(0, previousEndSeconds - start),
  };
}

/**
 * Preserve precise clock gaps rather than silently compressing recordings.
 * SourceBuffer settings must only be modified when it is not updating.
 */
export function applyAppendPlan(buffer: SourceBuffer, plan: AppendPlan): void {
  if (buffer.updating) throw new Error("SourceBuffer is updating");
  buffer.timestampOffset = plan.timestampOffset;
  buffer.appendWindowStart = plan.appendWindowStart;
  buffer.appendWindowEnd = plan.appendWindowEnd;
}
