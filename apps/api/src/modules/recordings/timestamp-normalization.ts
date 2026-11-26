/**
 * Plan MSE append positioning from the actual fragment presentation timeline.
 * A fragment requested at +30s belongs at recordingStart +30s, not at the
 * recording's start. firstPresentationSeconds must be measured on the remuxed
 * fragment before these instructions can be used in a production player.
 */
export interface RecordingWindow {
  id: string;
  startTime: string;
  endTime: string;
}
export interface FragmentTiming {
  /** Relative source recording offset for the intended fragment start. */
  startSeconds: number;
  /** Measured first PTS from the actual remuxed output (not the requested -ss). */
  firstPresentationSeconds: number;
  /** Measured presentation span of the output media. */
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
    !Number.isFinite(fragment.startSeconds) ||
    fragment.startSeconds < 0 ||
    !Number.isFinite(fragment.firstPresentationSeconds) ||
    !Number.isFinite(fragment.durationSeconds) ||
    fragment.durationSeconds <= 0 ||
    !Number.isFinite(previousEndSeconds) ||
    previousEndSeconds < 0
  )
    throw new RangeError("Invalid recording or fragment timing");

  const recordingStart = (startMs - originUtcMs) / 1000;
  const recordingEnd = (endMs - originUtcMs) / 1000;
  const start = recordingStart + fragment.startSeconds;
  const actualEnd = Math.min(recordingEnd, start + fragment.durationSeconds);
  if (recordingStart < 0 || start >= recordingEnd) {
    throw new RangeError("Fragment outside the recording timeline");
  }
  const appendWindowStart = Math.max(start, previousEndSeconds);
  if (actualEnd <= appendWindowStart) {
    throw new RangeError(
      "Fragment is fully outside the remaining append window",
    );
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

/** Only call between SourceBuffer updates, after awaiting updateend. */
export function applyAppendPlan(buffer: SourceBuffer, plan: AppendPlan): void {
  if (buffer.updating) throw new Error("SourceBuffer is updating");
  // Start must be set before end when shrinking an existing append window.
  buffer.appendWindowStart = 0;
  buffer.appendWindowEnd = Number.POSITIVE_INFINITY;
  buffer.timestampOffset = plan.timestampOffset;
  buffer.appendWindowEnd = plan.appendWindowEnd;
  buffer.appendWindowStart = plan.appendWindowStart;
}
