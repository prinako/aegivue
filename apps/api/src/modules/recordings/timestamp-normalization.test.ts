import { describe, expect, it } from "vitest";
import { applyAppendPlan, planRecordingAppend } from "./timestamp-normalization.js";

const origin = Date.parse("2026-10-19T10:00:00.000Z");
const recording = {
  id: "segment-1",
  startTime: "2026-10-19T10:00:10.000Z",
  endTime: "2026-10-19T10:00:20.000Z",
};

describe("wall-clock MSE timestamp mapping", () => {
  it("maps a fragment's measured presentation time onto the UTC timeline", () => {
    const plan = planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 1.25,
      durationSeconds: 10,
    });
    expect(plan.timestampOffset).toBeCloseTo(8.75);
    expect(plan.appendWindowStart).toBe(10);
    expect(plan.appendWindowEnd).toBe(20);
    expect(plan.gapBeforeSeconds).toBe(10);
  });

  it("places a mid-recording fragment at its true timeline offset", () => {
    const longRecording = {
      ...recording,
      endTime: "2026-10-19T10:02:00.000Z",
    };
    const plan = planRecordingAppend(origin, longRecording, {
      startSeconds: 30,
      firstPresentationSeconds: 0.75,
      durationSeconds: 10,
    }, 40);
    expect(plan.timestampOffset).toBeCloseTo(39.25);
    expect(plan.appendWindowStart).toBe(40);
    expect(plan.appendWindowEnd).toBe(50);
    expect(plan.gapBeforeSeconds).toBe(0);
  });

  it("rejects requested fragments beyond the end of the recording", () => {
    expect(() => planRecordingAppend(origin, recording, {
      startSeconds: 20,
      firstPresentationSeconds: 0,
      durationSeconds: 5,
    })).toThrow(RangeError);
  });

  it("preserves gaps between recordings", () => {
    const plan = planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 0,
      durationSeconds: 10,
    }, 7);
    expect(plan.gapBeforeSeconds).toBe(3);
    expect(plan.overlapBeforeSeconds).toBe(0);
  });

  it("clips overlap with earlier appended media", () => {
    const plan = planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 0,
      durationSeconds: 10,
    }, 12);
    expect(plan.overlapBeforeSeconds).toBe(2);
    expect(plan.appendWindowStart).toBe(12);
  });

  it("rejects a fragment that is already entirely covered", () => {
    expect(() => planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 0,
      durationSeconds: 10,
    }, 20)).toThrow(RangeError);
  });

  it("rejects unparseable and reversed recording times", () => {
    expect(() => planRecordingAppend(origin, { ...recording, endTime: recording.startTime }, {
      startSeconds: 0,
      firstPresentationSeconds: 0, durationSeconds: 10,
    })).toThrow(RangeError);
  });

  it("applies offsets and append windows when SourceBuffer is idle", () => {
    const buffer = {
      updating: false,
      timestampOffset: 0,
      appendWindowStart: 0,
      appendWindowEnd: Infinity,
    } as SourceBuffer;
    const plan = planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 0.5,
      durationSeconds: 10,
    });
    applyAppendPlan(buffer, plan);
    expect(buffer.timestampOffset).toBe(9.5);
    expect(buffer.appendWindowStart).toBe(10);
    expect(buffer.appendWindowEnd).toBe(20);
  });

  it("refuses to mutate an updating SourceBuffer", () => {
    const buffer = { updating: true } as SourceBuffer;
    const plan = planRecordingAppend(origin, recording, {
      startSeconds: 0,
      firstPresentationSeconds: 0, durationSeconds: 10,
    });
    expect(() => applyAppendPlan(buffer, plan)).toThrow("SourceBuffer is updating");
  });
});
